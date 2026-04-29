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
  ///
  /// Для совместимости продолжает хранить "основную" временную точку записи.
  /// Для интервальных данных это конец интервала.
  final DateTime timestamp;

  /// Начало интервала, если источник отдал raw interval.
  final DateTime? intervalStart;

  /// Конец интервала, если источник отдал raw interval.
  ///
  /// Если отсутствует, используется [timestamp].
  final DateTime? intervalEnd;

  /// Идентификатор источника данных.
  final String sourceId;

  /// Создает измерение метрики здоровья.
  const HealthMetricSample({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.intervalStart,
    this.intervalEnd,
    required this.sourceId,
  });

  /// Эффективное начало интервала с fallback на legacy timestamp.
  DateTime get startAt => intervalStart?.toUtc() ?? timestamp.toUtc();

  /// Эффективный конец интервала с fallback на legacy timestamp.
  DateTime get endAt => intervalEnd?.toUtc() ?? timestamp.toUtc();

  /// Длительность интервала в минутах, если он задан явно и валиден.
  double? get intervalMinutes {
    final start = intervalStart?.toUtc();
    final end = intervalEnd?.toUtc();
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    return end.difference(start).inMilliseconds / 60000.0;
  }

  @override
  List<Object?> get props => [
        id,
        type,
        value,
        unit,
    timestamp,
    intervalStart,
    intervalEnd,
    sourceId,
  ];
}
