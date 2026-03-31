import '../../features/health_data/domain/entities/health_metric_type.dart';

class HealthMetricCatalog {
  HealthMetricCatalog._();

  /// MVP-метрики из Product brief (`Project 54.csv`).
  static const List<String> project54PriorityMetrics = [
    'steps',
    'heart_rate',
    'sleep',
    'weight',
    'blood_pressure',
    'blood_glucose',
    'blood_oxygen',
  ];

  /// Безопасный practical-набор для реального чтения из HealthKit/Health Connect.
  /// Используется как дефолт, когда в query не указаны конкретные типы.
  static const List<HealthMetricType> project54PriorityTypes = [
    HealthMetricType.steps,
    HealthMetricType.heartRate,
    HealthMetricType.sleep,
    HealthMetricType.weight,
    HealthMetricType.bloodPressureSystolic,
    HealthMetricType.bloodPressureDiastolic,
    HealthMetricType.bloodGlucose,
    HealthMetricType.bloodOxygen,
    HealthMetricType.activeEnergyBurned,
    HealthMetricType.distanceWalkingRunning,
    HealthMetricType.respiratoryRate,
    HealthMetricType.bodyTemperature,
  ];
}
