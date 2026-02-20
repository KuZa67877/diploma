import 'package:health/health.dart';
import '../../domain/entities/health_metric_type.dart';
import '../models/health_metric_sample_model.dart';

/// Маппинг метрик здоровья между доменом и платформенным SDK.
class HealthPlatformMapper {
  /// Возвращает список типов данных для запроса.
  static List<HealthDataType> toPlatformTypes(
    List<HealthMetricType> types,
  ) {
    if (types.isEmpty) {
      return _supportedTypes;
    }

    return types
        .map(_mapMetricType)
        .whereType<HealthDataType>()
        .toList(growable: false);
  }

  /// Преобразует платформенную точку в модель.
  static HealthMetricSampleModel toSample(
    HealthDataPoint point, {
    required String fallbackSourceId,
  }) {
    final value = _extractNumericValue(point);
    final unit = point.unit.name;
    final sourceId = point.sourceId.isNotEmpty
        ? point.sourceId
        : fallbackSourceId;

    return HealthMetricSampleModel(
      id: '${point.type.name}_${point.dateTo.toIso8601String()}_$sourceId',
      type: _mapPlatformType(point.type),
      value: value,
      unit: unit,
      timestamp: point.dateTo,
      sourceId: sourceId,
    );
  }

  static const Map<HealthMetricType, String> _metricTypeNames = {
    HealthMetricType.heartRate: 'HEART_RATE',
    HealthMetricType.steps: 'STEPS',
    HealthMetricType.sleep: 'SLEEP_ASLEEP',
    HealthMetricType.bloodOxygen: 'BLOOD_OXYGEN',
    HealthMetricType.weight: 'WEIGHT',
  };

  static HealthDataType? _mapMetricType(HealthMetricType type) {
    final name = _metricTypeNames[type];
    return name == null ? null : _typeByName(name);
  }

  static HealthMetricType _mapPlatformType(HealthDataType type) {
    switch (type.name) {
      case 'HEART_RATE':
        return HealthMetricType.heartRate;
      case 'STEPS':
        return HealthMetricType.steps;
      case 'SLEEP':
      case 'SLEEP_ASLEEP':
        return HealthMetricType.sleep;
      case 'BLOOD_OXYGEN':
      case 'BLOOD_OXYGEN_SATURATION':
        return HealthMetricType.bloodOxygen;
      case 'WEIGHT':
        return HealthMetricType.weight;
      default:
        return HealthMetricType.unknown;
    }
  }

  static List<HealthDataType> get _supportedTypes {
    final result = <HealthDataType>[];
    for (final name in _metricTypeNames.values) {
      final type = _typeByName(name);
      if (type != null) {
        result.add(type);
      }
    }
    return result;
  }

  static HealthDataType? _typeByName(String name) {
    for (final type in HealthDataType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return null;
  }

  static double _extractNumericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return 0;
  }
}
