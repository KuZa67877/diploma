import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/supabase_subject_resolver.dart';

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
  final SupabaseClient Function() _clientProvider;
  final SupabaseSubjectResolver _subjectResolver;
  final _logger = AppLogger.instance;

  HealthModelOutputRemoteDataSourceImpl({
    required SupabaseClient Function() clientProvider,
    required SupabaseSubjectResolver subjectResolver,
  }) : _clientProvider = clientProvider,
       _subjectResolver = subjectResolver;

  @override
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs) async {
    if (outputs.isEmpty) {
      return;
    }

    final user = _clientProvider().auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }
    final subjectId = await _subjectResolver.resolveSubjectId();
    final rows = outputs
        .map(
          (output) => {
            'subject_id': subjectId,
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
          },
        )
        .toList(growable: false);

    _logger.info(
      'health.model_outputs',
      'Save health model outputs',
      payload: {'subjectId': subjectId, 'outputs': rows.length},
    );

    await _clientProvider()
        .from('health_model_outputs')
        .upsert(
          rows,
          onConflict:
              'subject_id,model_id,model_version,window_start,window_end',
        );
  }

  @override
  Future<Map<String, HealthModelOutputRecord>> getLatestOutputsByModelIds(
    List<String> modelIds,
  ) async {
    final normalizedModelIds = modelIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedModelIds.isEmpty) {
      return const {};
    }

    final user = _clientProvider().auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final subjectId = await _subjectResolver.resolveSubjectId();
    final rows = await _clientProvider()
        .from('health_model_outputs')
        .select(
          'model_id, model_version, window_start, window_end, score, confidence, status, source, reason, reason_codes, data_quality, features',
        )
        .eq('subject_id', subjectId)
        .inFilter('model_id', normalizedModelIds)
        .order('window_end', ascending: false);

    final latestByModel = <String, HealthModelOutputRecord>{};
    for (final row in rows) {
      final modelId = row['model_id']?.toString().trim() ?? '';
      if (modelId.isEmpty || latestByModel.containsKey(modelId)) {
        continue;
      }

      final windowStart = DateTime.tryParse(
        row['window_start']?.toString() ?? '',
      )?.toUtc();
      final windowEnd = DateTime.tryParse(
        row['window_end']?.toString() ?? '',
      )?.toUtc();
      if (windowStart == null || windowEnd == null) {
        continue;
      }

      latestByModel[modelId] = HealthModelOutputRecord(
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
      );
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
        .toSet()
        .toList(growable: false);
    if (normalizedModelIds.isEmpty) {
      return const <HealthModelOutputRecord>[];
    }

    final user = _clientProvider().auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final subjectId = await _subjectResolver.resolveSubjectId();
    final rows = await _clientProvider()
        .from('health_model_outputs')
        .select(
          'model_id, model_version, window_start, window_end, score, confidence, status, source, reason, reason_codes, data_quality, features',
        )
        .eq('subject_id', subjectId)
        .inFilter('model_id', normalizedModelIds)
        .lte('window_start', end.toUtc().toIso8601String())
        .gte('window_end', start.toUtc().toIso8601String())
        .order('window_end', ascending: false);

    final records = <HealthModelOutputRecord>[];
    for (final row in rows) {
      final modelId = row['model_id']?.toString().trim() ?? '';
      if (modelId.isEmpty) {
        continue;
      }

      final windowStart = DateTime.tryParse(
        row['window_start']?.toString() ?? '',
      )?.toUtc();
      final windowEnd = DateTime.tryParse(
        row['window_end']?.toString() ?? '',
      )?.toUtc();
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
