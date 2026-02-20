/// Тип метрики здоровья.
enum HealthMetricType {
  /// Частота сердечных сокращений.
  heartRate,

  /// Количество шагов.
  steps,

  /// Сон.
  sleep,

  /// Насыщение крови кислородом.
  bloodOxygen,

  /// Вес.
  weight,

  /// Неизвестный тип.
  unknown,
}

/// Утилиты для работы с типами метрик.
extension HealthMetricTypeX on HealthMetricType {
  /// Ключ для сериализации в JSON.
  String get key => switch (this) {
        HealthMetricType.heartRate => 'heartRate',
        HealthMetricType.steps => 'steps',
        HealthMetricType.sleep => 'sleep',
        HealthMetricType.bloodOxygen => 'bloodOxygen',
        HealthMetricType.weight => 'weight',
        HealthMetricType.unknown => 'unknown',
      };

  /// Создает тип метрики из строкового ключа.
  static HealthMetricType fromKey(String? key) {
    switch (key) {
      case 'heartRate':
        return HealthMetricType.heartRate;
      case 'steps':
        return HealthMetricType.steps;
      case 'sleep':
        return HealthMetricType.sleep;
      case 'bloodOxygen':
        return HealthMetricType.bloodOxygen;
      case 'weight':
        return HealthMetricType.weight;
      default:
        return HealthMetricType.unknown;
    }
  }
}
