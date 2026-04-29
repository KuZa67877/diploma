import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/dashboard/data/services/physiology_anomaly_inference_model.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';

void main() {
  group('PhysiologyAnomalyInferenceModel', () {
    late PhysiologyAnomalyInferenceModel model;
    late DateTime now;

    setUp(() {
      model = PhysiologyAnomalyInferenceModel();
      now = DateTime.utc(2026, 4, 26, 23, 59);
    });

    test('scores unusual recovery profile against personal baseline', () {
      final result = model.inferSync(
        samples: _baselineSamples(now) + _anomalousCurrentDay(now),
        now: now,
      );

      expect(result.source, 'isolation_forest_v1_5');
      expect(result.anomalyScore, greaterThan(45));
      expect(result.confidence, greaterThan(0.45));
      expect(result.features['isolation_forest_score'], isNotNull);
      expect(result.features['isolation_forest_training_days'], greaterThan(0));
      expect(
        result.reasonCodes.map((reason) => reason.code),
        containsAll([
          'recovery_profile_unusual',
          'resting_hr_above_baseline',
          'hrv_below_baseline',
          'sleep_duration_below_baseline',
        ]),
      );
      expect(
        result.groupScores.map((group) => group.code),
        contains('recovery_deviation_score'),
      );
    });

    test('uses low-confidence fallback before 7 baseline days', () {
      final shortHistory = <HealthMetricSample>[
        ..._baselineDay(now, dayOffset: 2),
        ..._baselineDay(now, dayOffset: 1),
        ..._anomalousCurrentDay(now),
      ];

      final result = model.inferSync(samples: shortHistory, now: now);

      expect(result.source, 'fallback_rule_based');
      expect(result.insufficientData, isTrue);
      expect(result.confidence, lessThanOrEqualTo(0.35));
      expect(
        result.reasonCodes.map((reason) => reason.code),
        contains('insufficient_data'),
      );
    });

    test('exports expected JSON contract', () {
      final result = model.inferSync(
        samples: _baselineSamples(now) + _anomalousCurrentDay(now),
        now: now,
      );
      final json = result.toJson();

      expect(json['model_id'], PhysiologyAnomalyInferenceModel.modelId);
      expect(
        json['model_version'],
        PhysiologyAnomalyInferenceModel.modelVersion,
      );
      expect(json['anomaly_score'], isA<double>());
      expect(json['confidence'], isA<double>());
      expect(json['reason_codes'], isA<List<dynamic>>());
      expect(json['data_quality'], isA<Map<String, dynamic>>());
    });

    test(
      'treats gaps between sleep segments as fragmentation when awake is absent',
      () {
        final fragmentedCurrentDay = <HealthMetricSample>[
          _sample(
            HealthMetricType.restingHeartRate,
            61,
            DateTime.utc(2026, 4, 26, 8),
          ),
          _sample(
            HealthMetricType.heartRate,
            66,
            DateTime.utc(2026, 4, 26, 12),
          ),
          _sample(HealthMetricType.heartRate, 56, DateTime.utc(2026, 4, 26, 6)),
          _sample(
            HealthMetricType.heartRateVariabilitySdnn,
            62,
            DateTime.utc(2026, 4, 26, 7),
          ),
          _sample(
            HealthMetricType.respiratoryRate,
            14,
            DateTime.utc(2026, 4, 26, 7),
          ),
          _sample(
            HealthMetricType.sleepWristTemperature,
            36.4,
            DateTime.utc(2026, 4, 26, 7),
          ),
          _sample(
            HealthMetricType.bloodOxygen,
            97,
            DateTime.utc(2026, 4, 26, 7),
          ),
          _sample(
            HealthMetricType.sleepAsleep,
            180,
            DateTime.utc(2026, 4, 26, 1),
          ),
          _sample(
            HealthMetricType.sleepAsleep,
            150,
            DateTime.utc(2026, 4, 26, 6, 30),
          ),
          _sample(HealthMetricType.steps, 8200, DateTime.utc(2026, 4, 26, 20)),
          _sample(
            HealthMetricType.activeEnergyBurned,
            510,
            DateTime.utc(2026, 4, 26, 20),
          ),
        ];

        final result = model.inferSync(
          samples: _baselineSamples(now) + fragmentedCurrentDay,
          now: now,
        );

        expect(result.features['sleep_total_minutes'], closeTo(330, 0.1));
        expect(result.features['sleep_awake_minutes'], closeTo(180, 0.1));
        expect(
          result.features['sleep_fragmentation_index'],
          closeTo(0.353, 0.01),
        );
      },
    );
  });
}

List<HealthMetricSample> _baselineSamples(DateTime now) {
  return List.generate(35, (index) => index + 1)
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
  return [
    _sample(HealthMetricType.restingHeartRate, 60 + jitter, base),
    _sample(
      HealthMetricType.heartRate,
      68 + jitter,
      base.add(const Duration(hours: 4)),
    ),
    _sample(
      HealthMetricType.heartRate,
      57 + jitter,
      base.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilitySdnn,
      64 + jitter,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      14 + (jitter * 0.2),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepWristTemperature,
      36.35 + (jitter * 0.03),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.bloodOxygen,
      97 + (jitter * 0.2),
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepDeep,
      90 + jitter,
      base.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepLight,
      260 + jitter,
      base.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.sleepRem,
      95 + jitter,
      base.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepAwake,
      25,
      base.subtract(const Duration(minutes: 30)),
    ),
    _sample(
      HealthMetricType.steps,
      8500 + (jitter * 100),
      base.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.distanceWalkingRunning,
      6200 + (jitter * 80),
      base.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.activeEnergyBurned,
      520 + (jitter * 20),
      base.add(const Duration(hours: 12)),
    ),
  ];
}

List<HealthMetricSample> _anomalousCurrentDay(DateTime now) {
  final morning = DateTime.utc(now.year, now.month, now.day, 8);
  return [
    _sample(HealthMetricType.restingHeartRate, 82, morning),
    _sample(
      HealthMetricType.heartRate,
      92,
      morning.add(const Duration(hours: 4)),
    ),
    _sample(
      HealthMetricType.heartRate,
      74,
      morning.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilitySdnn,
      28,
      morning.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      19,
      morning.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepWristTemperature,
      37.0,
      morning.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.bloodOxygen,
      93,
      morning.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepDeep,
      30,
      morning.subtract(const Duration(hours: 3)),
    ),
    _sample(
      HealthMetricType.sleepLight,
      210,
      morning.subtract(const Duration(hours: 2)),
    ),
    _sample(
      HealthMetricType.sleepRem,
      35,
      morning.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.sleepAwake,
      85,
      morning.subtract(const Duration(minutes: 30)),
    ),
    _sample(
      HealthMetricType.steps,
      700,
      morning.add(const Duration(hours: 12)),
    ),
    _sample(
      HealthMetricType.activeEnergyBurned,
      90,
      morning.add(const Duration(hours: 12)),
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
