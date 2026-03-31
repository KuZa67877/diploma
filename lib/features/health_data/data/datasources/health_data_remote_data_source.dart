import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/supabase_subject_resolver.dart';
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
  static const int _pageSize = 1000;
  static const int _upsertChunkSize = 500;
  static const String _legacyConnectedSourcesKey = 'health_connected_sources';
  static const String _legacyCachedSamplesKey = 'health_cached_samples';

  final SupabaseClient Function() _clientProvider;
  final SupabaseSubjectResolver _subjectResolver;
  final _logger = AppLogger.instance;

  HealthDataRemoteDataSourceImpl({
    required SupabaseClient Function() clientProvider,
    required SupabaseSubjectResolver subjectResolver,
  }) : _clientProvider = clientProvider,
       _subjectResolver = subjectResolver;

  @override
  Future<HealthRemoteSnapshot> getSnapshot() async {
    final user = _requireUser();
    final subjectId = await _subjectResolver.resolveSubjectId();

    try {
      final connected = <String>{};
      final connectionRows = await _clientProvider()
          .from('health_source_connections')
          .select('source_id, is_connected')
          .eq('subject_id', subjectId);
      for (final row in connectionRows) {
        if (row['is_connected'] != true) {
          continue;
        }
        final sourceId = row['source_id']?.toString().trim() ?? '';
        if (sourceId.isNotEmpty) {
          connected.add(sourceId);
        }
      }

      final samples = <HealthMetricSampleModel>[];
      var offset = 0;
      while (true) {
        final page = await _clientProvider()
            .from('health_metric_samples')
            .select(
              'sample_id, metric_type, value, unit, observed_at, source_id',
            )
            .eq('subject_id', subjectId)
            .order('observed_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
        if (page.isEmpty) {
          break;
        }

        for (final row in page) {
          final sampleId = row['sample_id']?.toString() ?? '';
          if (sampleId.isEmpty) {
            continue;
          }
          final observedAt = DateTime.tryParse(
            row['observed_at']?.toString() ?? '',
          );
          if (observedAt == null) {
            continue;
          }

          samples.add(
            HealthMetricSampleModel(
              id: sampleId,
              type: HealthMetricTypeX.fromKey(row['metric_type']?.toString()),
              value: _toDouble(row['value']),
              unit: row['unit']?.toString() ?? '',
              timestamp: observedAt,
              sourceId: row['source_id']?.toString() ?? '',
            ),
          );
        }

        if (page.length < _pageSize) {
          break;
        }
        offset += _pageSize;
      }

      final snapshot = HealthRemoteSnapshot(
        connectedSourceIds: connected,
        cachedSamples: samples,
      );
      if (!snapshot.isEmpty) {
        return snapshot;
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'health.remote',
        'Failed loading health snapshot from tables, using legacy metadata fallback',
        payload: {
          'subjectId': subjectId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }

    final legacySnapshot = _loadLegacySnapshot(user);
    if (!legacySnapshot.isEmpty) {
      try {
        await saveSnapshot(legacySnapshot);
      } catch (_) {
        // No-op, migration is best-effort.
      }
    }
    return legacySnapshot;
  }

  @override
  Future<void> saveSnapshot(HealthRemoteSnapshot snapshot) async {
    final user = _requireUser();
    final subjectId = await _subjectResolver.resolveSubjectId();

    _logger.info(
      'health.remote',
      'Sync health snapshot to Supabase tables',
      payload: {
        'subjectId': subjectId,
        'connectedSources': snapshot.connectedSourceIds.length,
        'samples': snapshot.cachedSamples.length,
      },
    );

    try {
      await _syncConnections(subjectId, snapshot.connectedSourceIds);
      await _syncSamples(subjectId, snapshot.cachedSamples);
    } catch (error, stackTrace) {
      try {
        await _saveLegacySnapshot(user, snapshot);
      } catch (_) {
        // No-op, primary error handled below.
      }
      _logger.error(
        'health.remote',
        'Failed to sync health snapshot',
        payload: {
          'userId': user.id,
          'subjectId': subjectId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to sync health data: $error');
    }
  }

  User _requireUser() {
    final user = _clientProvider().auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }
    return user;
  }

  Future<void> _syncConnections(
    String subjectId,
    Set<String> connectedSourceIds,
  ) async {
    await _clientProvider()
        .from('health_source_connections')
        .delete()
        .eq('subject_id', subjectId);

    if (connectedSourceIds.isEmpty) {
      return;
    }

    final rows = connectedSourceIds
        .map(
          (sourceId) => {
            'subject_id': subjectId,
            'source_id': sourceId,
            'is_connected': true,
            'updated_at': DateTime.now().toIso8601String(),
          },
        )
        .toList(growable: false);
    await _clientProvider()
        .from('health_source_connections')
        .upsert(rows, onConflict: 'subject_id,source_id');
  }

  Future<void> _syncSamples(
    String subjectId,
    List<HealthMetricSampleModel> samples,
  ) async {
    if (samples.isEmpty) {
      return;
    }

    final payload = samples
        .map(
          (sample) => {
            'subject_id': subjectId,
            'sample_id': sample.id,
            'metric_type': sample.type.key,
            'value': sample.value,
            'unit': sample.unit,
            'observed_at': sample.timestamp.toIso8601String(),
            'source_id': sample.sourceId,
          },
        )
        .toList(growable: false);

    for (var i = 0; i < payload.length; i += _upsertChunkSize) {
      final chunk = payload.sublist(
        i,
        i + _upsertChunkSize > payload.length
            ? payload.length
            : i + _upsertChunkSize,
      );
      await _clientProvider()
          .from('health_metric_samples')
          .upsert(chunk, onConflict: 'subject_id,sample_id');
    }
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

  HealthRemoteSnapshot _loadLegacySnapshot(User user) {
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final connected = <String>{};
    final connectedRaw = metadata[_legacyConnectedSourcesKey];
    if (connectedRaw is List) {
      for (final item in connectedRaw) {
        final sourceId = item?.toString().trim() ?? '';
        if (sourceId.isNotEmpty) {
          connected.add(sourceId);
        }
      }
    }

    final samples = <HealthMetricSampleModel>[];
    final samplesRaw = metadata[_legacyCachedSamplesKey];
    if (samplesRaw is List) {
      for (final item in samplesRaw) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          samples.add(HealthMetricSampleModel.fromJson(item));
        } catch (_) {
          // Skip malformed item.
        }
      }
    }

    return HealthRemoteSnapshot(
      connectedSourceIds: connected,
      cachedSamples: samples,
    );
  }

  Future<void> _saveLegacySnapshot(
    User user,
    HealthRemoteSnapshot snapshot,
  ) async {
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    metadata[_legacyConnectedSourcesKey] = snapshot.connectedSourceIds.toList(
      growable: false,
    );
    metadata[_legacyCachedSamplesKey] = snapshot.cachedSamples
        .map((sample) => sample.toJson())
        .toList(growable: false);
    await _clientProvider().auth.updateUser(UserAttributes(data: metadata));
  }
}
