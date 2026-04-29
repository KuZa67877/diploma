import '../../domain/entities/health_metric_sample.dart';
import '../../domain/entities/health_metric_type.dart';

/// Модель измерения метрики для слоя Data.
class HealthMetricSampleModel extends HealthMetricSample {
  /// Создает модель измерения метрики.
  const HealthMetricSampleModel({
    required super.id,
    required super.type,
    required super.value,
    required super.unit,
    required super.timestamp,
    super.intervalStart,
    super.intervalEnd,
    required super.sourceId,
  });

  /// Создает модель из JSON.
  factory HealthMetricSampleModel.fromJson(Map<String, dynamic> json) {
    return HealthMetricSampleModel(
      id: json['id'] as String? ?? '',
      type: HealthMetricTypeX.fromKey(json['type'] as String?),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.tryParse(json['intervalEnd'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      intervalStart: DateTime.tryParse(json['intervalStart'] as String? ?? ''),
      intervalEnd: DateTime.tryParse(json['intervalEnd'] as String? ?? ''),
      sourceId: json['sourceId'] as String? ?? '',
    );
  }

  /// Преобразует модель в JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.key,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'intervalStart': intervalStart?.toIso8601String(),
      'intervalEnd': intervalEnd?.toIso8601String(),
      'sourceId': sourceId,
    };
  }
}
