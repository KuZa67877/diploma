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

abstract class HealthModelOutputRemoteDataSource {
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs);
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
}
