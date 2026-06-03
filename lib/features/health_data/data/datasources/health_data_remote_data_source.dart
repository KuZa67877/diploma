import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/health_metric_type.dart';
import '../models/health_metric_sample_model.dart';

class HealthRemoteSnapshot {
  final Set<String> connectedSourceIds;
  final List<HealthMetricSampleModel> cachedSamples;

  const HealthRemoteSnapshot({
    required this.connectedSourceIds,
    required this.cachedSamples,
  });

  bool get isEmpty => connectedSourceIds.isEmpty && cachedSamples.isEmpty;
}

abstract class HealthDataRemoteDataSource {
  Future<HealthRemoteSnapshot> getSnapshot();

  Future<void> saveSnapshot(HealthRemoteSnapshot snapshot);
}

class HealthDataRemoteDataSourceImpl implements HealthDataRemoteDataSource {
  static const int _pageSize = 500;

  final FirebaseAuth Function() _authProvider;
  final FirebaseFirestore Function() _firestoreProvider;
  final _logger = AppLogger.instance;

  HealthDataRemoteDataSourceImpl({
    required FirebaseAuth Function() authProvider,
    required FirebaseFirestore Function() firestoreProvider,
  }) : _authProvider = authProvider,
       _firestoreProvider = firestoreProvider;

  @override
  Future<HealthRemoteSnapshot> getSnapshot() async {
    final user = _requireUser();
    final root = _userDoc(user.uid);

    final connected = <String>{};
    final connectionRows = await root.collection('health_connections').get();
    for (final doc in connectionRows.docs) {
      final row = doc.data();
      if (row['is_connected'] != true) {
        continue;
      }
      final sourceId = row['source_id']?.toString().trim() ?? '';
      if (sourceId.isNotEmpty) {
        connected.add(sourceId);
      }
    }

    final samples = <HealthMetricSampleModel>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
    while (true) {
      Query<Map<String, dynamic>> query = root
          .collection('health_samples')
          .orderBy('observed_at', descending: true)
          .limit(_pageSize);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      final page = await query.get();
      if (page.docs.isEmpty) {
        break;
      }

      for (final doc in page.docs) {
        final row = doc.data();
        final sampleId = row['sample_id']?.toString() ?? doc.id;
        final observedAt = _dateOrNull(row['observed_at']);
        if (sampleId.isEmpty || observedAt == null) {
          continue;
        }
        samples.add(
          HealthMetricSampleModel(
            id: sampleId,
            type: HealthMetricTypeX.fromKey(row['metric_type']?.toString()),
            value: _toDouble(row['value']),
            unit: row['unit']?.toString() ?? '',
            timestamp: observedAt,
            intervalStart: _dateOrNull(row['interval_start_at']),
            intervalEnd: _dateOrNull(row['interval_end_at']),
            sourceId: row['source_id']?.toString() ?? '',
          ),
        );
      }

      if (page.docs.length < _pageSize) {
        break;
      }
      lastDocument = page.docs.last;
    }

    return HealthRemoteSnapshot(
      connectedSourceIds: connected,
      cachedSamples: samples,
    );
  }

  @override
  Future<void> saveSnapshot(HealthRemoteSnapshot snapshot) async {
    final user = _requireUser();
    final root = _userDoc(user.uid);

    _logger.info(
      'health.remote',
      'Sync health snapshot to Firestore',
      payload: {
        'userId': user.uid,
        'connectedSources': snapshot.connectedSourceIds.length,
        'samples': snapshot.cachedSamples.length,
      },
    );

    try {
      await _replaceConnections(root, snapshot.connectedSourceIds);
      await _replaceSamples(root, snapshot.cachedSamples);
    } catch (error, stackTrace) {
      _logger.error(
        'health.remote',
        'Failed to sync health snapshot',
        payload: {
          'userId': user.uid,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to sync health data: $error');
    }
  }

  Future<void> _replaceConnections(
    DocumentReference<Map<String, dynamic>> root,
    Set<String> connectedSourceIds,
  ) async {
    final collection = root.collection('health_connections');
    await _deleteAll(collection);

    if (connectedSourceIds.isEmpty) {
      return;
    }

    var batch = _firestoreProvider().batch();
    var operations = 0;
    for (final sourceId in connectedSourceIds) {
      batch.set(collection.doc(sourceId), {
        'source_id': sourceId,
        'is_connected': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      operations += 1;
      if (operations == 400) {
        await batch.commit();
        batch = _firestoreProvider().batch();
        operations = 0;
      }
    }
    if (operations > 0) {
      await batch.commit();
    }
  }

  Future<void> _replaceSamples(
    DocumentReference<Map<String, dynamic>> root,
    List<HealthMetricSampleModel> samples,
  ) async {
    final collection = root.collection('health_samples');
    await _deleteAll(collection);
    if (samples.isEmpty) {
      return;
    }

    var batch = _firestoreProvider().batch();
    var operations = 0;
    for (final sample in samples) {
      batch.set(collection.doc(sample.id), {
        'sample_id': sample.id,
        'metric_type': sample.type.key,
        'value': sample.value,
        'unit': sample.unit,
        'observed_at': sample.timestamp.toUtc().toIso8601String(),
        'interval_start_at': sample.intervalStart?.toUtc().toIso8601String(),
        'interval_end_at': sample.intervalEnd?.toUtc().toIso8601String(),
        'source_id': sample.sourceId,
      });
      operations += 1;
      if (operations == 400) {
        await batch.commit();
        batch = _firestoreProvider().batch();
        operations = 0;
      }
    }
    if (operations > 0) {
      await batch.commit();
    }
  }

  Future<void> _deleteAll(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(_pageSize).get();
      if (page.docs.isEmpty) {
        return;
      }
      final batch = _firestoreProvider().batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (page.docs.length < _pageSize) {
        return;
      }
    }
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestoreProvider().collection('users').doc(uid);
  }

  User _requireUser() {
    final user = _authProvider().currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }
    return user;
  }

  DateTime? _dateOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.tryParse(value.toString());
  }

  double _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
