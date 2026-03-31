import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/supabase_subject_resolver.dart';
import '../../domain/entities/data_input_entry.dart';

abstract class DataInputRemoteDataSource {
  Future<void> saveEntry(DataInputEntry entry);
}

class DataInputRemoteDataSourceImpl implements DataInputRemoteDataSource {
  final SupabaseClient Function() _clientProvider;
  final SupabaseSubjectResolver _subjectResolver;
  final _logger = AppLogger.instance;

  DataInputRemoteDataSourceImpl({
    required SupabaseClient Function() clientProvider,
    required SupabaseSubjectResolver subjectResolver,
  }) : _clientProvider = clientProvider,
       _subjectResolver = subjectResolver;

  @override
  Future<void> saveEntry(DataInputEntry entry) async {
    final client = _clientProvider();
    final user = client.auth.currentUser;
    if (user == null) {
      _logger.warning(
        'data_input.remote',
        'Skip remote save: no active auth user in session',
      );
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final subjectId = await _subjectResolver.resolveSubjectId();
    final payload = _toPayload(subjectId, entry);
    _logger.info(
      'data_input.request',
      'Saving onboarding data to Supabase table onboarding_profiles',
      payload: {'subjectId': subjectId},
    );

    try {
      await client
          .from('onboarding_profiles')
          .upsert(payload, onConflict: 'subject_id');
      _logger.info(
        'data_input.response',
        'Onboarding data saved to onboarding_profiles',
        payload: {'subjectId': subjectId},
      );
    } catch (error, stackTrace) {
      try {
        final metadata = Map<String, dynamic>.from(
          user.userMetadata ?? const {},
        );
        metadata['onboarding_profile'] = _toLegacyMetadataPayload(entry);
        metadata['onboarding_completed_at'] = DateTime.now().toIso8601String();
        await client.auth.updateUser(UserAttributes(data: metadata));
      } catch (_) {
        // No-op, fallback is best-effort.
      }
      _logger.error(
        'data_input.response',
        'Failed to save onboarding data to onboarding_profiles',
        payload: {
          'subjectId': subjectId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to save onboarding profile: $error');
    }
  }

  Map<String, dynamic> _toPayload(String subjectId, DataInputEntry entry) {
    return {
      'subject_id': subjectId,
      'recorded_at': entry.recordedAt.toIso8601String(),
      'first_name': entry.firstName,
      'last_name': entry.lastName,
      'height_cm': entry.height,
      'weight_kg': entry.weight,
      'age': entry.age,
      'sex': entry.sex,
      'blood_pressure_systolic': entry.systolic,
      'blood_pressure_diastolic': entry.diastolic,
      'glucose': entry.glucose,
      'temperature_c': entry.temperature,
      'symptoms': entry.symptoms,
    };
  }

  Map<String, dynamic> _toLegacyMetadataPayload(DataInputEntry entry) {
    return {
      'recorded_at': entry.recordedAt.toIso8601String(),
      'first_name': entry.firstName,
      'last_name': entry.lastName,
      'height_cm': entry.height,
      'weight_kg': entry.weight,
      'age': entry.age,
      'sex': entry.sex,
      'blood_pressure_systolic': entry.systolic,
      'blood_pressure_diastolic': entry.diastolic,
      'glucose': entry.glucose,
      'temperature_c': entry.temperature,
      'symptoms': entry.symptoms,
    };
  }
}
