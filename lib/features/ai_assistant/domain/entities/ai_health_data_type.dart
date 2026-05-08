import '../../../health_data/domain/entities/health_metric_type.dart';

enum AiHealthDataType {
  healthScore,
  sleep,
  pulse,
  hrv,
  spo2,
  steps,
  activeEnergy,
  distance,
  workouts,
  stress,
  anomalies,
  baseline,
  diary,
  comments,
}

extension AiHealthDataTypeX on AiHealthDataType {
  String get labelKey => switch (this) {
    AiHealthDataType.healthScore => 'aiDataTypeHealthScore',
    AiHealthDataType.sleep => 'aiDataTypeSleep',
    AiHealthDataType.pulse => 'aiDataTypePulse',
    AiHealthDataType.hrv => 'aiDataTypeHrv',
    AiHealthDataType.spo2 => 'aiDataTypeSpo2',
    AiHealthDataType.steps => 'aiDataTypeSteps',
    AiHealthDataType.activeEnergy => 'aiDataTypeActiveEnergy',
    AiHealthDataType.distance => 'aiDataTypeDistance',
    AiHealthDataType.workouts => 'aiDataTypeWorkouts',
    AiHealthDataType.stress => 'aiDataTypeStress',
    AiHealthDataType.anomalies => 'aiDataTypeAnomalies',
    AiHealthDataType.baseline => 'aiDataTypeBaseline',
    AiHealthDataType.diary => 'aiDataTypeDiary',
    AiHealthDataType.comments => 'aiDataTypeComments',
  };

  String get displayText => switch (this) {
    AiHealthDataType.healthScore => 'HealthScore',
    AiHealthDataType.sleep => 'Сон',
    AiHealthDataType.pulse => 'Пульс',
    AiHealthDataType.hrv => 'HRV',
    AiHealthDataType.spo2 => 'SpO2',
    AiHealthDataType.steps => 'Шаги',
    AiHealthDataType.activeEnergy => 'Активная энергия',
    AiHealthDataType.distance => 'Дистанция',
    AiHealthDataType.workouts => 'Тренировки',
    AiHealthDataType.stress => 'Стресс',
    AiHealthDataType.anomalies => 'Аномалии',
    AiHealthDataType.baseline => 'Базовая линия',
    AiHealthDataType.diary => 'Дневниковые отметки',
    AiHealthDataType.comments => 'Комментарии пользователя',
  };

  List<HealthMetricType> get metricTypes => switch (this) {
    AiHealthDataType.sleep => const [
      HealthMetricType.sleep,
      HealthMetricType.sleepAsleep,
      HealthMetricType.sleepLight,
      HealthMetricType.sleepDeep,
      HealthMetricType.sleepRem,
      HealthMetricType.sleepSession,
    ],
    AiHealthDataType.pulse => const [
      HealthMetricType.heartRate,
      HealthMetricType.restingHeartRate,
      HealthMetricType.walkingHeartRate,
    ],
    AiHealthDataType.hrv => const [
      HealthMetricType.heartRateVariabilitySdnn,
      HealthMetricType.heartRateVariabilityRmssd,
    ],
    AiHealthDataType.spo2 => const [HealthMetricType.bloodOxygen],
    AiHealthDataType.steps => const [HealthMetricType.steps],
    AiHealthDataType.activeEnergy => const [
      HealthMetricType.activeEnergyBurned,
      HealthMetricType.totalCaloriesBurned,
    ],
    AiHealthDataType.distance => const [
      HealthMetricType.distanceWalkingRunning,
      HealthMetricType.distanceCycling,
      HealthMetricType.distanceSwimming,
    ],
    AiHealthDataType.workouts => const [
      HealthMetricType.workout,
      HealthMetricType.exerciseTime,
    ],
    _ => const <HealthMetricType>[],
  };
}
