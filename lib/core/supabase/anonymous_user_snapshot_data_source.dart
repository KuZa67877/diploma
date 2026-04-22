import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failures.dart';
import '../logging/app_logger.dart';
import 'onboarding_profile_snapshot.dart';
import 'supabase_subject_resolver.dart';

abstract class AnonymousUserSnapshotDataSource {
  Future<OnboardingProfileSnapshot?> getSnapshot();
}

class AnonymousUserSnapshotDataSourceImpl
    implements AnonymousUserSnapshotDataSource {
  final SupabaseClient Function() _clientProvider;
  final SupabaseSubjectResolver _subjectResolver;
  final _logger = AppLogger.instance;

  AnonymousUserSnapshotDataSourceImpl({
    required SupabaseClient Function() clientProvider,
    required SupabaseSubjectResolver subjectResolver,
  }) : _clientProvider = clientProvider,
       _subjectResolver = subjectResolver;

  @override
  Future<OnboardingProfileSnapshot?> getSnapshot() async {
    final client = _clientProvider();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    try {
      final subjectId = await _subjectResolver.resolveSubjectId();
      final profileRows = await client
          .from('onboarding_profiles')
          .select(
            'recorded_at, first_name, last_name, age, sex, height_cm, weight_kg, '
            'blood_pressure_systolic, blood_pressure_diastolic, glucose, '
            'temperature_c, symptoms, updated_at',
          )
          .eq('subject_id', subjectId)
          .limit(1);

      final profile = profileRows.isNotEmpty ? profileRows.first : null;

      final wellbeingRows = await client
          .from('wellbeing_entries')
          .select('entry_date')
          .eq('subject_id', subjectId);

      final wellbeingDates = <DateTime>[];
      for (final item in wellbeingRows) {
        final date = _dateOrNull(item['entry_date']);
        if (date != null) {
          wellbeingDates.add(DateTime(date.year, date.month, date.day));
        }
      }

      final healthCountResponse = await client
          .from('health_metric_samples')
          .select('sample_id')
          .eq('subject_id', subjectId)
          .limit(1)
          .count(CountOption.exact);
      final healthSamplesCount = healthCountResponse.count;

      final connectedRows = await client
          .from('health_source_connections')
          .select('source_id')
          .eq('subject_id', subjectId)
          .eq('is_connected', true);
      final connectedSourceIds = <String>[];
      for (final item in connectedRows) {
        final id = item['source_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          connectedSourceIds.add(id);
        }
      }

      if (profile == null &&
          wellbeingDates.isEmpty &&
          healthSamplesCount == 0 &&
          connectedSourceIds.isEmpty) {
        return null;
      }

      final map = profile != null
          ? Map<String, dynamic>.from(profile)
          : const <String, dynamic>{};

      final tableSnapshot = OnboardingProfileSnapshot(
        firstName: _stringOrNull(map['first_name']),
        lastName: _stringOrNull(map['last_name']),
        fullName: null,
        email: user.email,
        age: _intOrNull(map['age']),
        sex: _stringOrNull(map['sex']),
        heightCm: _doubleOrNull(map['height_cm']),
        weightKg: _doubleOrNull(map['weight_kg']),
        systolic: _intOrNull(map['blood_pressure_systolic']),
        diastolic: _intOrNull(map['blood_pressure_diastolic']),
        glucose: _intOrNull(map['glucose']),
        temperatureC: _doubleOrNull(map['temperature_c']),
        recordedAt: _dateOrNull(map['recorded_at']),
        completedAt: _dateOrNull(map['updated_at']),
        symptoms: _stringList(map['symptoms']),
        wellbeingEntriesCount: wellbeingDates.length,
        healthSamplesCount: healthSamplesCount,
        connectedHealthSourceIds: connectedSourceIds,
        wellbeingEntryDates: wellbeingDates,
      );

      final metadataSnapshot = OnboardingProfileSnapshot.fromUserMetadata(
        user.userMetadata,
        email: user.email,
      );
      final merged = _mergeWithMetadataFallback(
        tableSnapshot: tableSnapshot,
        metadataSnapshot: metadataSnapshot,
      );
      _logger.debug(
        'snapshot.remote',
        'Resolved onboarding snapshot',
        payload: {
          'subjectId': subjectId,
          'fromTable': {
            'age': tableSnapshot.age,
            'sex': tableSnapshot.sex,
            'heightCm': tableSnapshot.heightCm,
            'weightKg': tableSnapshot.weightKg,
          },
          'fromMetadata': {
            'age': metadataSnapshot.age,
            'sex': metadataSnapshot.sex,
            'heightCm': metadataSnapshot.heightCm,
            'weightKg': metadataSnapshot.weightKg,
          },
          'resolved': {
            'age': merged.age,
            'sex': merged.sex,
            'heightCm': merged.heightCm,
            'weightKg': merged.weightKg,
          },
        },
      );
      return merged;
    } catch (error, stackTrace) {
      _logger.warning(
        'snapshot.remote',
        'Failed to load anonymous snapshot from Supabase tables',
        payload: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  OnboardingProfileSnapshot _mergeWithMetadataFallback({
    required OnboardingProfileSnapshot tableSnapshot,
    required OnboardingProfileSnapshot metadataSnapshot,
  }) {
    return OnboardingProfileSnapshot(
      firstName: tableSnapshot.firstName ?? metadataSnapshot.firstName,
      lastName: tableSnapshot.lastName ?? metadataSnapshot.lastName,
      fullName: tableSnapshot.fullName ?? metadataSnapshot.fullName,
      email: tableSnapshot.email ?? metadataSnapshot.email,
      age: tableSnapshot.age ?? metadataSnapshot.age,
      sex: tableSnapshot.sex ?? metadataSnapshot.sex,
      heightCm: tableSnapshot.heightCm ?? metadataSnapshot.heightCm,
      weightKg: tableSnapshot.weightKg ?? metadataSnapshot.weightKg,
      systolic: tableSnapshot.systolic ?? metadataSnapshot.systolic,
      diastolic: tableSnapshot.diastolic ?? metadataSnapshot.diastolic,
      glucose: tableSnapshot.glucose ?? metadataSnapshot.glucose,
      temperatureC: tableSnapshot.temperatureC ?? metadataSnapshot.temperatureC,
      recordedAt: tableSnapshot.recordedAt ?? metadataSnapshot.recordedAt,
      completedAt: tableSnapshot.completedAt ?? metadataSnapshot.completedAt,
      symptoms: tableSnapshot.symptoms.isNotEmpty
          ? tableSnapshot.symptoms
          : metadataSnapshot.symptoms,
      wellbeingEntriesCount: tableSnapshot.wellbeingEntriesCount,
      healthSamplesCount: tableSnapshot.healthSamplesCount,
      connectedHealthSourceIds: tableSnapshot.connectedHealthSourceIds,
      wellbeingEntryDates: tableSnapshot.wellbeingEntryDates,
    );
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
