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

  factory OnboardingProfileSnapshot.fromAuthUser({
    required String? email,
    String? displayName,
  }) {
    return OnboardingProfileSnapshot(
      firstName: null,
      lastName: null,
      fullName: _stringOrNull(displayName),
      email: _stringOrNull(email),
      age: null,
      sex: null,
      heightCm: null,
      weightKg: null,
      systolic: null,
      diastolic: null,
      glucose: null,
      temperatureC: null,
      recordedAt: null,
      completedAt: null,
      symptoms: const <String>[],
      wellbeingEntriesCount: 0,
      healthSamplesCount: 0,
      connectedHealthSourceIds: const <String>[],
      wellbeingEntryDates: const <DateTime>[],
    );
  }

  factory OnboardingProfileSnapshot.fromUserMetadata(
    Map<String, dynamic>? userMetadata, {
    String? email,
  }) {
    final metadata = Map<String, dynamic>.from(userMetadata ?? const {});
    final onboardingRaw = metadata['onboarding_profile'];
    final onboardingLegacyRaw = metadata['onboarding'];
    final profileRaw = metadata['profile'];
    final onboarding = onboardingRaw is Map
        ? Map<String, dynamic>.from(onboardingRaw.cast<dynamic, dynamic>())
        : const <String, dynamic>{};
    final onboardingLegacy = onboardingLegacyRaw is Map
        ? Map<String, dynamic>.from(
            onboardingLegacyRaw.cast<dynamic, dynamic>(),
          )
        : const <String, dynamic>{};
    final profile = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw.cast<dynamic, dynamic>())
        : const <String, dynamic>{};

    Object? pick(List<String> keys) {
      for (final key in keys) {
        if (onboarding.containsKey(key) && onboarding[key] != null) {
          return onboarding[key];
        }
        if (onboardingLegacy.containsKey(key) &&
            onboardingLegacy[key] != null) {
          return onboardingLegacy[key];
        }
        if (profile.containsKey(key) && profile[key] != null) {
          return profile[key];
        }
        if (metadata.containsKey(key) && metadata[key] != null) {
          return metadata[key];
        }
      }
      return null;
    }

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
      firstName: _stringOrNull(
        pick(['first_name', 'firstName', 'name_first', 'firstname']),
      ),
      lastName: _stringOrNull(
        pick(['last_name', 'lastName', 'name_last', 'lastname']),
      ),
      fullName:
          _stringOrNull(metadata['full_name']) ??
          _stringOrNull(metadata['name']) ??
          _stringOrNull(
            pick(['display_name', 'displayName', 'fullName', 'full_name']),
          ),
      email: email ?? _stringOrNull(metadata['email']),
      age: _intOrNull(pick(['age'])),
      sex: _stringOrNull(pick(['sex', 'gender'])),
      heightCm: _doubleOrNull(pick(['height_cm', 'heightCm', 'height'])),
      weightKg: _doubleOrNull(pick(['weight_kg', 'weightKg', 'weight'])),
      systolic: _intOrNull(
        pick(['blood_pressure_systolic', 'systolic', 'bp_systolic']),
      ),
      diastolic: _intOrNull(
        pick(['blood_pressure_diastolic', 'diastolic', 'bp_diastolic']),
      ),
      glucose: _intOrNull(pick(['glucose', 'blood_glucose'])),
      temperatureC: _doubleOrNull(
        pick(['temperature_c', 'temperatureC', 'temperature']),
      ),
      recordedAt: _dateTimeOrNull(
        pick(['recorded_at', 'recordedAt', 'created_at']),
      ),
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
