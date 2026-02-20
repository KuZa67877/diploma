/// Тип источника данных здоровья.
enum HealthDataSourceType {
  /// Локальные данные, собранные в приложении.
  local,

  /// Данные из Apple Health (HealthKit).
  appleHealth,

  /// Данные из Google Fit.
  googleFit,

  /// Неизвестный тип.
  unknown,
}

/// Утилиты для работы с типами источников.
extension HealthDataSourceTypeX on HealthDataSourceType {
  /// Ключ для сериализации в JSON.
  String get key => switch (this) {
        HealthDataSourceType.local => 'local',
        HealthDataSourceType.appleHealth => 'appleHealth',
        HealthDataSourceType.googleFit => 'googleFit',
        HealthDataSourceType.unknown => 'unknown',
      };

  /// Создает тип источника из строкового ключа.
  static HealthDataSourceType fromKey(String? key) {
    switch (key) {
      case 'local':
        return HealthDataSourceType.local;
      case 'appleHealth':
        return HealthDataSourceType.appleHealth;
      case 'googleFit':
        return HealthDataSourceType.googleFit;
      default:
        return HealthDataSourceType.unknown;
    }
  }
}
