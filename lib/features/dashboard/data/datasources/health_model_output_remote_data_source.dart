import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';

class HealthModelOutputPayload {
  final String modelId;
  final String modelVersion;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double? score;
  final double confidence;
  final String status;
  final String? source;
  final String? reason;
  final List<Map<String, dynamic>> reasonCodes;
  final Map<String, dynamic> dataQuality;
  final Map<String, dynamic> features;

  const HealthModelOutputPayload({
    required this.modelId,
    required this.modelVersion,
    required this.windowStart,
    required this.windowEnd,
    required this.score,
    required this.confidence,
    required this.status,
    required this.source,
    required this.reason,
    required this.reasonCodes,
    required this.dataQuality,
    required this.features,
  });
}

class HealthModelOutputRecord {
  final String modelId;
  final String modelVersion;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double? score;
  final double confidence;
  final String status;
  final String? source;
  final String? reason;
  final List<Map<String, dynamic>> reasonCodes;
  final Map<String, dynamic> dataQuality;
  final Map<String, dynamic> features;

  const HealthModelOutputRecord({
    required this.modelId,
    required this.modelVersion,
    required this.windowStart,
    required this.windowEnd,
    required this.score,
    required this.confidence,
    required this.status,
    required this.source,
    required this.reason,
    required this.reasonCodes,
    required this.dataQuality,
    required this.features,
  });
}

abstract class HealthModelOutputRemoteDataSource {
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs);

  Future<Map<String, HealthModelOutputRecord>> getLatestOutputsByModelIds(
    List<String> modelIds,
  );

  Future<List<HealthModelOutputRecord>> getOutputsByModelIdsForRange({
    required List<String> modelIds,
    required DateTime start,
    required DateTime end,
  });
}

class HealthModelOutputRemoteDataSourceImpl
    implements HealthModelOutputRemoteDataSource {
  final FirebaseAuth Function() _authProvider;
  final FirebaseFirestore Function() _firestoreProvider;
  final _logger = AppLogger.instance;

  HealthModelOutputRemoteDataSourceImpl({
    required FirebaseAuth Function() authProvider,
    required FirebaseFirestore Function() firestoreProvider,
  }) : _authProvider = authProvider,
       _firestoreProvider = firestoreProvider;

  @override
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs) async {
    if (outputs.isEmpty) {
      return;
    }

    final user = _authProvider().currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }
    final collection = _modelOutputsCollection(user.uid);
    var batch = _firestoreProvider().batch();
    var operations = 0;

    _logger.info(
      'health.model_outputs',
      'Save health model outputs',
      payload: {'userId': user.uid, 'outputs': outputs.length},
    );

    for (final output in outputs) {
      batch.set(collection.doc(_outputId(output)), {
        'model_id': output.modelId,
        'model_version': output.modelVersion,
        'window_start': output.windowStart.toUtc().toIso8601String(),
        'window_end': output.windowEnd.toUtc().toIso8601String(),
        'score': output.score,
        'confidence': output.confidence.clamp(0.0, 1.0),
        'status': output.status,
        'source': output.source,
        'reason': output.reason,
        'reason_codes': output.reasonCodes,
        'data_quality': output.dataQuality,
        'features': output.features,
      }, SetOptions(merge: true));
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

  @override
  Future<Map<String, HealthModelOutputRecord>> getLatestOutputsByModelIds(
    List<String> modelIds,
  ) async {
    final normalizedModelIds = modelIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedModelIds.isEmpty) {
      return const {};
    }

    final records = await _loadAllRecords();
    final latestByModel = <String, HealthModelOutputRecord>{};
    for (final record in records) {
      if (!normalizedModelIds.contains(record.modelId)) {
        continue;
      }
      latestByModel.putIfAbsent(record.modelId, () => record);
    }
    return latestByModel;
  }

  @override
  Future<List<HealthModelOutputRecord>> getOutputsByModelIdsForRange({
    required List<String> modelIds,
    required DateTime start,
    required DateTime end,
  }) async {
    final normalizedModelIds = modelIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedModelIds.isEmpty) {
      return const <HealthModelOutputRecord>[];
    }

    final records = await _loadAllRecords();
    return records
        .where((record) {
          return normalizedModelIds.contains(record.modelId) &&
              !record.windowStart.isAfter(end.toUtc()) &&
              !record.windowEnd.isBefore(start.toUtc());
        })
        .toList(growable: false);
  }

  Future<List<HealthModelOutputRecord>> _loadAllRecords() async {
    final user = _authProvider().currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final query = await _modelOutputsCollection(
      user.uid,
    ).orderBy('window_end', descending: true).get();
    final records = <HealthModelOutputRecord>[];
    for (final doc in query.docs) {
      final row = doc.data();
      final modelId = row['model_id']?.toString().trim() ?? '';
      if (modelId.isEmpty) {
        continue;
      }

      final windowStart = _dateOrNull(row['window_start'])?.toUtc();
      final windowEnd = _dateOrNull(row['window_end'])?.toUtc();
      if (windowStart == null || windowEnd == null) {
        continue;
      }

      records.add(
        HealthModelOutputRecord(
          modelId: modelId,
          modelVersion: row['model_version']?.toString() ?? '',
          windowStart: windowStart,
          windowEnd: windowEnd,
          score: _toDoubleOrNull(row['score']),
          confidence: _toDouble(row['confidence']).clamp(0.0, 1.0),
          status: row['status']?.toString() ?? 'unknown',
          source: row['source']?.toString(),
          reason: row['reason']?.toString(),
          reasonCodes: _toListOfMap(row['reason_codes']),
          dataQuality: _toMap(row['data_quality']),
          features: _toMap(row['features']),
        ),
      );
    }
    return records;
  }

  CollectionReference<Map<String, dynamic>> _modelOutputsCollection(
    String uid,
  ) {
    return _firestoreProvider()
        .collection('users')
        .doc(uid)
        .collection('model_outputs');
  }

  String _outputId(HealthModelOutputPayload output) {
    final start = output.windowStart.toUtc().microsecondsSinceEpoch;
    final end = output.windowEnd.toUtc().microsecondsSinceEpoch;
    final version = output.modelVersion.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return '${output.modelId}__${version}__${start}__$end';
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
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _toDoubleOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  Map<String, dynamic> _toMap(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  List<Map<String, dynamic>> _toListOfMap(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, nested) => MapEntry(key.toString(), nested)),
        )
        .toList(growable: false);
  }
}
