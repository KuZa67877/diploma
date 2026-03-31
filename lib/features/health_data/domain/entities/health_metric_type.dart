/// Тип метрики здоровья в доменной модели.
enum HealthMetricType {
  activeEnergyBurned,
  atrialFibrillationBurden,
  audiogram,
  basalEnergyBurned,
  bloodGlucose,
  bloodOxygen,
  bloodPressureDiastolic,
  bloodPressureSystolic,
  bodyFatPercentage,
  leanBodyMass,
  bodyMassIndex,
  bodyTemperature,
  bodyWaterMass,
  dietaryCarbsConsumed,
  dietaryCaffeine,
  dietaryEnergyConsumed,
  dietaryFatsConsumed,
  dietaryProteinConsumed,
  dietaryFiber,
  dietarySugar,
  dietaryFatMonounsaturated,
  dietaryFatPolyunsaturated,
  dietaryFatSaturated,
  dietaryCholesterol,
  dietaryVitaminA,
  dietaryThiamin,
  dietaryRiboflavin,
  dietaryNiacin,
  dietaryPantothenicAcid,
  dietaryVitaminB6,
  dietaryBiotin,
  dietaryVitaminB12,
  dietaryVitaminC,
  dietaryVitaminD,
  dietaryVitaminE,
  dietaryVitaminK,
  dietaryFolate,
  dietaryCalcium,
  dietaryChloride,
  dietaryIron,
  dietaryMagnesium,
  dietaryPhosphorus,
  dietaryPotassium,
  dietarySodium,
  dietaryZinc,
  dietaryChromium,
  dietaryCopper,
  dietaryIodine,
  dietaryManganese,
  dietaryMolybdenum,
  dietarySelenium,
  forcedExpiratoryVolume,
  heartRate,
  heartRateVariabilitySdnn,
  heartRateVariabilityRmssd,
  height,
  insulinDelivery,
  restingHeartRate,
  respiratoryRate,
  peripheralPerfusionIndex,
  steps,
  waistCircumference,
  walkingHeartRate,
  weight,
  distanceWalkingRunning,
  distanceSwimming,
  distanceCycling,
  flightsClimbed,
  distanceDelta,
  mindfulness,
  water,
  sleep,
  sleepAsleep,
  sleepAwakeInBed,
  sleepAwake,
  sleepDeep,
  sleepInBed,
  sleepLight,
  sleepOutOfBed,
  sleepRem,
  sleepSession,
  sleepUnknown,
  exerciseTime,
  workout,
  headacheNotPresent,
  headacheMild,
  headacheModerate,
  headacheSevere,
  headacheUnspecified,
  nutrition,
  uvIndex,
  gender,
  birthDate,
  bloodType,
  menstruationFlow,
  waterTemperature,
  underwaterDepth,
  highHeartRateEvent,
  lowHeartRateEvent,
  irregularHeartRateEvent,
  electrodermalActivity,
  electrocardiogram,
  totalCaloriesBurned,

  // Типы из текущей дизайн-спеки, которые могут отсутствовать в конкретной
  // версии package:health или на текущей платформе.
  walkingSpeed,
  workoutRoute,
  sleepWristTemperature,
  skinTemperature,
  appleMoveTime,
  appleStandHour,

  unknown,
}

extension HealthMetricTypeX on HealthMetricType {
  /// Ключ сериализации.
  String get key => this == HealthMetricType.unknown ? 'unknown' : name;

  /// Имя типа в package:health (`HealthDataType`).
  String? get platformTypeName {
    if (this == HealthMetricType.unknown) {
      return null;
    }

    if (this == HealthMetricType.sleep) {
      return 'SLEEP_ASLEEP';
    }

    return _camelToUpperSnake(name);
  }

  /// Человекочитаемое название метрики.
  String get displayName {
    if (this == HealthMetricType.unknown) {
      return 'Unknown';
    }

    final source = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return source
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Создает тип метрики из строкового ключа.
  static HealthMetricType fromKey(String? key) {
    if (key == null || key.isEmpty) {
      return HealthMetricType.unknown;
    }

    final normalizedInput = _normalizeKey(key);

    // 1) Сначала пытаемся сопоставить по доменному ключу (one-to-one).
    for (final type in HealthMetricType.values) {
      if (type == HealthMetricType.unknown) {
        continue;
      }

      if (_normalizeKey(type.key) == normalizedInput) {
        return type;
      }
    }

    // 2) Затем — по платформенному имени `HealthDataType`.
    for (final type in HealthMetricType.values) {
      if (type == HealthMetricType.unknown) {
        continue;
      }
      final platformName = type.platformTypeName;
      if (platformName != null &&
          _normalizeKey(platformName) == normalizedInput) {
        return type;
      }
    }

    return HealthMetricType.unknown;
  }

  static String _normalizeKey(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }

  static String _camelToUpperSnake(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toUpperCase();
  }
}
