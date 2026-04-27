import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/dashboard/data/services/baseline_forecast_inference_model.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';

void main() {
  group('BaselineForecastInferenceModel', () {
    late BaselineForecastInferenceModel model;
    late DateTime now;

    setUp(() {
      model = BaselineForecastInferenceModel();
      now = DateTime.utc(2026, 4, 26, 23, 30);
    });

    test('builds personal expected values and deviations', () {
      final result = model.inferSync(
        samples: _baselineSamples(now, days: 35) + _deviatedCurrentDay(now),
        now: now,
      );

      expect(result.modelId, BaselineForecastInferenceModel.modelId);
      expect(result.source, 'median_ewma_ridge_blend');
      expect(result.insufficientData, isFalse);
      expect(result.overallDeviationScore, greaterThan(30));
      expect(result.summary.mainReasons, contains('resting_hr_above_expected'));
      expect(result.features['daily_feature_vector'], isA<Map>());

      final restingHr = result.metrics['resting_hr']!;
      expect(restingHr.expected, closeTo(61, 4));
      expect(restingHr.actual, 76);
      expect(restingHr.delta, greaterThan(10));
      expect(restingHr.severity, isIn(['moderate', 'high']));
      expect(restingHr.featureSnapshot['lag_1'], isNotNull);
      expect(restingHr.featureSnapshot['rolling_median_30'], isNotNull);

      final hrv = result.metrics['hrv']!;
      expect(hrv.expected, closeTo(58, 8));
      expect(hrv.delta, lessThan(0));
      expect(result.summary.mainReasons, contains('hrv_below_expected'));
    });

    test('uses median and EWMA warm start for 7 to 13 days', () {
      final result = model.inferSync(
        samples: _baselineSamples(now, days: 10) + _normalCurrentDay(now),
        now: now,
      );

      final restingHr = result.metrics['resting_hr']!;
      expect(result.source, 'rolling_median_ewma');
      expect(restingHr.method, 'rolling_median_ewma');
      expect(restingHr.expected, closeTo(61, 4));
      expect(restingHr.confidence, greaterThan(0.35));
    });

    test('keeps cold start low confidence without deviations', () {
      final result = model.inferSync(
        samples: _baselineSamples(now, days: 2) + _deviatedCurrentDay(now),
        now: now,
      );

      expect(result.insufficientData, isTrue);
      expect(result.status, 'insufficient');
      expect(result.source, 'cold_start');
      expect(result.overallDeviationScore, isNull);

      final restingHr = result.metrics['resting_hr']!;
      expect(restingHr.expected, isNull);
      expect(restingHr.delta, isNull);
      expect(restingHr.severity, 'insufficient');
      expect(restingHr.confidence, lessThanOrEqualTo(0.2));
    });

    test('marks current-day cumulative activity as partial before evening', () {
      final midday = DateTime.utc(2026, 4, 26, 12);
      final result = model.inferSync(
        samples: _baselineSamples(midday, days: 14) + _middayCurrentDay(midday),
        now: midday,
      );

      final steps = result.metrics['steps']!;
      expect(steps.actual, isNotNull);
      expect(steps.actualIsPartial, isTrue);
      expect(steps.delta, isNull);
      expect(steps.severity, 'pending');

      final restingHr = result.metrics['resting_hr']!;
      expect(restingHr.actualIsPartial, isFalse);
      expect(restingHr.delta, isNotNull);
    });
  });
}

List<HealthMetricSample> _baselineSamples(DateTime now, {required int days}) {
  return List.generate(days, (index) => index + 1)
      .map((day) => _baselineDay(now, dayOffset: day))
      .expand((items) => items)
      .toList(growable: false);
}

List<HealthMetricSample> _baselineDay(DateTime now, {required int dayOffset}) {
  final base = DateTime.utc(
    now.year,
    now.month,
    now.day,
    8,
  ).subtract(Duration(days: dayOffset));
  final jitter = dayOffset.isEven ? 1.0 : -1.0;
  final weekendActivity = base.weekday >= DateTime.saturday ? -1300.0 : 0.0;

  return [
    _sample(HealthMetricType.restingHeartRate, 61 + jitter, base),
    _sample(
      HealthMetricType.heartRateVariabilityRmssd,
      58 + (jitter * 2),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      14.2 + (jitter * 0.2),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepWristTemperature,
      36.35 + (jitter * 0.03),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.bloodOxygen,
      97.2 + (jitter * 0.2),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepAsleep,
      440 + (jitter * 10),
      base.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepDeep,
      88 + jitter,
      base.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepRem,
      96 + jitter,
      base.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.sleepAwake,
      24,
      base.subtract(const Duration(minutes: 45)),
    ),
    _sample(
      HealthMetricType.steps,
      8500 + weekendActivity + (jitter * 100),
      base.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.activeEnergyBurned,
      520 + (jitter * 20),
      base.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.exerciseTime,
      42 + jitter,
      base.add(const Duration(hours: 12)),
    ),
  ];
}

List<HealthMetricSample> _deviatedCurrentDay(DateTime now) {
  final base = DateTime.utc(now.year, now.month, now.day, 8);
  return [
    _sample(HealthMetricType.restingHeartRate, 76, base),
    _sample(
      HealthMetricType.heartRateVariabilityRmssd,
      34,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      18.8,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepWristTemperature,
      36.95,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.bloodOxygen,
      94,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepAsleep,
      310,
      base.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepDeep,
      35,
      base.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepRem,
      42,
      base.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.sleepAwake,
      70,
      base.subtract(const Duration(minutes: 45)),
    ),
    _sample(HealthMetricType.steps, 4200, base.add(const Duration(hours: 12))),
    _sample(
      HealthMetricType.activeEnergyBurned,
      260,
      base.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.exerciseTime,
      8,
      base.add(const Duration(hours: 12)),
    ),
  ];
}

List<HealthMetricSample> _normalCurrentDay(DateTime now) {
  return _baselineDay(now, dayOffset: 0);
}

List<HealthMetricSample> _middayCurrentDay(DateTime now) {
  final base = DateTime.utc(now.year, now.month, now.day, 8);
  return [
    _sample(HealthMetricType.restingHeartRate, 62, base),
    _sample(
      HealthMetricType.heartRateVariabilityRmssd,
      57,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(HealthMetricType.steps, 2400, base.add(const Duration(hours: 3))),
  ];
}

HealthMetricSample _sample(
  HealthMetricType type,
  double value,
  DateTime timestamp,
) {
  return HealthMetricSample(
    id: '${type.name}_${timestamp.toIso8601String()}_$value',
    type: type,
    value: value,
    unit: '',
    timestamp: timestamp,
    sourceId: 'apple_health',
  );
}
