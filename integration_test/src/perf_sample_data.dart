import 'package:medi_ai/core/supabase/onboarding_profile_snapshot.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';

OnboardingProfileSnapshot buildPerfProfile() {
  return OnboardingProfileSnapshot(
    firstName: 'Alex',
    lastName: 'Johnson',
    fullName: 'Alex Johnson',
    email: 'alex@example.com',
    age: 29,
    sex: 'male',
    heightCm: 178,
    weightKg: 72.4,
    systolic: 118,
    diastolic: 76,
    glucose: 92,
    temperatureC: 36.5,
    recordedAt: DateTime.utc(2026, 5, 1),
    completedAt: DateTime.utc(2026, 5, 1),
    symptoms: const <String>[],
    wellbeingEntriesCount: 6,
    healthSamplesCount: 0,
    connectedHealthSourceIds: const <String>['apple_health'],
    wellbeingEntryDates: const <DateTime>[],
  );
}

List<HealthMetricSample> buildPerfSamples(DateTime now) {
  final samples = <HealthMetricSample>[];

  for (var day = 21; day >= 1; day--) {
    final dayStart = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: day));
    final sleepMinutes = 420 + (day % 5) * 12;
    final sleepEnd = DateTime.utc(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      6,
      30,
    );
    samples.add(
      _sample(
        HealthMetricType.sleepAsleep,
        sleepMinutes.toDouble(),
        sleepEnd,
        intervalStart: sleepEnd.subtract(Duration(minutes: sleepMinutes)),
        intervalEnd: sleepEnd,
      ),
    );

    samples.add(
      _sample(
        HealthMetricType.steps,
        (6400 + (day % 7) * 380).toDouble(),
        dayStart.add(const Duration(hours: 20)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.activeEnergyBurned,
        (430 + (day % 6) * 24).toDouble(),
        dayStart.add(const Duration(hours: 20, minutes: 5)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.distanceWalkingRunning,
        4200 + (day % 6) * 210,
        dayStart.add(const Duration(hours: 20, minutes: 10)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.heartRate,
        68 + (day.isEven ? 3 : -2),
        dayStart.add(const Duration(hours: 12)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.restingHeartRate,
        58 + (day % 4),
        dayStart.add(const Duration(hours: 8)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.heartRateVariabilitySdnn,
        52 + (day % 5) * 2,
        dayStart.add(const Duration(hours: 7, minutes: 30)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.heartRateVariabilityRmssd,
        47 + (day % 4) * 2,
        dayStart.add(const Duration(hours: 7, minutes: 35)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.respiratoryRate,
        13 + (day % 3),
        dayStart.add(const Duration(hours: 9)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.sleepWristTemperature,
        36.4 + (day.isEven ? 0.07 : -0.04),
        dayStart.add(const Duration(hours: 7, minutes: 45)),
      ),
    );
    samples.add(
      _sample(
        HealthMetricType.bloodOxygen,
        97 + (day.isEven ? 1 : 0),
        dayStart.add(const Duration(hours: 7, minutes: 50)),
      ),
    );
  }

  samples.addAll(<HealthMetricSample>[
    _sample(
      HealthMetricType.heartRate,
      92,
      now.subtract(const Duration(minutes: 12)),
    ),
    _sample(
      HealthMetricType.heartRate,
      95,
      now.subtract(const Duration(minutes: 8)),
    ),
    _sample(
      HealthMetricType.heartRate,
      97,
      now.subtract(const Duration(minutes: 4)),
    ),
    _sample(
      HealthMetricType.steps,
      126,
      now.subtract(const Duration(minutes: 5)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilitySdnn,
      34,
      now.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.heartRateVariabilityRmssd,
      30,
      now.subtract(const Duration(hours: 1)),
    ),
    _sample(
      HealthMetricType.respiratoryRate,
      17,
      now.subtract(const Duration(minutes: 25)),
    ),
  ]);

  return samples
    ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
}

HealthMetricSample _sample(
  HealthMetricType type,
  double value,
  DateTime timestamp, {
  DateTime? intervalStart,
  DateTime? intervalEnd,
}) {
  return HealthMetricSample(
    id: '${type.name}_${timestamp.toIso8601String()}_$value',
    type: type,
    value: value,
    unit: '',
    timestamp: timestamp,
    intervalStart: intervalStart,
    intervalEnd: intervalEnd,
    sourceId: 'apple_health',
  );
}
