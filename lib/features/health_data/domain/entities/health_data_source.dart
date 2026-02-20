import 'package:equatable/equatable.dart';
import 'health_data_source_type.dart';
import 'health_metric_type.dart';

/// Описание источника данных здоровья.
class HealthDataSource extends Equatable {
  /// Уникальный идентификатор источника.
  final String id;

  /// Название источника.
  final String name;

  /// Краткое описание источника.
  final String description;

  /// Тип источника.
  final HealthDataSourceType type;

  /// Ключ иконки или идентификатор ресурса.
  final String iconKey;

  /// Поддерживаемые метрики.
  final List<HealthMetricType> supportedMetrics;

  /// Признак активного подключения источника.
  final bool isConnected;

  /// Признак доступности источника в текущем окружении.
  final bool isAvailable;

  /// Создает сущность источника данных.
  const HealthDataSource({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.iconKey,
    required this.supportedMetrics,
    required this.isConnected,
    required this.isAvailable,
  });

  /// Возвращает копию сущности с измененными полями.
  HealthDataSource copyWith({
    bool? isConnected,
    bool? isAvailable,
  }) {
    return HealthDataSource(
      id: id,
      name: name,
      description: description,
      type: type,
      iconKey: iconKey,
      supportedMetrics: supportedMetrics,
      isConnected: isConnected ?? this.isConnected,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  List<Object> get props => [
        id,
        name,
        description,
        type,
        iconKey,
        supportedMetrics,
        isConnected,
        isAvailable,
      ];
}
