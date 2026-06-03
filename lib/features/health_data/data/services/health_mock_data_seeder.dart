import 'dart:io';
import 'dart:math' as math;

import 'package:health/health.dart';

import '../../../../core/logging/app_logger.dart';

class HealthSeedSummary {
  final int daysSeeded;
  final int samplesWritten;
  final List<String> warnings;

  const HealthSeedSummary({
    required this.daysSeeded,
    required this.samplesWritten,
    required this.warnings,
  });
}

class HealthMockDataSeeder {
  final Health _health;
  final _logger = AppLogger.instance;

  HealthMockDataSeeder({Health? health}) : _health = health ?? Health();

  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  List<HealthDataType> get _types =>
      Platform.isAndroid ? _androidTypes : _iosTypes;

  HealthDataType get _distanceType => Platform.isAndroid
      ? HealthDataType.DISTANCE_DELTA
      : HealthDataType.DISTANCE_WALKING_RUNNING;

  HealthDataType get _hrvType => Platform.isAndroid
      ? HealthDataType.HEART_RATE_VARIABILITY_RMSSD
      : HealthDataType.HEART_RATE_VARIABILITY_SDNN;

  static const _androidTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
  ];

  static const _iosTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
  ];

  Future<void> authorize() async {
    if (!isSupported) {
      throw UnsupportedError(
        'HealthKit/Health Connect недоступен на этой платформе.',
      );
    }

    await _health.configure();
    final permissions = List<HealthDataAccess>.filled(
      _types.length,
      HealthDataAccess.READ_WRITE,
    );
    final granted = await _health.requestAuthorization(
      _types,
      permissions: permissions,
    );
    if (!granted) {
      throw StateError('Права на запись в приложение Здоровье не были выданы.');
    }
  }

  Future<HealthSeedSummary> seedLast30Days({bool clearExisting = true}) async {
    await authorize();
    if (clearExisting) {
      await clearLast40Days();
    }

    final now = DateTime.now();
    final rng = math.Random(20260508);
    final warnings = <String>[];
    var written = 0;

    for (var offset = 29; offset >= 0; offset--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: offset));
      final profile = _buildDayProfile(
        day: day,
        rng: rng,
        dayIndex: 29 - offset,
      );

      final dayWrites = await _writeDay(profile, warnings);
      written += dayWrites;
    }

    _logger.info(
      'health.seed',
      'Mock month seeded into Health app',
      payload: {'days': 30, 'samplesWritten': written, 'warnings': warnings},
    );

    return HealthSeedSummary(
      daysSeeded: 30,
      samplesWritten: written,
      warnings: warnings,
    );
  }

  Future<void> clearLast40Days() async {
    await authorize();
    final end = DateTime.now().add(const Duration(days: 1));
    final start = DateTime.now().subtract(const Duration(days: 40));

    for (final type in _types) {
      try {
        await _health.delete(type: type, startTime: start, endTime: end);
      } catch (error, stackTrace) {
        _logger.warning(
          'health.seed',
          'Failed deleting seeded mock data for type',
          payload: {
            'type': type.name,
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
      }
    }
  }

  Future<int> _writeDay(_SeedDayProfile profile, List<String> warnings) async {
    var written = 0;

    for (final segment in profile.sleepSegments) {
      final ok = await _safeWriteData(
        value: 0,
        type: segment.type,
        startTime: segment.start,
        endTime: segment.end,
        warnings: warnings,
      );
      if (ok) {
        written += 1;
      }
    }

    for (final measurement in profile.heartRateMeasurements) {
      final ok = await _safeWriteData(
        value: measurement.value,
        type: measurement.type,
        startTime: measurement.time,
        endTime: measurement.time.add(const Duration(minutes: 1)),
        warnings: warnings,
      );
      if (ok) {
        written += 1;
      }
    }

    final totals = <Future<bool>>[
      _safeWriteData(
        value: profile.steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: profile.eveningAnchor,
        endTime: profile.eveningAnchor.add(const Duration(minutes: 1)),
        warnings: warnings,
      ),
      _safeWriteData(
        value: profile.activeEnergyKcal,
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: profile.eveningAnchor,
        endTime: profile.eveningAnchor.add(const Duration(minutes: 1)),
        warnings: warnings,
      ),
      _safeWriteData(
        value: profile.distanceMeters,
        type: _distanceType,
        startTime: profile.eveningAnchor,
        endTime: profile.eveningAnchor.add(const Duration(minutes: 1)),
        warnings: warnings,
      ),
      _safeWriteData(
        value: profile.restingHeartRate,
        type: HealthDataType.RESTING_HEART_RATE,
        startTime: profile.morningAnchor,
        endTime: profile.morningAnchor.add(const Duration(minutes: 1)),
        warnings: warnings,
      ),
      _safeWriteData(
        value: profile.hrvSdnn,
        type: _hrvType,
        startTime: profile.morningAnchor.add(const Duration(minutes: 8)),
        endTime: profile.morningAnchor.add(const Duration(minutes: 9)),
        warnings: warnings,
      ),
      _safeWriteBloodOxygen(
        saturation: profile.bloodOxygenPct,
        startTime: profile.morningAnchor.add(const Duration(minutes: 12)),
        endTime: profile.morningAnchor.add(const Duration(minutes: 13)),
        warnings: warnings,
      ),
    ];

    final results = await Future.wait(totals);
    written += results.where((item) => item).length;
    return written;
  }

  Future<bool> _safeWriteBloodOxygen({
    required double saturation,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> warnings,
  }) async {
    try {
      return await _health.writeBloodOxygen(
        saturation: saturation,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (error) {
      warnings.add('Не удалось записать SpO2: $error');
      return false;
    }
  }

  Future<bool> _safeWriteData({
    required double value,
    required HealthDataType type,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> warnings,
  }) async {
    try {
      return await _health.writeHealthData(
        value: value,
        type: type,
        startTime: startTime,
        endTime: endTime,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (error) {
      warnings.add('Не удалось записать ${type.name}: $error');
      return false;
    }
  }

  _SeedDayProfile _buildDayProfile({
    required DateTime day,
    required math.Random rng,
    required int dayIndex,
  }) {
    final weekday = day.weekday;
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    final stressPhase = dayIndex >= 11 && dayIndex <= 15;
    final recoveryPhase = dayIndex >= 16 && dayIndex <= 20;

    final bedtimeHour = isWeekend ? 23 : 22;
    final bedtimeMinute = isWeekend ? 40 : 55;
    final sleepStart = DateTime(
      day.year,
      day.month,
      day.day,
      bedtimeHour,
      bedtimeMinute,
    ).subtract(const Duration(days: 1));

    final sleepHoursBase = stressPhase
        ? 5.8 + rng.nextDouble() * 0.5
        : recoveryPhase
        ? 7.7 + rng.nextDouble() * 0.6
        : (isWeekend ? 7.4 : 6.8) + rng.nextDouble() * 0.8;
    final sleepMinutes = (sleepHoursBase * 60).round();
    final awakeMinutes = stressPhase
        ? 28 + rng.nextInt(18)
        : recoveryPhase
        ? 8 + rng.nextInt(10)
        : 10 + rng.nextInt(18);

    final midpoint = sleepStart.add(Duration(minutes: sleepMinutes ~/ 2));
    final awakeStart = midpoint.subtract(Duration(minutes: awakeMinutes ~/ 2));
    final awakeEnd = awakeStart.add(Duration(minutes: awakeMinutes));
    final wakeTime = sleepStart.add(
      Duration(minutes: sleepMinutes + awakeMinutes),
    );

    final totalSteps = stressPhase
        ? 3800 + rng.nextInt(2400)
        : recoveryPhase
        ? 7800 + rng.nextInt(2600)
        : (isWeekend ? 5200 : 7000) + rng.nextInt(3800);
    final activityFactor = totalSteps / 10000.0;
    final activeEnergy = (320 + activityFactor * 260 + rng.nextInt(90))
        .toDouble();
    final distance = totalSteps * (0.67 + rng.nextDouble() * 0.08);

    final restingHr = stressPhase
        ? 68 + rng.nextInt(6)
        : recoveryPhase
        ? 57 + rng.nextInt(4)
        : 60 + rng.nextInt(6);
    final hrvSdnn = stressPhase
        ? 24 + rng.nextInt(10)
        : recoveryPhase
        ? 44 + rng.nextInt(10)
        : 34 + rng.nextInt(10);
    final spo2 = stressPhase
        ? 95 + rng.nextDouble() * 2
        : 96 + rng.nextDouble() * 3;

    final morningAnchor = DateTime(day.year, day.month, day.day, 7, 20);
    final eveningAnchor = DateTime(day.year, day.month, day.day, 20, 15);
    final sleepHrBase = stressPhase
        ? 72
        : recoveryPhase
        ? 60
        : 65;
    final dayHrBase = stressPhase
        ? 90
        : recoveryPhase
        ? 74
        : 80;

    final heartRates = <_PointMeasurement>[
      _PointMeasurement(
        time: sleepStart.add(const Duration(minutes: 90)),
        value: (sleepHrBase + rng.nextInt(5)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
      _PointMeasurement(
        time: midpoint,
        value: (sleepHrBase - 2 + rng.nextInt(5)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
      _PointMeasurement(
        time: wakeTime.subtract(const Duration(minutes: 40)),
        value: (sleepHrBase + 1 + rng.nextInt(5)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
      _PointMeasurement(
        time: DateTime(day.year, day.month, day.day, 10, 0),
        value: (dayHrBase + rng.nextInt(8)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
      _PointMeasurement(
        time: DateTime(day.year, day.month, day.day, 14, 30),
        value: (dayHrBase + 3 + rng.nextInt(10)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
      _PointMeasurement(
        time: DateTime(day.year, day.month, day.day, 18, 20),
        value: (dayHrBase - 2 + rng.nextInt(7)).toDouble(),
        type: HealthDataType.HEART_RATE,
      ),
    ];

    return _SeedDayProfile(
      sleepSegments: [
        _SleepSegment(
          type: HealthDataType.SLEEP_ASLEEP,
          start: sleepStart,
          end: awakeStart,
        ),
        _SleepSegment(
          type: HealthDataType.SLEEP_AWAKE,
          start: awakeStart,
          end: awakeEnd,
        ),
        _SleepSegment(
          type: HealthDataType.SLEEP_ASLEEP,
          start: awakeEnd,
          end: wakeTime,
        ),
      ],
      heartRateMeasurements: heartRates,
      steps: totalSteps,
      activeEnergyKcal: activeEnergy,
      distanceMeters: distance,
      restingHeartRate: restingHr.toDouble(),
      hrvSdnn: hrvSdnn.toDouble(),
      bloodOxygenPct: spo2,
      morningAnchor: morningAnchor,
      eveningAnchor: eveningAnchor,
    );
  }
}

class _SeedDayProfile {
  final List<_SleepSegment> sleepSegments;
  final List<_PointMeasurement> heartRateMeasurements;
  final int steps;
  final double activeEnergyKcal;
  final double distanceMeters;
  final double restingHeartRate;
  final double hrvSdnn;
  final double bloodOxygenPct;
  final DateTime morningAnchor;
  final DateTime eveningAnchor;

  const _SeedDayProfile({
    required this.sleepSegments,
    required this.heartRateMeasurements,
    required this.steps,
    required this.activeEnergyKcal,
    required this.distanceMeters,
    required this.restingHeartRate,
    required this.hrvSdnn,
    required this.bloodOxygenPct,
    required this.morningAnchor,
    required this.eveningAnchor,
  });
}

class _SleepSegment {
  final HealthDataType type;
  final DateTime start;
  final DateTime end;

  const _SleepSegment({
    required this.type,
    required this.start,
    required this.end,
  });
}

class _PointMeasurement {
  final DateTime time;
  final double value;
  final HealthDataType type;

  const _PointMeasurement({
    required this.time,
    required this.value,
    required this.type,
  });
}
