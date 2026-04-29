import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/dashboard/data/services/stress_inference_model.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StressInferenceModel', () {
    late StressInferenceModel model;
    late DateTime now;

    setUp(() {
      model = StressInferenceModel();
      now = DateTime.utc(2026, 4, 26, 12, 0);
    });

    test('returns scorecard result for elevated HR and low HRV', () {
      final samples = _highStressSamples(now);

      final result = model.inferSync(samples: samples, now: now);

      expect(result.source, 'scorecard_logistic_default');
      expect(result.insufficientData, isFalse);
      expect(result.stressScore, greaterThan(40));
      expect(result.confidence, greaterThanOrEqualTo(0.45));
      expect(result.features['hr_mean_5m'], isNotNull);
      expect(result.features['hr_z_5m_14'], isNotNull);
      expect(result.features['steps_5m'], isNotNull);
      expect(
        result.reasonCodes.map((reason) => reason.code),
        contains('elevated_hr_vs_baseline'),
      );
      expect(
        result.reasonCodes.map((reason) => reason.code),
        contains('low_hrv_vs_baseline'),
      );
    });

    test('loads trained scorecard artifact for async inference', () async {
      final result = await model.infer(
        samples: _highStressSamples(now),
        now: now,
      );

      expect(result.source, 'scorecard_logistic_trained');
      expect(result.insufficientData, isFalse);
      expect(result.modelVersion, 'stress-scorecard-v1');
      expect(result.modelContributions, isNotEmpty);
    });

    test('uses fallback when recent workout can confound heart rate', () {
      final samples = <HealthMetricSample>[
        ..._baselineHeartRate(now, bpm: 72),
        ..._sleepHistory(now, hours: 7.5),
        ..._currentHeartRate(now, bpm: 112),
        _sample(
          HealthMetricType.workout,
          1,
          now.subtract(const Duration(minutes: 20)),
        ),
      ];

      final result = model.inferSync(
        samples: samples,
        now: now,
        fallbackHealthScore: 78,
      );

      expect(result.source, 'fallback_rule_based');
      expect(result.insufficientData, isTrue);
      expect(result.reason, 'recent_workout_context');
      expect(result.stressScore, 22);
    });

    test('uses fallback when recent steps can confound heart rate', () {
      final samples = <HealthMetricSample>[
        ..._baselineHeartRate(now, bpm: 72),
        ..._sleepHistory(now, hours: 7.5),
        ..._currentHeartRate(now, bpm: 98),
        _sample(
          HealthMetricType.steps,
          3036,
          now.subtract(const Duration(minutes: 5)),
        ),
      ];

      final result = model.inferSync(samples: samples, now: now);

      expect(result.source, 'fallback_rule_based');
      expect(result.insufficientData, isTrue);
      expect(result.reason, 'recent_activity_context');
      expect(
        result.reasonCodes.map((reason) => reason.code),
        contains('recent_activity_context'),
      );
    });

    test('does not run scorecard without heart rate', () {
      final samples = <HealthMetricSample>[
        _sample(
          HealthMetricType.steps,
          1200,
          now.subtract(const Duration(minutes: 5)),
        ),
        _sample(
          HealthMetricType.sleepAsleep,
          450,
          now.subtract(const Duration(hours: 4)),
        ),
      ];

      final result = model.inferSync(
        samples: samples,
        now: now,
        fallbackHealthScore: 80,
      );

      expect(result.source, 'fallback_rule_based');
      expect(result.insufficientData, isTrue);
      expect(result.reason, 'missing_heart_rate');
      expect(result.missingModalities, contains('heart_rate'));
    });

    test(
      'infers reduced efficiency for fragmented sleep without awake samples',
      () {
        final samples = <HealthMetricSample>[
          ..._baselineHeartRate(now, bpm: 72),
          ..._baselineHrv(now, sdnn: 62, rmssd: 58),
          ..._baselineResp(now, value: 14),
          ..._sleepHistory(now, hours: 7.5),
          ..._currentHeartRate(now, bpm: 76),
          _sample(
            HealthMetricType.sleepAsleep,
            180,
            DateTime.utc(2026, 4, 26, 1, 0),
          ),
          _sample(
            HealthMetricType.sleepAsleep,
            150,
            DateTime.utc(2026, 4, 26, 6, 30),
          ),
        ];

        final result = model.inferSync(samples: samples, now: now);

        expect(result.features['sleep_hours_latest'], closeTo(5.5, 0.05));
        expect(result.features['sleep_efficiency_latest'], closeTo(64.7, 0.6));
      },
    );
  });
}

List<HealthMetricSample> _highStressSamples(DateTime now) {
  return <HealthMetricSample>[
    ..._baselineHeartRate(now, bpm: 72),
    ..._baselineHrv(now, sdnn: 62, rmssd: 58),
    ..._baselineResp(now, value: 14),
    ..._baselineTemperature(now, value: 36.4),
    ..._sleepHistory(now, hours: 7.5),
    ..._currentHeartRate(now, bpm: 104),
    _sample(
      HealthMetricType.restingHeartRate,
      92,
      now.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilitySdnn,
      28,
      now.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilityRmssd,
      24,
      now.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      19,
      now.subtract(const Duration(minutes: 25)),
    ),
    _sample(
      HealthMetricType.sleepAsleep,
      330,
      now.subtract(const Duration(hours: 4)),
    ),
    _sample(
      HealthMetricType.steps,
      40,
      now.subtract(const Duration(minutes: 5)),
    ),
  ];
}

List<HealthMetricSample> _baselineHeartRate(DateTime now, {required int bpm}) {
  return List.generate(10, (index) {
    final day = index + 1;
    return _sample(
      HealthMetricType.heartRate,
      bpm + (index.isEven ? 1 : -1),
      now.subtract(Duration(days: day, minutes: 10)),
    );
  });
}

List<HealthMetricSample> _baselineHrv(
  DateTime now, {
  required int sdnn,
  required int rmssd,
}) {
  return List.generate(10, (index) {
    final day = index + 1;
    return [
      _sample(
        HealthMetricType.heartRateVariabilitySdnn,
        sdnn + (index.isEven ? 2 : -2),
        now.subtract(Duration(days: day, hours: 8)),
      ),
      _sample(
        HealthMetricType.heartRateVariabilityRmssd,
        rmssd + (index.isEven ? 2 : -2),
        now.subtract(Duration(days: day, hours: 8)),
      ),
    ];
  }).expand((items) => items).toList(growable: false);
}

List<HealthMetricSample> _baselineResp(DateTime now, {required int value}) {
  return List.generate(8, (index) {
    final day = index + 1;
    return _sample(
      HealthMetricType.respiratoryRate,
      value + (index.isEven ? 1 : -1),
      now.subtract(Duration(days: day, hours: 2)),
    );
  });
}

List<HealthMetricSample> _baselineTemperature(
  DateTime now, {
  required double value,
}) {
  return List.generate(8, (index) {
    final day = index + 1;
    return _sample(
      HealthMetricType.sleepWristTemperature,
      value + (index.isEven ? 0.05 : -0.05),
      now.subtract(Duration(days: day, hours: 5)),
    );
  });
}

List<HealthMetricSample> _sleepHistory(DateTime now, {required double hours}) {
  return List.generate(7, (index) {
    final day = index + 1;
    return _sample(
      HealthMetricType.sleepAsleep,
      hours * 60,
      now.subtract(Duration(days: day, hours: 4)),
    );
  });
}

List<HealthMetricSample> _currentHeartRate(DateTime now, {required int bpm}) {
  return [
    _sample(
      HealthMetricType.heartRate,
      bpm - 3,
      now.subtract(const Duration(minutes: 12)),
    ),
    _sample(
      HealthMetricType.heartRate,
      bpm.toDouble(),
      now.subtract(const Duration(minutes: 8)),
    ),
    _sample(
      HealthMetricType.heartRate,
      bpm + 2,
      now.subtract(const Duration(minutes: 4)),
    ),
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
