import 'dart:io';
import 'package:health/health.dart';
import '../../domain/entities/health_metric_type.dart';
import '../models/health_metric_sample_model.dart';

/// Маппинг метрик здоровья между доменом и платформенным SDK.
class HealthPlatformMapper {
  /// Возвращает список типов данных для запроса.
  static List<HealthDataType> toPlatformTypes(List<HealthMetricType> types) {
    final requestedTypes = types.isEmpty
        ? supportedMetricsForCurrentPlatform
        : types;
    final availableNames = _availablePlatformTypeNames;

    final result = <HealthDataType>[];
    final added = <String>{};

    for (final metricType in requestedTypes) {
      final platformName = metricType.platformTypeName;
      if (platformName == null || !availableNames.contains(platformName)) {
        continue;
      }
      if (!added.add(platformName)) {
        continue;
      }

      final mapped = _typeByName(platformName);
      if (mapped != null) {
        result.add(mapped);
      }
    }

    return result;
  }

  /// Список доменных метрик, доступных на iOS.
  static List<HealthMetricType> get supportedMetricsForIOS {
    return _mapPlatformList(dataTypeKeysIOS);
  }

  /// Список доменных метрик, доступных на Android.
  static List<HealthMetricType> get supportedMetricsForAndroid {
    return _mapPlatformList(dataTypeKeysAndroid);
  }

  /// Список доменных метрик, доступных на текущей платформе.
  static List<HealthMetricType> get supportedMetricsForCurrentPlatform {
    return Platform.isIOS ? supportedMetricsForIOS : supportedMetricsForAndroid;
  }

  /// Преобразует платформенную точку в модель.
  static HealthMetricSampleModel toSample(
    HealthDataPoint point, {
    required String fallbackSourceId,
  }) {
    final start = point.dateFrom.toUtc();
    final end = point.dateTo.toUtc();
    final metricType = _mapPlatformType(point.type);
    final value = _resolvedValue(point, metricType, start: start, end: end);
    final unit = point.unit.name;
    final sourceId = point.sourceId.isNotEmpty
        ? point.sourceId
        : fallbackSourceId;

    return HealthMetricSampleModel(
      id: '${point.type.name}_${start.toIso8601String()}_${end.toIso8601String()}_$sourceId',
      type: metricType,
      value: value,
      unit: unit,
      timestamp: end,
      intervalStart: start,
      intervalEnd: end,
      sourceId: sourceId,
    );
  }

  static Set<String> get _availablePlatformTypeNames {
    final supportedTypes = Platform.isIOS
        ? dataTypeKeysIOS
        : dataTypeKeysAndroid;
    return supportedTypes.map((item) => item.name).toSet();
  }

  static List<HealthMetricType> _mapPlatformList(List<HealthDataType> types) {
    final mapped = <HealthMetricType>[];
    final added = <HealthMetricType>{};

    for (final type in types) {
      final metricType = _mapPlatformType(type);
      if (metricType == HealthMetricType.unknown) {
        continue;
      }
      if (added.add(metricType)) {
        mapped.add(metricType);
      }
    }

    return mapped;
  }

  static HealthMetricType _mapPlatformType(HealthDataType type) {
    return HealthMetricTypeX.fromKey(type.name);
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

    if (value is WorkoutHealthValue) {
      return (value.totalEnergyBurned ??
              value.totalDistance ??
              value.totalSteps ??
              0)
          .toDouble();
    }

    if (value is ElectrocardiogramHealthValue) {
      return value.averageHeartRate?.toDouble() ?? 0;
    }

    if (value is InsulinDeliveryHealthValue) {
      return value.units;
    }

    return 0;
  }

  static double _resolvedValue(
    HealthDataPoint point,
    HealthMetricType metricType, {
    required DateTime start,
    required DateTime end,
  }) {
    if (_durationBackedSleepTypes.contains(metricType) && end.isAfter(start)) {
      return end.difference(start).inMilliseconds / 60000.0;
    }
    return _extractNumericValue(point);
  }

  static const Set<HealthMetricType> _durationBackedSleepTypes = {
    HealthMetricType.sleep,
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepAwake,
    HealthMetricType.sleepAwakeInBed,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepInBed,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepOutOfBed,
    HealthMetricType.sleepRem,
    HealthMetricType.sleepSession,
    HealthMetricType.sleepUnknown,
  };
}
