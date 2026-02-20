import 'package:equatable/equatable.dart';
import 'health_metric_type.dart';

/// Отдельное измерение метрики здоровья.
class HealthMetricSample extends Equatable {
  /// Уникальный идентификатор измерения.
  final String id;

  /// Тип метрики.
  final HealthMetricType type;

  /// Значение метрики.
  final double value;

  /// Единица измерения.
  final String unit;

  /// Время фиксации значения.
  final DateTime timestamp;

  /// Идентификатор источника данных.
  final String sourceId;

  /// Создает измерение метрики здоровья.
  const HealthMetricSample({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.sourceId,
  });

  @override
  List<Object> get props => [
        id,
        type,
        value,
        unit,
        timestamp,
        sourceId,
      ];
}
