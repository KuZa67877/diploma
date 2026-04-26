import 'dart:math' as math;

import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';

class PhysiologyAnomalyInferenceResult {
  final String modelId;
  final String modelVersion;
  final DateTime inferenceTimestamp;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double? anomalyScore;
  final double confidence;
  final String status;
  final String source;
  final String reason;
  final bool insufficientData;
  final PhysiologyDataQuality dataQuality;
  final List<PhysiologyReasonCode> reasonCodes;
  final List<PhysiologyGroupScore> groupScores;
  final Map<String, double?> features;

  const PhysiologyAnomalyInferenceResult({
    required this.modelId,
    required this.modelVersion,
    required this.inferenceTimestamp,
    required this.windowStart,
    required this.windowEnd,
    required this.anomalyScore,
    required this.confidence,
    required this.status,
    required this.source,
    required this.reason,
    required this.insufficientData,
    required this.dataQuality,
    required this.reasonCodes,
    required this.groupScores,
    required this.features,
  });

  factory PhysiologyAnomalyInferenceResult.insufficient({
    required DateTime now,
    String reason = 'insufficient_data',
    double? fallbackScore,
    double confidence = 0.0,
    PhysiologyDataQuality dataQuality = PhysiologyDataQuality.empty,
    List<PhysiologyReasonCode> reasonCodes = const [],
    List<PhysiologyGroupScore> groupScores = const [],
    Map<String, double?> features = const {},
  }) {
    final score = fallbackScore?.clamp(0.0, 100.0);
    return PhysiologyAnomalyInferenceResult(
      modelId: PhysiologyAnomalyInferenceModel.modelId,
      modelVersion: PhysiologyAnomalyInferenceModel.modelVersion,
      inferenceTimestamp: now,
      windowStart: now.subtract(PhysiologyAnomalyInferenceModel.dailyWindow),
      windowEnd: now,
      anomalyScore: score,
      confidence: score == null ? 0.0 : confidence.clamp(0.0, 0.35),
      status: score == null ? 'insufficient' : _statusForScore(score),
      source: score == null ? 'insufficient' : 'fallback_rule_based',
      reason: reason,
      insufficientData: true,
      dataQuality: dataQuality,
      reasonCodes: reasonCodes.isEmpty
          ? const [
              PhysiologyReasonCode(
                code: 'insufficient_data',
                message: 'Недостаточно данных для сравнения с личной нормой',
                impact: 1,
              ),
            ]
          : reasonCodes,
      groupScores: groupScores,
      features: features,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'model_version': modelVersion,
      'window_start': windowStart.toIso8601String(),
      'window_end': windowEnd.toIso8601String(),
      'anomaly_score': anomalyScore,
      'confidence': confidence,
      'status': status,
      'reason_codes': reasonCodes.map((reason) => reason.toJson()).toList(),
      'data_quality': dataQuality.toJson(),
    };
  }

  static String _statusForScore(double score) {
    if (score >= 61) return 'risk';
    if (score >= 31) return 'attention';
    return 'stable';
  }
}

class PhysiologyReasonCode {
  final String code;
  final String message;
  final double impact;

  const PhysiologyReasonCode({
    required this.code,
    required this.message,
    required this.impact,
  });

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message, 'impact': impact.clamp(0.0, 1.0)};
  }
}

class PhysiologyGroupScore {
  final String code;
  final double score;
  final double confidence;

  const PhysiologyGroupScore({
    required this.code,
    required this.score,
    required this.confidence,
  });
}

class PhysiologyDataQuality {
  final double heart;
  final double hrv;
  final double sleep;
  final double activity;
  final double temperature;
  final double respiration;
  final double oxygen;
  final double baseline;
  final double overall;
  final double missingnessRatio;

  const PhysiologyDataQuality({
    required this.heart,
    required this.hrv,
    required this.sleep,
    required this.activity,
    required this.temperature,
    required this.respiration,
    required this.oxygen,
    required this.baseline,
    required this.overall,
    required this.missingnessRatio,
  });

  static const empty = PhysiologyDataQuality(
    heart: 0,
    hrv: 0,
    sleep: 0,
    activity: 0,
    temperature: 0,
    respiration: 0,
    oxygen: 0,
    baseline: 0,
    overall: 0,
    missingnessRatio: 1,
  );

  Map<String, dynamic> toJson() {
    return {
      'heart': heart,
      'hrv': hrv,
      'sleep': sleep,
      'activity': activity,
      'temperature': temperature,
      'respiration': respiration,
      'oxygen': oxygen,
    };
  }
}

class PhysiologyAnomalyInferenceModel {
  static const String modelId = 'personal_physiology_anomaly_v1';
  static const String modelVersion = '1.0.0';
  static const Duration dailyWindow = Duration(hours: 24);
  static const Duration _baselineWindow = Duration(days: 30);
  static const Duration _longBaselineWindow = Duration(days: 60);
  static const double _minQualityForModel = 0.25;
  static const int _minIsolationForestBaselineDays = 30;
  static const int _minIsolationForestRows = 14;
  static const int _isolationForestTrees = 64;
  static const int _isolationForestSampleSize = 32;

  PhysiologyAnomalyInferenceResult inferSync({
    required List<HealthMetricSample> samples,
    DateTime? now,
  }) {
    final utcNow = (now ?? DateTime.now()).toUtc();
    final windowStart = utcNow.subtract(dailyWindow);
    final relevantSamples = samples
        .where(
          (sample) => sample.sourceId.trim().toLowerCase() != 'local_manual',
        )
        .where((sample) => _trackedTypes.contains(sample.type))
        .where((sample) => !sample.timestamp.toUtc().isAfter(utcNow))
        .toList(growable: false);

    if (relevantSamples.isEmpty) {
      return PhysiologyAnomalyInferenceResult.insufficient(
        now: utcNow,
        reason: 'no_wearable_samples',
      );
    }

    final features = _buildFeatures(
      samples: relevantSamples,
      now: utcNow,
      windowStart: windowStart,
    );
    final quality = _estimateDataQuality(features);
    final reasonCodes = _buildReasonCodes(features, quality);
    final baselineDays = (features['baseline_days_60'] ?? 0).round();

    if (baselineDays < 7 || quality.overall < _minQualityForModel) {
      final fallbackScore = _fallbackScore(features);
      return PhysiologyAnomalyInferenceResult.insufficient(
        now: utcNow,
        reason: baselineDays < 7 ? 'insufficient_baseline' : 'low_data_quality',
        fallbackScore: fallbackScore,
        confidence: math.min(quality.overall, 0.35),
        dataQuality: quality,
        reasonCodes: [
          ...reasonCodes,
          PhysiologyReasonCode(
            code: baselineDays < 7 ? 'insufficient_data' : 'low_data_quality',
            message: baselineDays < 7
                ? 'Нужно больше дней истории для персональной нормы'
                : 'Качество данных слишком низкое для надежной оценки',
            impact: baselineDays < 7 ? 1.0 : 1.0 - quality.overall,
          ),
        ],
        features: features,
      );
    }

    final groupScores = _scoreGroups(features, quality);
    final robustScore = _weightedScore(
      groupScores,
    ).clamp(0.0, 100.0).toDouble();
    final forestPrediction =
        baselineDays >= _minIsolationForestBaselineDays &&
            quality.overall >= 0.45
        ? _runIsolationForest(
            samples: relevantSamples,
            now: utcNow,
            currentFeatures: features,
          )
        : null;
    final blendedScore = forestPrediction == null
        ? robustScore
        : ((robustScore * 0.60) + (forestPrediction.score * 0.40));
    final score = blendedScore.clamp(0.0, 100.0).toDouble();
    final confidence = _confidenceFor(
      quality: quality,
      baselineDays: baselineDays,
    );
    final resolvedReasons =
        forestPrediction != null && forestPrediction.score >= 45
        ? [
            PhysiologyReasonCode(
              code: 'recovery_profile_unusual',
              message:
                  'Профиль восстановления отличается от вашей обычной нормы',
              impact: (forestPrediction.score / 100.0)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
            ...reasonCodes,
          ]
        : reasonCodes;

    return PhysiologyAnomalyInferenceResult(
      modelId: modelId,
      modelVersion: modelVersion,
      inferenceTimestamp: utcNow,
      windowStart: windowStart,
      windowEnd: utcNow,
      anomalyScore: score,
      confidence: forestPrediction == null
          ? confidence
          : math.min(1.0, confidence + (0.08 * forestPrediction.confidence)),
      status: _statusForScore(score),
      source: forestPrediction == null
          ? baselineDays < 14
                ? 'preliminary_robust_zscore'
                : 'robust_zscore_v1'
          : 'isolation_forest_v1_5',
      reason: 'ok',
      insufficientData: baselineDays < 14 || quality.overall < 0.45,
      dataQuality: quality,
      reasonCodes: resolvedReasons,
      groupScores: groupScores,
      features: {
        ...features,
        'robust_zscore_anomaly_score': robustScore,
        'isolation_forest_score': forestPrediction?.score,
        'isolation_forest_raw_score': forestPrediction?.rawScore,
        'isolation_forest_training_days': forestPrediction?.trainingRows
            .toDouble(),
        'recovery_deviation_score': _groupValue(
          groupScores,
          'recovery_deviation_score',
        ),
        'cardio_deviation_score': _groupValue(
          groupScores,
          'cardio_anomaly_score',
        ),
        'sleep_deviation_score': _groupValue(
          groupScores,
          'sleep_anomaly_score',
        ),
        'load_deviation_score': _groupValue(
          groupScores,
          'activity_load_anomaly_score',
        ),
        'temperature_respiration_deviation_score': _groupValue(
          groupScores,
          'respiration_temp_anomaly_score',
        ),
        'data_quality_score': quality.overall,
        'missingness_ratio': quality.missingnessRatio,
      },
    );
  }

  Map<String, double?> _buildFeatures({
    required List<HealthMetricSample> samples,
    required DateTime now,
    required DateTime windowStart,
  }) {
    final baselineStart = now.subtract(_baselineWindow);
    final longBaselineStart = now.subtract(_longBaselineWindow);

    final heartDay = _values(
      samples,
      HealthMetricType.heartRate,
      start: windowStart,
      end: now,
    );
    final heartBaseline = _values(
      samples,
      HealthMetricType.heartRate,
      start: baselineStart,
      end: windowStart,
    );
    final heartBaselineStats = _robustBaseline(heartBaseline);

    final restingDay = _values(
      samples,
      HealthMetricType.restingHeartRate,
      start: windowStart,
      end: now,
    );
    final restingHr =
        _mean(restingDay) ??
        _latestValue(
          samples,
          HealthMetricType.restingHeartRate,
          start: windowStart,
          end: now,
        );
    final restingBaseline = _robustBaseline(
      _values(
        samples,
        HealthMetricType.restingHeartRate,
        start: baselineStart,
        end: windowStart,
      ),
    );

    final nights = _buildSleepNights(samples, now: now);
    final latestNight = nights.isEmpty ? null : nights.last;
    final activeNight =
        latestNight != null &&
            latestNight.end.isAfter(now.subtract(const Duration(hours: 36)))
        ? latestNight
        : null;
    final previousNights = activeNight == null
        ? nights
        : nights
              .where((night) => night.dateKey != activeNight.dateKey)
              .toList(growable: false);

    final sleepHr = activeNight == null
        ? const <double>[]
        : _values(
            samples,
            HealthMetricType.heartRate,
            start: activeNight.start,
            end: activeNight.end,
          );
    final sleepHrBaseline = _robustBaseline(
      _sleepWindowMeans(samples, previousNights, HealthMetricType.heartRate),
    );

    final hrvSdnnDay = _values(
      samples,
      HealthMetricType.heartRateVariabilitySdnn,
      start: windowStart,
      end: now,
    );
    final hrvSdnnMean = _mean(hrvSdnnDay);
    final hrvSdnnMedian = hrvSdnnDay.isEmpty
        ? null
        : _median(hrvSdnnDay.toList()..sort());
    final hrvSdnnBaseline = _robustBaseline(
      _values(
        samples,
        HealthMetricType.heartRateVariabilitySdnn,
        start: baselineStart,
        end: windowStart,
      ),
    );

    final hrvRmssdDay = _values(
      samples,
      HealthMetricType.heartRateVariabilityRmssd,
      start: windowStart,
      end: now,
    );

    final respSleep = activeNight == null
        ? const <double>[]
        : _values(
            samples,
            HealthMetricType.respiratoryRate,
            start: activeNight.start,
            end: activeNight.end,
          );
    final respDay = _values(
      samples,
      HealthMetricType.respiratoryRate,
      start: windowStart,
      end: now,
    );
    final respCurrent = _mean(respSleep) ?? _mean(respDay);
    final respBaseline = _robustBaseline(
      _sleepWindowMeans(
            samples,
            previousNights,
            HealthMetricType.respiratoryRate,
          ).isNotEmpty
          ? _sleepWindowMeans(
              samples,
              previousNights,
              HealthMetricType.respiratoryRate,
            )
          : _values(
              samples,
              HealthMetricType.respiratoryRate,
              start: baselineStart,
              end: windowStart,
            ),
    );

    final spo2Day = _values(
      samples,
      HealthMetricType.bloodOxygen,
      start: windowStart,
      end: now,
    );
    final spo2Mean = _mean(spo2Day);
    final spo2Min = _min(spo2Day);

    final tempTypes = const [
      HealthMetricType.sleepWristTemperature,
      HealthMetricType.skinTemperature,
      HealthMetricType.bodyTemperature,
    ];
    final sleepWristTemp = _values(
      samples,
      HealthMetricType.sleepWristTemperature,
      start: activeNight?.start ?? windowStart,
      end: activeNight?.end ?? now,
    );
    final tempCurrent =
        _mean(sleepWristTemp) ??
        _mean(
          _valuesForTypes(samples, tempTypes, start: windowStart, end: now),
        );
    final tempBaseline = _robustBaseline(
      _valuesForTypes(
        samples,
        tempTypes,
        start: baselineStart,
        end: windowStart,
      ),
    );

    final sleepBaseline = _robustBaseline(
      previousNights.map((night) => night.sleepMinutes).toList(growable: false),
    );
    final activityBaseline = _robustBaseline(
      _dailySums(
        samples,
        HealthMetricType.steps,
        start: baselineStart,
        end: windowStart,
      ),
    );
    final stepsSum = _sum(
      samples,
      HealthMetricType.steps,
      start: windowStart,
      end: now,
    );
    final distanceSum = _sum(
      samples,
      HealthMetricType.distanceWalkingRunning,
      start: windowStart,
      end: now,
    );
    final activeEnergySum = _sum(
      samples,
      HealthMetricType.activeEnergyBurned,
      start: windowStart,
      end: now,
    );
    final exerciseTimeSum = _sum(
      samples,
      HealthMetricType.exerciseTime,
      start: windowStart,
      end: now,
    );
    final workoutCount = _count(
      samples,
      HealthMetricType.workout,
      start: windowStart,
      end: now,
    );

    final activityZ = _zScore(stepsSum, activityBaseline);
    final sleepQualityProxy = activeNight == null
        ? null
        : _sleepQualityProxy(activeNight, sleepBaseline.median);

    final highHrEvents = _count(
      samples,
      HealthMetricType.highHeartRateEvent,
      start: windowStart,
      end: now,
    );
    final lowHrEvents = _count(
      samples,
      HealthMetricType.lowHeartRateEvent,
      start: windowStart,
      end: now,
    );
    final irregularHrEvents = _count(
      samples,
      HealthMetricType.irregularHeartRateEvent,
      start: windowStart,
      end: now,
    );

    final hrvDropPercent =
        hrvSdnnMean != null &&
            hrvSdnnBaseline.median != null &&
            hrvSdnnBaseline.median! > 0
        ? ((hrvSdnnBaseline.median! - hrvSdnnMean) /
                  hrvSdnnBaseline.median! *
                  100.0)
              .clamp(0.0, 100.0)
        : null;

    return {
      'resting_hr_mean': restingHr,
      'resting_hr_delta_vs_30d_median': _delta(
        restingHr,
        restingBaseline.median,
      ),
      'resting_hr_zscore': _zScore(restingHr, restingBaseline),
      'heart_rate_day_mean': _mean(heartDay),
      'heart_rate_day_std': _std(heartDay),
      'heart_rate_day_zscore': _zScore(_mean(heartDay), heartBaselineStats),
      'heart_rate_sleep_mean': _mean(sleepHr),
      'heart_rate_sleep_delta_vs_baseline': _delta(
        _mean(sleepHr),
        sleepHrBaseline.median,
      ),
      'heart_rate_sleep_zscore': _zScore(_mean(sleepHr), sleepHrBaseline),
      'high_hr_event_count': highHrEvents.toDouble(),
      'low_hr_event_count': lowHrEvents.toDouble(),
      'irregular_hr_event_count': irregularHrEvents.toDouble(),
      'hrv_sdnn_mean': hrvSdnnMean,
      'hrv_sdnn_median': hrvSdnnMedian,
      'hrv_sdnn_delta_vs_30d_median': _delta(
        hrvSdnnMean,
        hrvSdnnBaseline.median,
      ),
      'hrv_sdnn_zscore': _zScore(hrvSdnnMean, hrvSdnnBaseline),
      'hrv_drop_percent': hrvDropPercent,
      'hrv_missing_flag': hrvSdnnMean == null && hrvRmssdDay.isEmpty ? 1 : 0,
      'hrv_rmssd_mean': _mean(hrvRmssdDay),
      'respiratory_rate_sleep_mean': _mean(respSleep),
      'respiratory_rate_delta_vs_baseline': _delta(
        respCurrent,
        respBaseline.median,
      ),
      'respiratory_rate_zscore': _zScore(respCurrent, respBaseline),
      'spo2_min': spo2Min,
      'spo2_mean': spo2Mean,
      'spo2_low_minutes': spo2Day.where((value) => value < 92).length * 5.0,
      'spo2_missing_flag': spo2Day.isEmpty ? 1 : 0,
      'sleep_wrist_temperature_mean': _mean(sleepWristTemp),
      'temperature_delta_vs_baseline': _delta(tempCurrent, tempBaseline.median),
      'temperature_zscore': _zScore(tempCurrent, tempBaseline),
      'temperature_missing_flag': tempCurrent == null ? 1 : 0,
      'sleep_total_minutes': activeNight?.sleepMinutes,
      'sleep_deep_minutes': activeNight?.deepMinutes,
      'sleep_rem_minutes': activeNight?.remMinutes,
      'sleep_awake_minutes': activeNight?.awakeMinutes,
      'sleep_efficiency': activeNight?.sleepEfficiency,
      'sleep_fragmentation_index': activeNight?.fragmentationIndex,
      'sleep_duration_delta_vs_baseline': _delta(
        activeNight?.sleepMinutes,
        sleepBaseline.median,
      ),
      'sleep_duration_zscore': _zScore(
        activeNight?.sleepMinutes,
        sleepBaseline,
      ),
      'sleep_quality_proxy': sleepQualityProxy,
      'steps_sum': stepsSum,
      'distance_sum': distanceSum,
      'active_energy_sum': activeEnergySum,
      'exercise_time_sum': exerciseTimeSum,
      'workout_minutes': exerciseTimeSum ?? (workoutCount * 30.0),
      'activity_delta_vs_baseline': _delta(stepsSum, activityBaseline.median),
      'activity_zscore': activityZ,
      'low_activity_flag': activityZ != null && activityZ <= -1.5 ? 1 : 0,
      'unusually_high_activity_flag': activityZ != null && activityZ >= 1.5
          ? 1
          : 0,
      'baseline_days_30': _uniqueDaysAny(
        samples,
        start: baselineStart,
        end: windowStart,
      ).toDouble(),
      'baseline_days_60': _uniqueDaysAny(
        samples,
        start: longBaselineStart,
        end: windowStart,
      ).toDouble(),
      'sleep_nights_30': previousNights.length.toDouble(),
      'missing_heart': heartDay.isEmpty && restingHr == null ? 1 : 0,
      'missing_hrv': hrvSdnnMean == null && hrvRmssdDay.isEmpty ? 1 : 0,
      'missing_sleep': activeNight == null ? 1 : 0,
      'missing_activity': stepsSum == null && activeEnergySum == null ? 1 : 0,
      'missing_temperature': tempCurrent == null ? 1 : 0,
      'missing_respiration': respCurrent == null ? 1 : 0,
      'missing_oxygen': spo2Day.isEmpty ? 1 : 0,
    };
  }

  PhysiologyDataQuality _estimateDataQuality(Map<String, double?> features) {
    final baselineDays = features['baseline_days_60'] ?? 0;
    final baseline = (baselineDays / 30.0).clamp(0.0, 1.0);
    final sleepNights = features['sleep_nights_30'] ?? 0;

    final heart = (features['missing_heart'] ?? 1) < 0.5 ? 1.0 : 0.0;
    final hrv = (features['missing_hrv'] ?? 1) < 0.5
        ? math.max(0.35, baseline)
        : 0.0;
    final sleep = (features['missing_sleep'] ?? 1) < 0.5
        ? math.min(1.0, math.max(0.35, sleepNights / 7.0))
        : 0.0;
    final activity = (features['missing_activity'] ?? 1) < 0.5 ? 1.0 : 0.0;
    final temperature = (features['missing_temperature'] ?? 1) < 0.5
        ? math.max(0.35, baseline)
        : 0.0;
    final respiration = (features['missing_respiration'] ?? 1) < 0.5
        ? math.max(0.35, baseline)
        : 0.0;
    final oxygen = (features['missing_oxygen'] ?? 1) < 0.5 ? 1.0 : 0.0;
    final missingnessRatio =
        [
          heart,
          hrv,
          sleep,
          activity,
          temperature,
          respiration,
          oxygen,
        ].where((value) => value <= 0).length /
        7.0;
    final overall =
        (0.22 * heart) +
        (0.18 * hrv) +
        (0.18 * sleep) +
        (0.14 * activity) +
        (0.10 * temperature) +
        (0.10 * respiration) +
        (0.08 * oxygen);

    return PhysiologyDataQuality(
      heart: heart,
      hrv: hrv.clamp(0.0, 1.0),
      sleep: sleep.clamp(0.0, 1.0),
      activity: activity,
      temperature: temperature.clamp(0.0, 1.0),
      respiration: respiration.clamp(0.0, 1.0),
      oxygen: oxygen,
      baseline: baseline.clamp(0.0, 1.0),
      overall: (overall * (0.55 + 0.45 * baseline)).clamp(0.0, 1.0),
      missingnessRatio: missingnessRatio.clamp(0.0, 1.0),
    );
  }

  _IsolationForestPrediction? _runIsolationForest({
    required List<HealthMetricSample> samples,
    required DateTime now,
    required Map<String, double?> currentFeatures,
  }) {
    final trainingRows = _buildIsolationForestTrainingRows(
      samples: samples,
      now: now,
    );
    if (trainingRows.length < _minIsolationForestRows) {
      return null;
    }

    final matrix = _buildIsolationForestMatrix(
      trainingRows: trainingRows,
      currentFeatures: currentFeatures,
    );
    if (matrix == null) {
      return null;
    }

    final forest = _IsolationForest.fit(
      matrix.trainingRows,
      treeCount: _isolationForestTrees,
      sampleSize: math.min(
        _isolationForestSampleSize,
        matrix.trainingRows.length,
      ),
      seed: _seedFor(now),
    );
    final trainingRawScores = matrix.trainingRows
        .map(forest.score)
        .where((score) => score.isFinite)
        .toList(growable: false);
    if (trainingRawScores.length < _minIsolationForestRows) {
      return null;
    }

    final rawScore = forest.score(matrix.currentRow);
    final calibratedScore = _calibrateIsolationForestScore(
      rawScore,
      trainingRawScores,
    );
    return _IsolationForestPrediction(
      score: calibratedScore,
      rawScore: rawScore,
      trainingRows: matrix.trainingRows.length,
      confidence: (matrix.trainingRows.length / 30.0)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  List<_ForestTrainingRow> _buildIsolationForestTrainingRows({
    required List<HealthMetricSample> samples,
    required DateTime now,
  }) {
    if (samples.isEmpty) return const [];

    final windowStart = now.subtract(dailyWindow);
    final start = now.subtract(_longBaselineWindow);
    var dayEnd = DateTime.utc(start.year, start.month, start.day, 23, 59, 59);
    final rows = <_ForestTrainingRow>[];

    while (!dayEnd.isAfter(windowStart)) {
      final features = _buildFeatures(
        samples: samples,
        now: dayEnd,
        windowStart: dayEnd.subtract(dailyWindow),
      );
      final baselineDays = (features['baseline_days_60'] ?? 0).round();
      if (baselineDays >= 14) {
        final quality = _estimateDataQuality(features);
        final groupScore = _weightedScore(_scoreGroups(features, quality));
        final hasCardiacEvent =
            (features['high_hr_event_count'] ?? 0) > 0 ||
            (features['low_hr_event_count'] ?? 0) > 0 ||
            (features['irregular_hr_event_count'] ?? 0) > 0;
        if (quality.overall >= 0.45 && groupScore <= 60 && !hasCardiacEvent) {
          rows.add(
            _ForestTrainingRow(
              features: features,
              quality: quality.overall,
              robustScore: groupScore,
            ),
          );
        }
      }
      dayEnd = dayEnd.add(const Duration(days: 1));
    }

    return rows;
  }

  _IsolationForestMatrix? _buildIsolationForestMatrix({
    required List<_ForestTrainingRow> trainingRows,
    required Map<String, double?> currentFeatures,
  }) {
    final nullableTrainingVectors = trainingRows
        .map((row) => _isolationForestVector(row.features))
        .toList(growable: false);
    final currentVector = _isolationForestVector(currentFeatures);
    final columnCount = _isolationForestFeatureNames.length;

    final medians = List<double>.filled(columnCount, 0);
    final scales = List<double>.filled(columnCount, 1);
    var usableColumns = 0;

    for (var column = 0; column < columnCount; column++) {
      final values =
          nullableTrainingVectors
              .map((row) => row[column])
              .whereType<double>()
              .where((value) => value.isFinite)
              .toList()
            ..sort();
      if (values.isEmpty) {
        continue;
      }
      medians[column] = _median(values);
      final q1 = _quantile(values, 0.25);
      final q3 = _quantile(values, 0.75);
      var scale = q3 - q1;
      if (scale <= 0) {
        scale = _std(values) ?? 0;
      }
      if (scale > 0) {
        scales[column] = scale;
        usableColumns += 1;
      }
    }

    if (usableColumns < 4) {
      return null;
    }

    List<double> normalize(List<double?> vector) {
      return List<double>.generate(columnCount, (column) {
        final raw = vector[column];
        final imputed = raw == null || !raw.isFinite ? medians[column] : raw;
        return ((imputed - medians[column]) / scales[column])
            .clamp(-8.0, 8.0)
            .toDouble();
      }, growable: false);
    }

    return _IsolationForestMatrix(
      trainingRows: nullableTrainingVectors
          .map(normalize)
          .toList(growable: false),
      currentRow: normalize(currentVector),
    );
  }

  List<double?> _isolationForestVector(Map<String, double?> features) {
    return _isolationForestFeatureNames
        .map((name) => features[name])
        .toList(growable: false);
  }

  double _calibrateIsolationForestScore(
    double rawScore,
    List<double> trainingRawScores,
  ) {
    final sorted = trainingRawScores.toList()..sort();
    final p50 = _quantile(sorted, 0.50);
    final p95 = _quantile(sorted, 0.95);
    final spread = math.max(0.02, p95 - p50);
    return (25.0 + (((rawScore - p50) / spread) * 45.0))
        .clamp(0.0, 100.0)
        .toDouble();
  }

  int _seedFor(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day);
    return day.millisecondsSinceEpoch ^ 0x5EED51;
  }

  List<PhysiologyGroupScore> _scoreGroups(
    Map<String, double?> features,
    PhysiologyDataQuality quality,
  ) {
    final cardio = _weightedMean([
      _Signal(_highBad(features['resting_hr_zscore']), 0.30),
      _Signal(_highBad(features['heart_rate_day_zscore']), 0.20),
      _Signal(_highBad(features['heart_rate_sleep_zscore']), 0.25),
      _Signal(
        ((features['high_hr_event_count'] ?? 0) / 2.0).clamp(0.0, 1.0),
        0.15,
      ),
      _Signal(
        (((features['low_hr_event_count'] ?? 0) +
                    (features['irregular_hr_event_count'] ?? 0)) /
                2.0)
            .clamp(0.0, 1.0),
        0.10,
      ),
    ]);

    final hrv = _weightedMean([
      _Signal(_lowBad(features['hrv_sdnn_zscore']), 0.70),
      _Signal(
        ((features['hrv_drop_percent'] ?? 0) / 45.0).clamp(0.0, 1.0),
        0.30,
      ),
    ]);

    final sleep = _weightedMean([
      _Signal(_lowBad(features['sleep_duration_zscore']), 0.35),
      _Signal(_lowAbsolute(features['sleep_efficiency'], target: 0.85), 0.25),
      _Signal(
        _highAbsolute(features['sleep_fragmentation_index'], target: 0.18),
        0.20,
      ),
      _Signal(_lowAbsolute(features['sleep_quality_proxy'], target: 70), 0.20),
    ]);

    final respTemp = _weightedMean([
      _Signal(_highBad(features['respiratory_rate_zscore']), 0.35),
      _Signal(_highBad(features['temperature_zscore']), 0.30),
      _Signal(_lowAbsolute(features['spo2_mean'], target: 95), 0.20),
      _Signal(
        ((features['spo2_low_minutes'] ?? 0) / 30.0).clamp(0.0, 1.0),
        0.15,
      ),
    ]);

    final activity = _weightedMean([
      _Signal(_twoSidedBad(features['activity_zscore']), 0.55),
      _Signal((features['low_activity_flag'] ?? 0).clamp(0.0, 1.0), 0.20),
      _Signal(
        (features['unusually_high_activity_flag'] ?? 0).clamp(0.0, 1.0),
        0.25,
      ),
    ]);

    final recovery = _weightedMean([
      _Signal(hrv, 0.35),
      _Signal(sleep, 0.30),
      _Signal(cardio, 0.20),
      _Signal(respTemp, 0.15),
    ]);

    return [
      PhysiologyGroupScore(
        code: 'cardio_anomaly_score',
        score: cardio * 100,
        confidence: quality.heart,
      ),
      PhysiologyGroupScore(
        code: 'hrv_anomaly_score',
        score: hrv * 100,
        confidence: quality.hrv,
      ),
      PhysiologyGroupScore(
        code: 'sleep_anomaly_score',
        score: sleep * 100,
        confidence: quality.sleep,
      ),
      PhysiologyGroupScore(
        code: 'respiration_temp_anomaly_score',
        score: respTemp * 100,
        confidence: math.max(
          quality.respiration,
          math.max(quality.temperature, quality.oxygen),
        ),
      ),
      PhysiologyGroupScore(
        code: 'activity_load_anomaly_score',
        score: activity * 100,
        confidence: quality.activity,
      ),
      PhysiologyGroupScore(
        code: 'recovery_deviation_score',
        score: recovery * 100,
        confidence: math.max(quality.hrv, quality.sleep),
      ),
    ];
  }

  double _weightedScore(List<PhysiologyGroupScore> groupScores) {
    const weights = {
      'cardio_anomaly_score': 0.22,
      'hrv_anomaly_score': 0.20,
      'sleep_anomaly_score': 0.18,
      'respiration_temp_anomaly_score': 0.18,
      'activity_load_anomaly_score': 0.12,
      'recovery_deviation_score': 0.10,
    };
    var numerator = 0.0;
    var denominator = 0.0;
    for (final group in groupScores) {
      final weight = weights[group.code] ?? 0.0;
      final effectiveWeight = weight * group.confidence.clamp(0.0, 1.0);
      numerator += group.score * effectiveWeight;
      denominator += effectiveWeight;
    }
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }

  double _fallbackScore(Map<String, double?> features) {
    var score = 18.0;
    final rhr = features['resting_hr_mean'];
    final hrv = features['hrv_sdnn_mean'];
    final sleep = features['sleep_total_minutes'];
    final resp = features['respiratory_rate_sleep_mean'];
    final temp = features['sleep_wrist_temperature_mean'];
    final spo2 = features['spo2_mean'];
    final steps = features['steps_sum'];

    if (_highBad(features['resting_hr_zscore']) >= 0.35 ||
        (rhr != null && rhr >= 92)) {
      score += 18;
    }
    if (_lowBad(features['hrv_sdnn_zscore']) >= 0.35 ||
        (hrv != null && hrv <= 25)) {
      score += 16;
    }
    if (_lowBad(features['sleep_duration_zscore']) >= 0.35 ||
        (sleep != null && sleep < 300)) {
      score += 14;
    }
    if (_highBad(features['respiratory_rate_zscore']) >= 0.35 ||
        (resp != null && resp >= 20)) {
      score += 12;
    }
    if (_highBad(features['temperature_zscore']) >= 0.35 ||
        (temp != null && temp >= 37.4)) {
      score += 12;
    }
    if (spo2 != null && spo2 < 94) {
      score += 10;
    }
    if (steps != null && (steps < 900 || steps > 18000)) {
      score += 8;
    }
    return score.clamp(0.0, 100.0);
  }

  List<PhysiologyReasonCode> _buildReasonCodes(
    Map<String, double?> features,
    PhysiologyDataQuality quality,
  ) {
    final reasons = <PhysiologyReasonCode>[];

    void add(String code, String message, double impact) {
      if (impact <= 0) return;
      reasons.add(
        PhysiologyReasonCode(
          code: code,
          message: message,
          impact: impact.clamp(0.0, 1.0),
        ),
      );
    }

    add(
      'resting_hr_above_baseline',
      'Пульс в покое выше вашей обычной нормы',
      _highBad(features['resting_hr_zscore']),
    );
    add(
      'hrv_below_baseline',
      'HRV ниже вашей обычной нормы',
      math.max(
        _lowBad(features['hrv_sdnn_zscore']),
        ((features['hrv_drop_percent'] ?? 0) / 45.0).clamp(0.0, 1.0),
      ),
    );
    add(
      'sleep_duration_below_baseline',
      'Сон короче вашей обычной нормы',
      _lowBad(features['sleep_duration_zscore']),
    );
    add(
      'sleep_fragmentation_high',
      'Сон выглядит более фрагментированным, чем обычно',
      _highAbsolute(features['sleep_fragmentation_index'], target: 0.18),
    );
    add(
      'respiratory_rate_above_baseline',
      'Частота дыхания выше вашей обычной нормы',
      _highBad(features['respiratory_rate_zscore']),
    );
    add(
      'temperature_above_baseline',
      'Температура выше вашей обычной нормы',
      _highBad(features['temperature_zscore']),
    );
    add(
      'spo2_below_baseline',
      'Кислород в крови ниже обычного уровня',
      _lowAbsolute(features['spo2_mean'], target: 95),
    );
    add(
      'activity_unusually_low',
      'Активность заметно ниже обычной',
      (features['low_activity_flag'] ?? 0).clamp(0.0, 1.0),
    );
    add(
      'activity_unusually_high',
      'Активность заметно выше обычной',
      (features['unusually_high_activity_flag'] ?? 0).clamp(0.0, 1.0),
    );
    add(
      'low_data_quality',
      'Часть метрик отсутствует, поэтому уверенность снижена',
      quality.overall < 0.45 ? 1.0 - quality.overall : 0,
    );

    reasons.sort((a, b) => b.impact.compareTo(a.impact));
    if (reasons.length > 8) {
      return reasons.take(8).toList(growable: false);
    }
    return reasons;
  }

  double _confidenceFor({
    required PhysiologyDataQuality quality,
    required int baselineDays,
  }) {
    final maturity = switch (baselineDays) {
      < 7 => 0.35,
      < 14 => 0.55,
      < 30 => 0.75,
      < 60 => 0.90,
      _ => 1.0,
    };
    return (quality.overall * maturity).clamp(0.0, 1.0);
  }

  static String _statusForScore(double score) {
    if (score >= 61) return 'risk';
    if (score >= 31) return 'attention';
    return 'stable';
  }

  static double _groupValue(List<PhysiologyGroupScore> groups, String code) {
    for (final group in groups) {
      if (group.code == code) return group.score;
    }
    return 0;
  }

  static double _highBad(double? z) {
    if (z == null || !z.isFinite) return 0;
    return ((z - 1.0) / 2.0).clamp(0.0, 1.0);
  }

  static double _lowBad(double? z) {
    if (z == null || !z.isFinite) return 0;
    return ((-z - 1.0) / 2.0).clamp(0.0, 1.0);
  }

  static double _twoSidedBad(double? z) {
    if (z == null || !z.isFinite) return 0;
    return ((z.abs() - 1.0) / 2.0).clamp(0.0, 1.0);
  }

  static double _lowAbsolute(double? value, {required double target}) {
    if (value == null || !value.isFinite || value >= target) return 0;
    return ((target - value) / target).clamp(0.0, 1.0);
  }

  static double _highAbsolute(double? value, {required double target}) {
    if (value == null || !value.isFinite || value <= target) return 0;
    final denominator = target == 0 ? 1.0 : target.abs();
    return ((value - target) / denominator).clamp(0.0, 1.0);
  }

  static double _weightedMean(List<_Signal> signals) {
    var numerator = 0.0;
    var denominator = 0.0;
    for (final signal in signals) {
      numerator += signal.value.clamp(0.0, 1.0) * signal.weight;
      denominator += signal.weight;
    }
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }

  static double? _zScore(double? value, _RobustBaseline baseline) {
    if (value == null || baseline.median == null) return null;
    final spread = baseline.iqr;
    if (spread == null || spread <= 0) return null;
    return ((value - baseline.median!) / spread).clamp(-5.0, 5.0);
  }

  static _RobustBaseline _robustBaseline(List<double> values) {
    final valid = values.where((value) => value.isFinite).toList()..sort();
    if (valid.isEmpty) return const _RobustBaseline();
    final q1 = _quantile(valid, 0.25);
    final q3 = _quantile(valid, 0.75);
    var iqr = q3 - q1;
    if (iqr <= 0 && valid.length >= 2) {
      final fallback = _std(valid);
      iqr = fallback == null || fallback <= 0 ? 0 : fallback;
    }
    return _RobustBaseline(median: _median(valid), iqr: iqr);
  }

  static double _sleepQualityProxy(_SleepNight night, double? baselineMinutes) {
    final targetMinutes = baselineMinutes?.clamp(360.0, 540.0) ?? 450.0;
    final durationScore = (night.sleepMinutes / targetMinutes * 100.0).clamp(
      0.0,
      100.0,
    );
    final efficiencyScore = (night.sleepEfficiency * 100.0).clamp(0.0, 100.0);
    final deepRemMinutes = night.deepMinutes + night.remMinutes;
    final stageScore = night.sleepMinutes <= 0
        ? 0.0
        : (deepRemMinutes / night.sleepMinutes / 0.42 * 100.0).clamp(
            0.0,
            100.0,
          );
    final fragmentationPenalty = (night.fragmentationIndex / 0.25 * 20.0).clamp(
      0.0,
      20.0,
    );
    return ((0.42 * durationScore) +
            (0.36 * efficiencyScore) +
            (0.22 * stageScore) -
            fragmentationPenalty)
        .clamp(0.0, 100.0);
  }

  static double? _delta(double? value, double? baseline) {
    if (value == null || baseline == null) return null;
    return value - baseline;
  }

  static List<double> _sleepWindowMeans(
    List<HealthMetricSample> samples,
    List<_SleepNight> nights,
    HealthMetricType type,
  ) {
    final means = <double>[];
    for (final night in nights) {
      final values = _values(samples, type, start: night.start, end: night.end);
      final mean = _mean(values);
      if (mean != null) means.add(mean);
    }
    return means;
  }

  static List<double> _dailySums(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    final totals = <String, double>{};
    for (final sample in samples) {
      if (sample.type != type) continue;
      final ts = sample.timestamp.toUtc();
      if (!_inRange(ts, start, end)) continue;
      final key = _dateKey(ts);
      totals[key] = (totals[key] ?? 0) + sample.value;
    }
    return totals.values.where((value) => value.isFinite).toList();
  }

  static List<_SleepNight> _buildSleepNights(
    List<HealthMetricSample> samples, {
    required DateTime now,
  }) {
    final start = now.subtract(_longBaselineWindow);
    final byDate = <String, _SleepNightAccumulator>{};

    for (final sample in samples) {
      if (!_sleepTypes.contains(sample.type) || sample.value <= 0) continue;
      final end = sample.timestamp.toUtc();
      if (!_inRange(end, start, now)) continue;
      final date = end.hour < 18 ? end : end.add(const Duration(days: 1));
      final dateKey = _dateKey(date);
      final accumulator = byDate.putIfAbsent(
        dateKey,
        () => _SleepNightAccumulator(dateKey),
      );
      accumulator.add(sample.type, sample.value, end);
    }

    final nights =
        byDate.values
            .map((accumulator) => accumulator.build())
            .where((night) => night.sleepMinutes >= 60)
            .toList(growable: false)
          ..sort((a, b) => a.end.compareTo(b.end));
    return nights;
  }

  static List<double> _values(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    return samples
        .where((sample) => sample.type == type)
        .where((sample) => _inRange(sample.timestamp.toUtc(), start, end))
        .map((sample) => sample.value)
        .where((value) => value.isFinite)
        .toList(growable: false);
  }

  static List<double> _valuesForTypes(
    List<HealthMetricSample> samples,
    List<HealthMetricType> types, {
    required DateTime start,
    required DateTime end,
  }) {
    final typeSet = types.toSet();
    return samples
        .where((sample) => typeSet.contains(sample.type))
        .where((sample) => _inRange(sample.timestamp.toUtc(), start, end))
        .map((sample) => sample.value)
        .where((value) => value.isFinite)
        .toList(growable: false);
  }

  static double? _latestValue(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    HealthMetricSample? latest;
    for (final sample in samples) {
      if (sample.type != type) continue;
      final ts = sample.timestamp.toUtc();
      if (!_inRange(ts, start, end)) continue;
      if (latest == null || ts.isAfter(latest.timestamp.toUtc())) {
        latest = sample;
      }
    }
    return latest?.value;
  }

  static double? _sum(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    final values = _values(samples, type, start: start, end: end);
    if (values.isEmpty) return null;
    return values.fold<double>(0, (total, value) => total + value);
  }

  static int _count(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    return samples
        .where((sample) => sample.type == type)
        .where((sample) => _inRange(sample.timestamp.toUtc(), start, end))
        .length;
  }

  static int _uniqueDaysAny(
    List<HealthMetricSample> samples, {
    required DateTime start,
    required DateTime end,
  }) {
    return samples
        .where((sample) => _trackedTypes.contains(sample.type))
        .where((sample) => _inRange(sample.timestamp.toUtc(), start, end))
        .map((sample) => _dateKey(sample.timestamp.toUtc()))
        .toSet()
        .length;
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  static double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? _std(List<double> values) {
    if (values.length < 2) return null;
    final mean = _mean(values)!;
    final variance =
        values
            .map((value) => math.pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static double _median(List<double> sortedValues) {
    final n = sortedValues.length;
    final mid = n ~/ 2;
    if (n.isOdd) return sortedValues[mid];
    return (sortedValues[mid - 1] + sortedValues[mid]) / 2.0;
  }

  static double _quantile(List<double> sortedValues, double q) {
    if (sortedValues.isEmpty) return 0;
    if (sortedValues.length == 1) return sortedValues.first;
    final pos = (sortedValues.length - 1) * q;
    final lower = pos.floor();
    final upper = pos.ceil();
    if (lower == upper) return sortedValues[lower];
    final fraction = pos - lower;
    return sortedValues[lower] +
        ((sortedValues[upper] - sortedValues[lower]) * fraction);
  }

  static double? _min(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.min);
  }

  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static const Set<HealthMetricType> _trackedTypes = {
    HealthMetricType.heartRate,
    HealthMetricType.restingHeartRate,
    HealthMetricType.walkingHeartRate,
    HealthMetricType.heartRateVariabilitySdnn,
    HealthMetricType.heartRateVariabilityRmssd,
    HealthMetricType.highHeartRateEvent,
    HealthMetricType.lowHeartRateEvent,
    HealthMetricType.irregularHeartRateEvent,
    HealthMetricType.atrialFibrillationBurden,
    HealthMetricType.respiratoryRate,
    HealthMetricType.bloodOxygen,
    HealthMetricType.bodyTemperature,
    HealthMetricType.skinTemperature,
    HealthMetricType.sleepWristTemperature,
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepAwake,
    HealthMetricType.sleepAwakeInBed,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepRem,
    HealthMetricType.sleepInBed,
    HealthMetricType.sleepSession,
    HealthMetricType.steps,
    HealthMetricType.distanceWalkingRunning,
    HealthMetricType.activeEnergyBurned,
    HealthMetricType.basalEnergyBurned,
    HealthMetricType.exerciseTime,
    HealthMetricType.workout,
  };

  static const Set<HealthMetricType> _sleepTypes = {
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepAwake,
    HealthMetricType.sleepAwakeInBed,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepRem,
    HealthMetricType.sleepInBed,
    HealthMetricType.sleepSession,
  };

  static const List<String> _isolationForestFeatureNames = [
    'resting_hr_zscore',
    'heart_rate_day_zscore',
    'heart_rate_sleep_zscore',
    'high_hr_event_count',
    'low_hr_event_count',
    'irregular_hr_event_count',
    'hrv_sdnn_zscore',
    'hrv_drop_percent',
    'respiratory_rate_zscore',
    'temperature_zscore',
    'spo2_mean',
    'spo2_low_minutes',
    'sleep_duration_zscore',
    'sleep_efficiency',
    'sleep_fragmentation_index',
    'sleep_quality_proxy',
    'activity_zscore',
    'low_activity_flag',
    'unusually_high_activity_flag',
    'missing_heart',
    'missing_hrv',
    'missing_sleep',
    'missing_activity',
    'missing_temperature',
    'missing_respiration',
    'missing_oxygen',
  ];
}

class _IsolationForestPrediction {
  final double score;
  final double rawScore;
  final int trainingRows;
  final double confidence;

  const _IsolationForestPrediction({
    required this.score,
    required this.rawScore,
    required this.trainingRows,
    required this.confidence,
  });
}

class _ForestTrainingRow {
  final Map<String, double?> features;
  final double quality;
  final double robustScore;

  const _ForestTrainingRow({
    required this.features,
    required this.quality,
    required this.robustScore,
  });
}

class _IsolationForestMatrix {
  final List<List<double>> trainingRows;
  final List<double> currentRow;

  const _IsolationForestMatrix({
    required this.trainingRows,
    required this.currentRow,
  });
}

class _IsolationForest {
  final List<_IsolationTreeNode> trees;
  final int sampleSize;

  const _IsolationForest({required this.trees, required this.sampleSize});

  factory _IsolationForest.fit(
    List<List<double>> rows, {
    required int treeCount,
    required int sampleSize,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final maxDepth = math.max(1, (math.log(sampleSize) / math.ln2).ceil());
    final trees = <_IsolationTreeNode>[];
    for (var i = 0; i < treeCount; i++) {
      final indices = List<int>.generate(rows.length, (index) => index)
        ..shuffle(rng);
      final sampleIndices = indices.take(sampleSize).toList(growable: false);
      trees.add(
        _IsolationTreeNode.fit(
          rows: rows,
          indices: sampleIndices,
          depth: 0,
          maxDepth: maxDepth,
          rng: rng,
        ),
      );
    }
    return _IsolationForest(trees: trees, sampleSize: sampleSize);
  }

  double score(List<double> row) {
    if (trees.isEmpty) return 0;
    final averagePath =
        trees
            .map((tree) => tree.pathLength(row))
            .reduce((left, right) => left + right) /
        trees.length;
    final denominator = _c(sampleSize);
    if (denominator <= 0) return 0;
    return math.pow(2, -averagePath / denominator).toDouble();
  }
}

class _IsolationTreeNode {
  final int? featureIndex;
  final double? splitValue;
  final _IsolationTreeNode? left;
  final _IsolationTreeNode? right;
  final int size;

  const _IsolationTreeNode.external({required this.size})
    : featureIndex = null,
      splitValue = null,
      left = null,
      right = null;

  const _IsolationTreeNode.internal({
    required this.featureIndex,
    required this.splitValue,
    required this.left,
    required this.right,
    required this.size,
  });

  factory _IsolationTreeNode.fit({
    required List<List<double>> rows,
    required List<int> indices,
    required int depth,
    required int maxDepth,
    required math.Random rng,
  }) {
    if (indices.length <= 1 || depth >= maxDepth) {
      return _IsolationTreeNode.external(size: indices.length);
    }

    final columnCount = rows.first.length;
    final candidates = <_SplitCandidate>[];
    for (var feature = 0; feature < columnCount; feature++) {
      var minValue = double.infinity;
      var maxValue = double.negativeInfinity;
      for (final index in indices) {
        final value = rows[index][feature];
        if (value < minValue) minValue = value;
        if (value > maxValue) maxValue = value;
      }
      if (minValue.isFinite && maxValue.isFinite && maxValue > minValue) {
        candidates.add(_SplitCandidate(feature, minValue, maxValue));
      }
    }

    if (candidates.isEmpty) {
      return _IsolationTreeNode.external(size: indices.length);
    }

    final candidate = candidates[rng.nextInt(candidates.length)];
    final split =
        candidate.minValue +
        (rng.nextDouble() * (candidate.maxValue - candidate.minValue));
    final leftIndices = <int>[];
    final rightIndices = <int>[];
    for (final index in indices) {
      if (rows[index][candidate.featureIndex] < split) {
        leftIndices.add(index);
      } else {
        rightIndices.add(index);
      }
    }

    if (leftIndices.isEmpty || rightIndices.isEmpty) {
      return _IsolationTreeNode.external(size: indices.length);
    }

    return _IsolationTreeNode.internal(
      featureIndex: candidate.featureIndex,
      splitValue: split,
      size: indices.length,
      left: _IsolationTreeNode.fit(
        rows: rows,
        indices: leftIndices,
        depth: depth + 1,
        maxDepth: maxDepth,
        rng: rng,
      ),
      right: _IsolationTreeNode.fit(
        rows: rows,
        indices: rightIndices,
        depth: depth + 1,
        maxDepth: maxDepth,
        rng: rng,
      ),
    );
  }

  double pathLength(List<double> row, [int depth = 0]) {
    final feature = featureIndex;
    final split = splitValue;
    if (feature == null || split == null || left == null || right == null) {
      return depth + _c(size);
    }
    if (row[feature] < split) {
      return left!.pathLength(row, depth + 1);
    }
    return right!.pathLength(row, depth + 1);
  }
}

class _SplitCandidate {
  final int featureIndex;
  final double minValue;
  final double maxValue;

  const _SplitCandidate(this.featureIndex, this.minValue, this.maxValue);
}

double _c(int size) {
  if (size <= 1) return 0;
  if (size == 2) return 1;
  return (2.0 * (math.log(size - 1) + 0.5772156649)) -
      (2.0 * (size - 1) / size);
}

class _RobustBaseline {
  final double? median;
  final double? iqr;

  const _RobustBaseline({this.median, this.iqr});
}

class _Signal {
  final double value;
  final double weight;

  const _Signal(this.value, this.weight);
}

class _SleepNight {
  final String dateKey;
  final DateTime start;
  final DateTime end;
  final double sleepMinutes;
  final double deepMinutes;
  final double remMinutes;
  final double awakeMinutes;
  final double inBedMinutes;

  const _SleepNight({
    required this.dateKey,
    required this.start,
    required this.end,
    required this.sleepMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    required this.inBedMinutes,
  });

  double get sleepEfficiency {
    if (inBedMinutes <= 0) return 0;
    return (sleepMinutes / inBedMinutes).clamp(0.0, 1.0);
  }

  double get fragmentationIndex {
    final denominator = sleepMinutes + awakeMinutes;
    if (denominator <= 0) return 0;
    return (awakeMinutes / denominator).clamp(0.0, 1.0);
  }
}

class _SleepNightAccumulator {
  final String dateKey;
  DateTime? latestEnd;
  double genericAsleep = 0;
  double stagedAsleep = 0;
  double deep = 0;
  double light = 0;
  double rem = 0;
  double awake = 0;
  double inBed = 0;
  double session = 0;

  _SleepNightAccumulator(this.dateKey);

  void add(HealthMetricType type, double minutes, DateTime end) {
    if (latestEnd == null || end.isAfter(latestEnd!)) {
      latestEnd = end;
    }

    switch (type) {
      case HealthMetricType.sleepDeep:
        deep += minutes;
        stagedAsleep += minutes;
        break;
      case HealthMetricType.sleepLight:
        light += minutes;
        stagedAsleep += minutes;
        break;
      case HealthMetricType.sleepRem:
        rem += minutes;
        stagedAsleep += minutes;
        break;
      case HealthMetricType.sleepAsleep:
        genericAsleep += minutes;
        break;
      case HealthMetricType.sleepAwake:
      case HealthMetricType.sleepAwakeInBed:
        awake += minutes;
        break;
      case HealthMetricType.sleepInBed:
        inBed += minutes;
        break;
      case HealthMetricType.sleepSession:
        session += minutes;
        break;
      default:
        break;
    }
  }

  _SleepNight build() {
    final asleep = stagedAsleep > 0 ? stagedAsleep : genericAsleep;
    final resolvedInBed = inBed > 0
        ? inBed
        : session > 0
        ? session
        : asleep + awake;
    final end =
        latestEnd ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final start = end.subtract(
      Duration(minutes: math.max(resolvedInBed, asleep).round()),
    );
    return _SleepNight(
      dateKey: dateKey,
      start: start,
      end: end,
      sleepMinutes: asleep,
      deepMinutes: deep,
      remMinutes: rem,
      awakeMinutes: awake,
      inBedMinutes: math.max(resolvedInBed, asleep),
    );
  }
}
