class OnboardingProfileSnapshot {
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? email;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final int? systolic;
  final int? diastolic;
  final int? glucose;
  final double? temperatureC;
  final DateTime? recordedAt;
  final DateTime? completedAt;
  final List<String> symptoms;
  final int wellbeingEntriesCount;
  final int healthSamplesCount;
  final List<String> connectedHealthSourceIds;
  final List<DateTime> wellbeingEntryDates;

  const OnboardingProfileSnapshot({
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.systolic,
    required this.diastolic,
    required this.glucose,
    required this.temperatureC,
    required this.recordedAt,
    required this.completedAt,
    required this.symptoms,
    required this.wellbeingEntriesCount,
    required this.healthSamplesCount,
    required this.connectedHealthSourceIds,
    required this.wellbeingEntryDates,
  });

  factory OnboardingProfileSnapshot.fromUserMetadata(
    Map<String, dynamic>? userMetadata, {
    String? email,
  }) {
    final metadata = Map<String, dynamic>.from(userMetadata ?? const {});
    final onboardingRaw = metadata['onboarding_profile'];
    final onboarding = onboardingRaw is Map
        ? Map<String, dynamic>.from(onboardingRaw.cast<dynamic, dynamic>())
        : const <String, dynamic>{};
    final symptomsRaw = onboarding['symptoms'];
    final symptoms = symptomsRaw is List
        ? symptomsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final wellbeingRaw = metadata['wellbeing_entries'];
    final wellbeingEntryDates = <DateTime>[];
    if (wellbeingRaw is Map) {
      wellbeingRaw.forEach((dateKey, value) {
        if (dateKey is String) {
          final date = _fromDateKey(dateKey);
          if (date != null) {
            wellbeingEntryDates.add(date);
          }
        }
      });
    }

    final healthSamplesRaw = metadata['health_cached_samples'];
    var healthSamplesCount = 0;
    if (healthSamplesRaw is List) {
      for (final item in healthSamplesRaw) {
        if (item is Map) {
          healthSamplesCount += 1;
        }
      }
    }

    final connectedSourcesRaw = metadata['health_connected_sources'];
    final connectedHealthSourceIds = <String>[];
    if (connectedSourcesRaw is List) {
      for (final item in connectedSourcesRaw) {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          connectedHealthSourceIds.add(id);
        }
      }
    }

    return OnboardingProfileSnapshot(
      firstName: _stringOrNull(onboarding['first_name']),
      lastName: _stringOrNull(onboarding['last_name']),
      fullName:
          _stringOrNull(metadata['full_name']) ??
          _stringOrNull(metadata['name']),
      email: email ?? _stringOrNull(metadata['email']),
      age: _intOrNull(onboarding['age']),
      sex: _stringOrNull(onboarding['sex']),
      heightCm: _doubleOrNull(onboarding['height_cm']),
      weightKg: _doubleOrNull(onboarding['weight_kg']),
      systolic: _intOrNull(onboarding['blood_pressure_systolic']),
      diastolic: _intOrNull(onboarding['blood_pressure_diastolic']),
      glucose: _intOrNull(onboarding['glucose']),
      temperatureC: _doubleOrNull(onboarding['temperature_c']),
      recordedAt: _dateTimeOrNull(onboarding['recorded_at']),
      completedAt: _dateTimeOrNull(metadata['onboarding_completed_at']),
      symptoms: symptoms,
      wellbeingEntriesCount: wellbeingEntryDates.length,
      healthSamplesCount: healthSamplesCount,
      connectedHealthSourceIds: connectedHealthSourceIds,
      wellbeingEntryDates: wellbeingEntryDates,
    );
  }

  String? get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    final fromParts = '$first $last'.trim();
    if (fromParts.isNotEmpty) {
      return fromParts;
    }
    if ((fullName ?? '').trim().isNotEmpty) {
      return fullName!.trim();
    }
    if ((email ?? '').trim().isNotEmpty) {
      final value = email!.trim();
      final atIndex = value.indexOf('@');
      if (atIndex > 0) {
        return value.substring(0, atIndex);
      }
      return value;
    }
    return null;
  }

  bool get hasAnyCoreHealthValue =>
      weightKg != null ||
      heightCm != null ||
      systolic != null ||
      diastolic != null ||
      glucose != null ||
      temperatureC != null;

  int get recordsCount {
    final hasProfileData = hasAnyCoreHealthValue || symptoms.isNotEmpty;
    var total = 0;
    if (hasProfileData) {
      total += 1;
    }
    total += wellbeingEntriesCount;
    total += healthSamplesCount;
    return total;
  }

  int get streakDays {
    final normalizedDates = <DateTime>{};
    for (final date in wellbeingEntryDates) {
      normalizedDates.add(DateTime(date.year, date.month, date.day));
    }
    final completed = completedAt;
    if (completed != null) {
      normalizedDates.add(
        DateTime(completed.year, completed.month, completed.day),
      );
    }

    if (normalizedDates.isEmpty) {
      return recordsCount == 0 ? 0 : 1;
    }

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var streak = 0;
    while (normalizedDates.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (streak > 0) {
      return streak;
    }

    if (recordsCount > 0) {
      return 1;
    }
    return 0;
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

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static DateTime? _fromDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }
}
