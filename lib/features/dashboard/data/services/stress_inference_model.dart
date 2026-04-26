import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';

class StressInferenceResult {
  final double? stressScore;
  final double confidence;
  final bool insufficientData;
  final String status;
  final String source;
  final String modelVersion;
  final DateTime inferenceTimestamp;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String reason;
  final StressQualityBreakdown quality;
  final List<StressReasonCode> reasonCodes;
  final List<StressModelContribution> modelContributions;
  final List<String> missingModalities;
  final Map<String, double?> features;

  const StressInferenceResult({
    required this.stressScore,
    required this.confidence,
    required this.insufficientData,
    required this.status,
    required this.source,
    required this.modelVersion,
    required this.inferenceTimestamp,
    required this.windowStart,
    required this.windowEnd,
    required this.reason,
    required this.quality,
    required this.reasonCodes,
    this.modelContributions = const [],
    required this.missingModalities,
    required this.features,
  });

  factory StressInferenceResult.insufficient({
    required DateTime now,
    String reason = 'insufficient_data',
    double? fallbackStressScore,
    double fallbackConfidence = 0.25,
    StressQualityBreakdown quality = StressQualityBreakdown.empty,
    List<StressReasonCode> reasonCodes = const [],
    List<String> missingModalities = const [],
    Map<String, double?> features = const {},
  }) {
    final score = fallbackStressScore?.clamp(0.0, 100.0);
    return StressInferenceResult(
      stressScore: score,
      confidence: score == null ? 0 : fallbackConfidence.clamp(0.0, 1.0),
      insufficientData: true,
      status: score == null ? 'insufficient' : _statusForScore(score),
      source: score == null ? 'insufficient' : 'fallback_rule_based',
      modelVersion: StressInferenceModel.modelVersion,
      inferenceTimestamp: now,
      windowStart: now.subtract(StressInferenceModel.currentWindow),
      windowEnd: now,
      reason: reason,
      quality: quality,
      reasonCodes: reasonCodes,
      missingModalities: missingModalities,
      features: features,
    );
  }

  static String _statusForScore(double score) {
    if (score >= 70) return 'risk';
    if (score >= 40) return 'attention';
    return 'stable';
  }
}

class StressReasonCode {
  final String code;
  final String severity;
  final double contribution;
  final String message;

  const StressReasonCode({
    required this.code,
    required this.severity,
    required this.contribution,
    required this.message,
  });
}

class StressModelContribution {
  final String featureName;
  final double? rawValue;
  final double imputedValue;
  final bool isImputed;
  final double normalizedValue;
  final double coefficient;
  final double contribution;

  const StressModelContribution({
    required this.featureName,
    required this.rawValue,
    required this.imputedValue,
    required this.isImputed,
    required this.normalizedValue,
    required this.coefficient,
    required this.contribution,
  });
}

class StressQualityBreakdown {
  final double overall;
  final double heartRate;
  final double baseline;
  final double sleep;
  final double activityContext;
  final double hrv;
  final double respiratoryTemperatureOxygen;

  const StressQualityBreakdown({
    required this.overall,
    required this.heartRate,
    required this.baseline,
    required this.sleep,
    required this.activityContext,
    required this.hrv,
    required this.respiratoryTemperatureOxygen,
  });

  static const empty = StressQualityBreakdown(
    overall: 0,
    heartRate: 0,
    baseline: 0,
    sleep: 0,
    activityContext: 0,
    hrv: 0,
    respiratoryTemperatureOxygen: 0,
  );
}

class StressScorecardArtifact {
  final String modelVersion;
  final List<String> featureNames;
  final List<double> imputerStatistics;
  final List<double> center;
  final List<double> scale;
  final double intercept;
  final List<double> coefficients;
  final double calibrationCoefficient;
  final double calibrationIntercept;

  const StressScorecardArtifact({
    required this.modelVersion,
    required this.featureNames,
    required this.imputerStatistics,
    required this.center,
    required this.scale,
    required this.intercept,
    required this.coefficients,
    required this.calibrationCoefficient,
    required this.calibrationIntercept,
  });

  factory StressScorecardArtifact.fromJson(Map<String, dynamic> json) {
    final preprocessing = json['preprocessing'] as Map<String, dynamic>;
    final model = json['model'] as Map<String, dynamic>;
    final calibration = json['calibration'] as Map<String, dynamic>;

    return StressScorecardArtifact(
      modelVersion:
          json['model_version']?.toString() ??
          StressInferenceModel.modelVersion,
      featureNames: _stringList(json['feature_names']),
      imputerStatistics: _doubleList(preprocessing['imputer_statistics']),
      center: _doubleList(preprocessing['center']),
      scale: _doubleList(preprocessing['scale']),
      intercept: _toDouble(model['intercept']),
      coefficients: _doubleList(model['coefficients']),
      calibrationCoefficient: _toDouble(
        calibration['coefficient'],
        fallback: 1,
      ),
      calibrationIntercept: _toDouble(calibration['intercept']),
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>).map((item) => item.toString()).toList();
  }

  static List<double> _doubleList(dynamic value) {
    return (value as List<dynamic>)
        .map((item) => _toDouble(item))
        .toList(growable: false);
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }
}

class StressInferenceModel {
  static const String modelVersion = 'stress-scorecard-v1';
  static const String _scorecardAssetPath =
      'assets/models/stress/scorecard_v1.json';
  static const Duration _shortWindow = Duration(minutes: 5);
  static const Duration currentWindow = Duration(minutes: 15);
  static const Duration _contextWindow = Duration(hours: 1);
  static const Duration _dayWindow = Duration(days: 1);
  static const Duration _baselineWindow = Duration(days: 30);
  static const double _minModelQuality = 0.45;
  static const int _minBaselineDays = 3;
  static const int _workoutCooldownMinutes = 45;

  Future<StressScorecardArtifact?>? _scorecardFuture;
  StressScorecardArtifact? _loadedScorecard;

  Future<StressInferenceResult> infer({
    required List<HealthMetricSample> samples,
    DateTime? now,
    double? recentSleepScore,
    int? fallbackHealthScore,
  }) async {
    final scorecard = await _loadScorecard();
    return _inferInternal(
      samples: samples,
      now: now,
      recentSleepScore: recentSleepScore,
      fallbackHealthScore: fallbackHealthScore,
      scorecard: scorecard,
    );
  }

  StressInferenceResult inferSync({
    required List<HealthMetricSample> samples,
    DateTime? now,
    double? recentSleepScore,
    int? fallbackHealthScore,
  }) {
    return _inferInternal(
      samples: samples,
      now: now,
      recentSleepScore: recentSleepScore,
      fallbackHealthScore: fallbackHealthScore,
      scorecard: _loadedScorecard,
    );
  }

  Future<StressScorecardArtifact?> _loadScorecard() {
    return _scorecardFuture ??= _loadScorecardOnce();
  }

  Future<StressScorecardArtifact?> _loadScorecardOnce() async {
    try {
      final payload = await rootBundle.loadString(_scorecardAssetPath);
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      final scorecard = StressScorecardArtifact.fromJson(jsonMap);
      _validateScorecard(scorecard);
      _loadedScorecard = scorecard;
      return scorecard;
    } catch (_) {
      return null;
    }
  }

  void _validateScorecard(StressScorecardArtifact scorecard) {
    final n = scorecard.featureNames.length;
    if (scorecard.imputerStatistics.length != n ||
        scorecard.center.length != n ||
        scorecard.scale.length != n ||
        scorecard.coefficients.length != n) {
      throw const FormatException('Invalid stress scorecard vector lengths');
    }
  }

  StressInferenceResult _inferInternal({
    required List<HealthMetricSample> samples,
    required DateTime? now,
    required double? recentSleepScore,
    required int? fallbackHealthScore,
    required StressScorecardArtifact? scorecard,
  }) {
    final utcNow = (now ?? DateTime.now()).toUtc();
    final windowStart = utcNow.subtract(currentWindow);
    final shortWindowStart = utcNow.subtract(_shortWindow);
    final contextStart = utcNow.subtract(_contextWindow);
    final dayStart = utcNow.subtract(_dayWindow);
    final baselineStart = utcNow.subtract(_baselineWindow);
    final relevantSamples = samples
        .where(
          (sample) => sample.sourceId.trim().toLowerCase() != 'local_manual',
        )
        .where((sample) => _trackedTypes.contains(sample.type))
        .where((sample) => !sample.timestamp.toUtc().isAfter(utcNow))
        .toList(growable: false);

    if (relevantSamples.isEmpty) {
      return StressInferenceResult.insufficient(
        now: utcNow,
        reason: 'no_wearable_samples',
        fallbackStressScore: _stressFromFallbackHealthScore(
          fallbackHealthScore,
        ),
        missingModalities: const ['heart_rate'],
      );
    }

    final features = _buildFeatures(
      samples: relevantSamples,
      shortWindowStart: shortWindowStart,
      windowStart: windowStart,
      contextStart: contextStart,
      dayStart: dayStart,
      baselineStart: baselineStart,
      now: utcNow,
      recentSleepScore: recentSleepScore,
    );
    final quality = _estimateQuality(
      samples: relevantSamples,
      features: features,
      windowStart: windowStart,
      contextStart: contextStart,
      dayStart: dayStart,
      baselineStart: baselineStart,
      now: utcNow,
    );
    final missing = _missingModalities(features);
    final reasons = _buildReasonCodes(features: features, quality: quality);
    final fallbackStressScore =
        _stressFromFallbackHealthScore(fallbackHealthScore) ??
        _ruleBasedFallbackScore(features);

    final baselineDays = (features['hr_baseline_days_14'] ?? 0).round();
    final hasHeartRate = (features['missing_hr'] ?? 1) < 0.5;
    final recentWorkout =
        (features['minutes_since_workout'] ?? 9999) < _workoutCooldownMinutes;
    final highRecentActivity = _activityConfounder(features) >= 0.65;
    final hasCardiacEvent = (features['cardiac_event_present'] ?? 0) > 0.5;

    if (!hasHeartRate) {
      return StressInferenceResult.insufficient(
        now: utcNow,
        reason: 'missing_heart_rate',
        fallbackStressScore: fallbackStressScore,
        fallbackConfidence: 0.20,
        quality: quality,
        reasonCodes: [
          ...reasons,
          const StressReasonCode(
            code: 'low_data_quality',
            severity: 'high',
            contribution: 1,
            message: 'Heart rate is required for stress load estimation.',
          ),
        ],
        missingModalities: missing,
        features: features,
      );
    }

    if (hasCardiacEvent) {
      return StressInferenceResult.insufficient(
        now: utcNow,
        reason: 'cardiac_event_context',
        fallbackStressScore: fallbackStressScore,
        fallbackConfidence: 0.20,
        quality: quality,
        reasonCodes: [
          ...reasons,
          const StressReasonCode(
            code: 'cardiac_event_context',
            severity: 'high',
            contribution: 1,
            message:
                'Recent cardiac event data is present, so stress inference is not used.',
          ),
        ],
        missingModalities: missing,
        features: features,
      );
    }

    if (recentWorkout || highRecentActivity) {
      return StressInferenceResult.insufficient(
        now: utcNow,
        reason: recentWorkout
            ? 'recent_workout_context'
            : 'recent_activity_context',
        fallbackStressScore: fallbackStressScore,
        fallbackConfidence: 0.25,
        quality: quality,
        reasonCodes: [
          ...reasons,
          const StressReasonCode(
            code: 'recent_activity_context',
            severity: 'medium',
            contribution: 1,
            message:
                'Recent activity can elevate heart rate and obscure stress estimation.',
          ),
        ],
        missingModalities: missing,
        features: features,
      );
    }

    if (baselineDays < _minBaselineDays || quality.overall < _minModelQuality) {
      return StressInferenceResult.insufficient(
        now: utcNow,
        reason: baselineDays < _minBaselineDays
            ? 'insufficient_baseline'
            : 'low_data_quality',
        fallbackStressScore: fallbackStressScore,
        fallbackConfidence: math.min(quality.overall, 0.35),
        quality: quality,
        reasonCodes: [
          ...reasons,
          StressReasonCode(
            code: baselineDays < _minBaselineDays
                ? 'insufficient_baseline'
                : 'low_data_quality',
            severity: 'medium',
            contribution: 1,
            message:
                'More personal history is needed for reliable stress estimation.',
          ),
        ],
        missingModalities: missing,
        features: features,
      );
    }

    final trainedPrediction = scorecard == null
        ? null
        : _scoreWithTrainedScorecard(features, scorecard);
    final stressScore =
        trainedPrediction?.score ?? _scoreWithDefaultScorecard(features);
    final confidence = _confidenceFromQuality(
      quality: quality,
      missingModalities: missing,
    );

    return StressInferenceResult(
      stressScore: stressScore,
      confidence: confidence,
      insufficientData: false,
      status: _statusForScore(stressScore),
      source: scorecard == null
          ? 'scorecard_logistic_default'
          : 'scorecard_logistic_trained',
      modelVersion: scorecard?.modelVersion ?? modelVersion,
      inferenceTimestamp: utcNow,
      windowStart: windowStart,
      windowEnd: utcNow,
      reason: 'ok',
      quality: quality,
      reasonCodes: reasons,
      modelContributions: trainedPrediction?.contributions ?? const [],
      missingModalities: missing,
      features: features,
    );
  }

  Map<String, double?> _buildFeatures({
    required List<HealthMetricSample> samples,
    required DateTime shortWindowStart,
    required DateTime windowStart,
    required DateTime contextStart,
    required DateTime dayStart,
    required DateTime baselineStart,
    required DateTime now,
    required double? recentSleepScore,
  }) {
    final shortHr = _values(
      samples,
      HealthMetricType.heartRate,
      start: shortWindowStart,
      end: now,
    );
    final currentHr = _values(
      samples,
      HealthMetricType.heartRate,
      start: windowStart,
      end: now,
    );
    final contextHr = _values(
      samples,
      HealthMetricType.heartRate,
      start: contextStart,
      end: now,
    );
    final baselineHr14 = _values(
      samples,
      HealthMetricType.heartRate,
      start: now.subtract(const Duration(days: 14)),
      end: windowStart,
    );
    final baselineRhr30 = _values(
      samples,
      HealthMetricType.restingHeartRate,
      start: baselineStart,
      end: windowStart,
    );
    final rhrDay = _latestValue(
      samples,
      HealthMetricType.restingHeartRate,
      start: dayStart,
      end: now,
    );
    final walkingHrDay = _latestValue(
      samples,
      HealthMetricType.walkingHeartRate,
      start: dayStart,
      end: now,
    );
    final hrvSdnnDay = _latestValue(
      samples,
      HealthMetricType.heartRateVariabilitySdnn,
      start: dayStart,
      end: now,
    );
    final hrvRmssdDay = _latestValue(
      samples,
      HealthMetricType.heartRateVariabilityRmssd,
      start: dayStart,
      end: now,
    );
    final baselineSdnn30 = _values(
      samples,
      HealthMetricType.heartRateVariabilitySdnn,
      start: baselineStart,
      end: windowStart,
    );
    final baselineRmssd30 = _values(
      samples,
      HealthMetricType.heartRateVariabilityRmssd,
      start: baselineStart,
      end: windowStart,
    );
    final respContext = _values(
      samples,
      HealthMetricType.respiratoryRate,
      start: contextStart,
      end: now,
    );
    final baselineResp14 = _values(
      samples,
      HealthMetricType.respiratoryRate,
      start: now.subtract(const Duration(days: 14)),
      end: windowStart,
    );
    final tempDay = _latestAnyValue(
      samples,
      const [
        HealthMetricType.skinTemperature,
        HealthMetricType.sleepWristTemperature,
        HealthMetricType.bodyTemperature,
      ],
      start: dayStart,
      end: now,
    );
    final baselineTemp30 = _valuesForTypes(
      samples,
      const [
        HealthMetricType.skinTemperature,
        HealthMetricType.sleepWristTemperature,
        HealthMetricType.bodyTemperature,
      ],
      start: baselineStart,
      end: windowStart,
    );
    final spo2Day = _values(
      samples,
      HealthMetricType.bloodOxygen,
      start: dayStart,
      end: now,
    );
    final steps15 = _sum(
      samples,
      HealthMetricType.steps,
      start: windowStart,
      end: now,
    );
    final steps1h = _sum(
      samples,
      HealthMetricType.steps,
      start: contextStart,
      end: now,
    );
    final steps24h = _sum(
      samples,
      HealthMetricType.steps,
      start: dayStart,
      end: now,
    );
    final energy1h = _sum(
      samples,
      HealthMetricType.activeEnergyBurned,
      start: contextStart,
      end: now,
    );
    final exercise45m = _sum(
      samples,
      HealthMetricType.exerciseTime,
      start: now.subtract(const Duration(minutes: _workoutCooldownMinutes)),
      end: now,
    );
    final minutesSinceWorkout = _minutesSinceLatestWorkout(samples, now: now);
    final nights = _buildSleepNights(samples, now: now);
    final latestNight = nights.isEmpty ? null : nights.last;
    final previousNights = latestNight == null
        ? const <_SleepNight>[]
        : nights
              .where((night) => night.dateKey != latestNight.dateKey)
              .toList(growable: false);
    final sleepBaseline = _robustBaseline(
      previousNights.map((night) => night.sleepHours).toList(growable: false),
    );
    final sleepEfficiencyBaseline = _robustBaseline(
      previousNights
          .map((night) => night.sleepEfficiencyPct)
          .toList(growable: false),
    );

    final hrMean = _mean(currentHr) ?? _mean(contextHr);
    final hr5mMean = _mean(shortHr);
    final hrBaseline14 = _robustBaseline(baselineHr14);
    final rhrBaseline30 = _robustBaseline(baselineRhr30);
    final sdnnBaseline30 = _robustBaseline(baselineSdnn30);
    final rmssdBaseline30 = _robustBaseline(baselineRmssd30);
    final respBaseline14 = _robustBaseline(baselineResp14);
    final tempBaseline30 = _robustBaseline(baselineTemp30);
    final sleepHours = latestNight?.sleepHours;
    final sleepEfficiency = latestNight?.sleepEfficiencyPct;

    return {
      'hr_mean': hrMean,
      'hr_mean_5m': hr5mMean,
      'hr_std_5m': _std(shortHr),
      'hr_min_5m': _min(shortHr),
      'hr_max_5m': _max(shortHr),
      'hr_slope_5m': _slope(shortHr),
      'hr_z_5m_14': _zScore(hr5mMean, hrBaseline14),
      'hr_std': _std(currentHr.isEmpty ? contextHr : currentHr),
      'hr_min': _min(currentHr.isEmpty ? contextHr : currentHr),
      'hr_max': _max(currentHr.isEmpty ? contextHr : currentHr),
      'hr_slope': _slope(currentHr.isEmpty ? contextHr : currentHr),
      'hr_z_14': _zScore(hrMean, hrBaseline14),
      'hr_baseline_days_14': _uniqueDays(
        samples,
        HealthMetricType.heartRate,
        start: now.subtract(const Duration(days: 14)),
        end: windowStart,
      ).toDouble(),
      'resting_hr_latest': rhrDay,
      'resting_hr_z_30': _zScore(rhrDay, rhrBaseline30),
      'walking_hr_latest': walkingHrDay,
      'hr_over_rhr': hrMean != null && rhrDay != null && rhrDay > 0
          ? hrMean / rhrDay
          : null,
      'hrv_sdnn_latest': hrvSdnnDay,
      'hrv_sdnn_z_30': _zScore(hrvSdnnDay, sdnnBaseline30),
      'hrv_rmssd_latest': hrvRmssdDay,
      'hrv_rmssd_z_30': _zScore(hrvRmssdDay, rmssdBaseline30),
      'resp_rate_mean_1h': _mean(respContext),
      'resp_rate_z_14': _zScore(_mean(respContext), respBaseline14),
      'temperature_latest': tempDay,
      'temperature_z_30': _zScore(tempDay, tempBaseline30),
      'spo2_min_24h': _min(spo2Day),
      'steps_15m': steps15,
      'steps_5m': _sum(
        samples,
        HealthMetricType.steps,
        start: shortWindowStart,
        end: now,
      ),
      'steps_1h': steps1h,
      'steps_24h': steps24h,
      'active_energy_1h': energy1h,
      'active_energy_5m': _sum(
        samples,
        HealthMetricType.activeEnergyBurned,
        start: shortWindowStart,
        end: now,
      ),
      'exercise_time_45m': exercise45m,
      'minutes_since_workout': minutesSinceWorkout.toDouble(),
      'sleep_hours_latest': sleepHours,
      'sleep_hours_delta_7': sleepHours != null
          ? sleepHours - (sleepBaseline.median ?? 7.5)
          : null,
      'sleep_efficiency_latest': sleepEfficiency,
      'sleep_efficiency_delta_7':
          sleepEfficiency != null && sleepEfficiencyBaseline.median != null
          ? sleepEfficiency - sleepEfficiencyBaseline.median!
          : null,
      'sleep_nights_7': nights
          .where(
            (night) => night.end.isAfter(now.subtract(const Duration(days: 7))),
          )
          .length
          .toDouble(),
      'recent_sleep_score': recentSleepScore,
      'cardiac_event_present': _hasCardiacEvent(samples, dayStart, now) ? 1 : 0,
      'high_hr_event_present':
          _hasType(
            samples,
            HealthMetricType.highHeartRateEvent,
            start: dayStart,
            end: now,
          )
          ? 1
          : 0,
      'missing_hr': hrMean == null ? 1 : 0,
      'missing_resting_hr': rhrDay == null ? 1 : 0,
      'missing_hrv_sdnn': hrvSdnnDay == null ? 1 : 0,
      'missing_hrv_rmssd': hrvRmssdDay == null ? 1 : 0,
      'missing_resp_rate': respContext.isEmpty ? 1 : 0,
      'missing_temperature': tempDay == null ? 1 : 0,
      'missing_spo2': spo2Day.isEmpty ? 1 : 0,
      'missing_sleep': latestNight == null ? 1 : 0,
      'missing_activity': steps1h == null && energy1h == null ? 1 : 0,
    };
  }

  StressQualityBreakdown _estimateQuality({
    required List<HealthMetricSample> samples,
    required Map<String, double?> features,
    required DateTime windowStart,
    required DateTime contextStart,
    required DateTime dayStart,
    required DateTime baselineStart,
    required DateTime now,
  }) {
    final currentHrCount = _count(
      samples,
      HealthMetricType.heartRate,
      start: windowStart,
      end: now,
    );
    final contextHrCount = _count(
      samples,
      HealthMetricType.heartRate,
      start: contextStart,
      end: now,
    );
    final heartRate = currentHrCount > 0
        ? math.min(currentHrCount / 3.0, 1.0)
        : contextHrCount > 0
        ? 0.70
        : _hasType(
            samples,
            HealthMetricType.heartRate,
            start: now.subtract(const Duration(hours: 2)),
            end: now,
          )
        ? 0.40
        : 0.0;
    final baselineDays = features['hr_baseline_days_14'] ?? 0;
    final baseline = (baselineDays / 7.0).clamp(0.0, 1.0);
    final sleepNights = features['sleep_nights_7'] ?? 0;
    final sleep = (sleepNights / 3.0).clamp(0.0, 1.0);
    final activityContext = (features['missing_activity'] ?? 1) < 0.5
        ? 1.0
        : 0.45;
    final hrv =
        (features['missing_hrv_sdnn'] ?? 1) < 0.5 ||
            (features['missing_hrv_rmssd'] ?? 1) < 0.5
        ? 1.0
        : _hasAnyType(
            samples,
            const [
              HealthMetricType.heartRateVariabilitySdnn,
              HealthMetricType.heartRateVariabilityRmssd,
            ],
            start: baselineStart,
            end: now,
          )
        ? 0.50
        : 0.0;
    final optionalPresent = [
      (features['missing_resp_rate'] ?? 1) < 0.5,
      (features['missing_temperature'] ?? 1) < 0.5,
      (features['missing_spo2'] ?? 1) < 0.5,
    ].where((item) => item).length;
    final respiratoryTemperatureOxygen = optionalPresent / 3.0;
    final overall =
        (0.35 * heartRate) +
        (0.20 * baseline) +
        (0.15 * sleep) +
        (0.10 * activityContext) +
        (0.10 * hrv) +
        (0.10 * respiratoryTemperatureOxygen);

    return StressQualityBreakdown(
      overall: overall.clamp(0.0, 1.0),
      heartRate: heartRate.clamp(0.0, 1.0),
      baseline: baseline.clamp(0.0, 1.0),
      sleep: sleep.clamp(0.0, 1.0),
      activityContext: activityContext.clamp(0.0, 1.0),
      hrv: hrv.clamp(0.0, 1.0),
      respiratoryTemperatureOxygen: respiratoryTemperatureOxygen.clamp(
        0.0,
        1.0,
      ),
    );
  }

  _TrainedScorecardPrediction _scoreWithTrainedScorecard(
    Map<String, double?> features,
    StressScorecardArtifact scorecard,
  ) {
    var logit = scorecard.intercept;
    final contributions = <StressModelContribution>[];
    for (var i = 0; i < scorecard.featureNames.length; i++) {
      final featureName = scorecard.featureNames[i];
      final raw = features[featureName];
      final hasRaw = raw != null && raw.isFinite;
      final imputed = hasRaw ? raw : scorecard.imputerStatistics[i];
      final denom = scorecard.scale[i] == 0 ? 1.0 : scorecard.scale[i];
      final scaled = ((imputed - scorecard.center[i]) / denom)
          .clamp(-20.0, 20.0)
          .toDouble();
      final coefficient = scorecard.coefficients[i];
      final contribution = scaled * coefficient;
      logit += contribution;
      if (coefficient != 0) {
        contributions.add(
          StressModelContribution(
            featureName: featureName,
            rawValue: hasRaw ? raw : null,
            imputedValue: imputed,
            isImputed: !hasRaw,
            normalizedValue: scaled,
            coefficient: coefficient,
            contribution: contribution,
          ),
        );
      }
    }
    final calibratedLogit =
        (logit * scorecard.calibrationCoefficient) +
        scorecard.calibrationIntercept;
    final probability = 1.0 / (1.0 + math.exp(-calibratedLogit.clamp(-40, 40)));
    contributions.sort(
      (a, b) => b.contribution.abs().compareTo(a.contribution.abs()),
    );
    return _TrainedScorecardPrediction(
      score: (probability * 100.0).clamp(0.0, 100.0).toDouble(),
      contributions: contributions,
    );
  }

  double _scoreWithDefaultScorecard(Map<String, double?> features) {
    final hr = math.max(
      _positiveFeature(features['hr_z_14'], scale: 3.0),
      _positiveFeature(features['hr_z_5m_14'], scale: 3.0),
    );
    final rhr = _positiveFeature(features['resting_hr_z_30'], scale: 2.5);
    final lowSdnn = _negativeFeature(features['hrv_sdnn_z_30'], scale: 3.0);
    final lowRmssd = _negativeFeature(features['hrv_rmssd_z_30'], scale: 3.0);
    final hrv = lowSdnn == 0 && lowRmssd == 0
        ? math.max(lowSdnn, lowRmssd)
        : (lowSdnn + lowRmssd) / (lowSdnn > 0 && lowRmssd > 0 ? 2.0 : 1.0);
    final resp = _positiveFeature(features['resp_rate_z_14'], scale: 2.5);
    final sleepDebt = _positiveFeature(
      -(features['sleep_hours_delta_7'] ?? 0),
      scale: 2.0,
    );
    final sleepEfficiencyDrop = _positiveFeature(
      -(features['sleep_efficiency_delta_7'] ?? 0),
      scale: 20.0,
    );
    final temp = _absoluteFeature(features['temperature_z_30'], scale: 3.0);
    final lowRecentSleepScore = _positiveFeature(
      75.0 - (features['recent_sleep_score'] ?? 75.0),
      scale: 35.0,
    );
    final activityConfounder = _activityConfounder(features);
    final highHrEvent = (features['high_hr_event_present'] ?? 0).clamp(
      0.0,
      1.0,
    );

    final logit =
        -2.10 +
        (2.20 * hr) +
        (1.40 * rhr) +
        (1.75 * hrv) +
        (1.10 * resp) +
        (0.85 * sleepDebt) +
        (0.55 * sleepEfficiencyDrop) +
        (0.45 * temp) +
        (0.45 * lowRecentSleepScore) +
        (0.35 * highHrEvent) -
        (0.75 * activityConfounder);
    final probability = 1.0 / (1.0 + math.exp(-logit));
    return (probability * 100.0).clamp(0.0, 100.0);
  }

  double? _ruleBasedFallbackScore(Map<String, double?> features) {
    final hasAny = features.values.any((value) => value != null);
    if (!hasAny) return null;

    var score = 25.0;
    final hrZ = features['hr_z_14'];
    final rhrZ = features['resting_hr_z_30'];
    final sdnnZ = features['hrv_sdnn_z_30'];
    final rmssdZ = features['hrv_rmssd_z_30'];
    final respZ = features['resp_rate_z_14'];
    final sleepDelta = features['sleep_hours_delta_7'];

    if (hrZ != null && hrZ > 1.5) score += 22;
    if (rhrZ != null && rhrZ > 1.2) score += 18;
    if ((sdnnZ != null && sdnnZ < -1.2) || (rmssdZ != null && rmssdZ < -1.2)) {
      score += 18;
    }
    if (respZ != null && respZ > 1.5) score += 12;
    if (sleepDelta != null && sleepDelta < -1.0) score += 10;
    if (_activityConfounder(features) > 0.5) score -= 15;

    return score.clamp(0.0, 100.0);
  }

  List<StressReasonCode> _buildReasonCodes({
    required Map<String, double?> features,
    required StressQualityBreakdown quality,
  }) {
    final result = <StressReasonCode>[];

    void add(
      String code,
      String severity,
      double contribution,
      String message,
    ) {
      result.add(
        StressReasonCode(
          code: code,
          severity: severity,
          contribution: contribution.clamp(0.0, 1.0),
          message: message,
        ),
      );
    }

    final hrZ = features['hr_z_14'];
    final hr5mZ = features['hr_z_5m_14'];
    final elevatedHrZ = [hrZ, hr5mZ].whereType<double>().fold<double?>(
      null,
      (best, value) => best == null ? value : math.max(best, value),
    );
    if (elevatedHrZ != null && elevatedHrZ >= 1.5) {
      add(
        'elevated_hr_vs_baseline',
        elevatedHrZ >= 2.5 ? 'high' : 'medium',
        _positiveFeature(elevatedHrZ, scale: 3.0),
        'Heart rate is above the personal baseline.',
      );
    }

    final rhrZ = features['resting_hr_z_30'];
    if (rhrZ != null && rhrZ >= 1.2) {
      add(
        'elevated_resting_hr_vs_baseline',
        rhrZ >= 2.0 ? 'high' : 'medium',
        _positiveFeature(rhrZ, scale: 2.5),
        'Resting heart rate is above the personal baseline.',
      );
    }

    final sdnnZ = features['hrv_sdnn_z_30'];
    final rmssdZ = features['hrv_rmssd_z_30'];
    final hrvSignal = math.max(
      _negativeFeature(sdnnZ, scale: 3.0),
      _negativeFeature(rmssdZ, scale: 3.0),
    );
    if (hrvSignal >= 0.30) {
      add(
        'low_hrv_vs_baseline',
        hrvSignal >= 0.65 ? 'high' : 'medium',
        hrvSignal,
        'HRV is below the personal baseline.',
      );
    }

    final respZ = features['resp_rate_z_14'];
    if (respZ != null && respZ >= 1.5) {
      add(
        'elevated_respiratory_rate',
        respZ >= 2.5 ? 'high' : 'medium',
        _positiveFeature(respZ, scale: 2.5),
        'Respiratory rate is above the personal baseline.',
      );
    }

    final sleepDelta = features['sleep_hours_delta_7'];
    if (sleepDelta != null && sleepDelta <= -1.0) {
      add(
        'poor_sleep_recovery',
        sleepDelta <= -2.0 ? 'high' : 'medium',
        _positiveFeature(-sleepDelta, scale: 2.0),
        'Recent sleep is below the personal baseline.',
      );
    }

    final tempZ = features['temperature_z_30'];
    if (tempZ != null && tempZ.abs() >= 1.5) {
      add(
        'temperature_deviation',
        'low',
        _absoluteFeature(tempZ, scale: 3.0),
        'Temperature differs from the personal baseline.',
      );
    }

    if (quality.overall < _minModelQuality) {
      add(
        'low_data_quality',
        'medium',
        1.0 - quality.overall,
        'Data coverage is low for reliable stress estimation.',
      );
    }

    return result..sort((a, b) => b.contribution.compareTo(a.contribution));
  }

  List<String> _missingModalities(Map<String, double?> features) {
    final mapping = {
      'missing_hr': 'heart_rate',
      'missing_resting_hr': 'resting_heart_rate',
      'missing_hrv_sdnn': 'hrv_sdnn',
      'missing_hrv_rmssd': 'hrv_rmssd',
      'missing_resp_rate': 'respiratory_rate',
      'missing_temperature': 'temperature',
      'missing_spo2': 'blood_oxygen',
      'missing_sleep': 'sleep',
      'missing_activity': 'activity',
    };
    return mapping.entries
        .where((entry) => (features[entry.key] ?? 0) > 0.5)
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  double _confidenceFromQuality({
    required StressQualityBreakdown quality,
    required List<String> missingModalities,
  }) {
    var confidence = quality.overall;
    if (missingModalities.contains('hrv_sdnn') &&
        missingModalities.contains('hrv_rmssd')) {
      confidence *= 0.88;
    }
    if (missingModalities.contains('respiratory_rate')) {
      confidence *= 0.94;
    }
    if (missingModalities.contains('sleep')) {
      confidence *= 0.90;
    }
    return confidence.clamp(0.0, 1.0);
  }

  double _activityConfounder(Map<String, double?> features) {
    final steps5m = features['steps_5m'] ?? 0;
    final steps1h = features['steps_1h'] ?? 0;
    final activeEnergy5m = features['active_energy_5m'] ?? 0;
    final activeEnergy1h = features['active_energy_1h'] ?? 0;
    final exercise45m = features['exercise_time_45m'] ?? 0;
    final minutesSinceWorkout = features['minutes_since_workout'] ?? 9999;
    final stepSignal = math.max(
      (steps5m / 450.0).clamp(0.0, 1.0),
      (steps1h / 1800.0).clamp(0.0, 1.0),
    );
    final energySignal = math.max(
      (activeEnergy5m / 45.0).clamp(0.0, 1.0),
      (activeEnergy1h / 180.0).clamp(0.0, 1.0),
    );
    final exerciseSignal = (exercise45m / 20.0).clamp(0.0, 1.0);
    final workoutSignal = minutesSinceWorkout < _workoutCooldownMinutes
        ? 1.0
        : 0.0;
    return math.max(
      workoutSignal,
      math.max(stepSignal, math.max(energySignal, exerciseSignal)),
    );
  }

  double? _stressFromFallbackHealthScore(int? fallbackHealthScore) {
    if (fallbackHealthScore == null) return null;
    return (100 - fallbackHealthScore.clamp(0, 100)).toDouble();
  }

  static String _statusForScore(double score) {
    if (score >= 70) return 'risk';
    if (score >= 40) return 'attention';
    return 'stable';
  }

  static double _positiveFeature(double? value, {required double scale}) {
    if (value == null || !value.isFinite || value <= 0) return 0;
    return (value / scale).clamp(0.0, 1.0);
  }

  static double _negativeFeature(double? value, {required double scale}) {
    if (value == null || !value.isFinite || value >= 0) return 0;
    return (-value / scale).clamp(0.0, 1.0);
  }

  static double _absoluteFeature(double? value, {required double scale}) {
    if (value == null || !value.isFinite) return 0;
    return (value.abs() / scale).clamp(0.0, 1.0);
  }

  static double? _zScore(double? value, _RobustBaseline baseline) {
    if (value == null || baseline.median == null) return null;
    final spread = baseline.robustStd;
    if (spread == null || spread <= 0) return null;
    return ((value - baseline.median!) / spread).clamp(-5.0, 5.0);
  }

  static _RobustBaseline _robustBaseline(List<double> values) {
    final valid = values.where((v) => v.isFinite).toList(growable: false)
      ..sort();
    if (valid.isEmpty) return const _RobustBaseline();
    final median = _median(valid);
    final deviations = valid.map((v) => (v - median).abs()).toList()..sort();
    final mad = _median(deviations);
    final robustStd = mad > 0 ? 1.4826 * mad : _std(valid);
    return _RobustBaseline(median: median, robustStd: robustStd);
  }

  static double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? _std(List<double> values) {
    if (values.length < 2) return null;
    final mean = _mean(values)!;
    final variance =
        values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static double _median(List<double> sortedValues) {
    final n = sortedValues.length;
    final mid = n ~/ 2;
    if (n.isOdd) return sortedValues[mid];
    return (sortedValues[mid - 1] + sortedValues[mid]) / 2.0;
  }

  static double? _min(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.min);
  }

  static double? _max(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.max);
  }

  static double? _slope(List<double> values) {
    if (values.length < 2) return null;
    final n = values.length.toDouble();
    final xMean = (n - 1) / 2.0;
    final yMean = _mean(values)!;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < values.length; i++) {
      final dx = i - xMean;
      numerator += dx * (values[i] - yMean);
      denominator += dx * dx;
    }
    if (denominator == 0) return 0;
    return numerator / denominator;
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

  static double? _latestAnyValue(
    List<HealthMetricSample> samples,
    List<HealthMetricType> types, {
    required DateTime start,
    required DateTime end,
  }) {
    final typeSet = types.toSet();
    HealthMetricSample? latest;
    for (final sample in samples) {
      if (!typeSet.contains(sample.type)) continue;
      final ts = sample.timestamp.toUtc();
      if (!_inRange(ts, start, end)) continue;
      if (latest == null || ts.isAfter(latest.timestamp.toUtc())) {
        latest = sample;
      }
    }
    return latest?.value;
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

  static int _uniqueDays(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    return samples
        .where((sample) => sample.type == type)
        .where((sample) => _inRange(sample.timestamp.toUtc(), start, end))
        .map((sample) {
          final ts = sample.timestamp.toUtc();
          return DateTime.utc(ts.year, ts.month, ts.day).toIso8601String();
        })
        .toSet()
        .length;
  }

  static bool _hasType(
    List<HealthMetricSample> samples,
    HealthMetricType type, {
    required DateTime start,
    required DateTime end,
  }) {
    return samples.any(
      (sample) =>
          sample.type == type && _inRange(sample.timestamp.toUtc(), start, end),
    );
  }

  static bool _hasAnyType(
    List<HealthMetricSample> samples,
    List<HealthMetricType> types, {
    required DateTime start,
    required DateTime end,
  }) {
    final typeSet = types.toSet();
    return samples.any(
      (sample) =>
          typeSet.contains(sample.type) &&
          _inRange(sample.timestamp.toUtc(), start, end),
    );
  }

  static bool _hasCardiacEvent(
    List<HealthMetricSample> samples,
    DateTime start,
    DateTime end,
  ) {
    return _hasAnyType(
      samples,
      const [
        HealthMetricType.highHeartRateEvent,
        HealthMetricType.lowHeartRateEvent,
        HealthMetricType.irregularHeartRateEvent,
        HealthMetricType.atrialFibrillationBurden,
      ],
      start: start,
      end: end,
    );
  }

  static int _minutesSinceLatestWorkout(
    List<HealthMetricSample> samples, {
    required DateTime now,
  }) {
    DateTime? latest;
    for (final sample in samples) {
      if (sample.type != HealthMetricType.workout) continue;
      final ts = sample.timestamp.toUtc();
      if (ts.isAfter(now)) continue;
      if (latest == null || ts.isAfter(latest)) {
        latest = ts;
      }
    }
    if (latest == null) return 9999;
    return now.difference(latest).inMinutes;
  }

  static List<_SleepNight> _buildSleepNights(
    List<HealthMetricSample> samples, {
    required DateTime now,
  }) {
    final byDate = <String, _SleepNightAccumulator>{};
    final start = now.subtract(const Duration(days: 30));

    for (final sample in samples) {
      if (!_sleepTypes.contains(sample.type) || sample.value <= 0) continue;
      final end = sample.timestamp.toUtc();
      if (!_inRange(end, start, now)) continue;
      final minutes = sample.value;
      final date = end.hour < 18 ? end : end.add(const Duration(days: 1));
      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final accumulator = byDate.putIfAbsent(
        dateKey,
        () => _SleepNightAccumulator(dateKey),
      );
      accumulator.add(sample.type, minutes, end);
    }

    final nights =
        byDate.values
            .map((accumulator) => accumulator.build())
            .where((night) => night.sleepMinutes >= 60)
            .toList(growable: false)
          ..sort((a, b) => a.end.compareTo(b.end));
    return nights;
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  static const Set<HealthMetricType> _trackedTypes = {
    HealthMetricType.heartRate,
    HealthMetricType.restingHeartRate,
    HealthMetricType.walkingHeartRate,
    HealthMetricType.heartRateVariabilitySdnn,
    HealthMetricType.heartRateVariabilityRmssd,
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
    HealthMetricType.exerciseTime,
    HealthMetricType.workout,
    HealthMetricType.highHeartRateEvent,
    HealthMetricType.lowHeartRateEvent,
    HealthMetricType.irregularHeartRateEvent,
    HealthMetricType.atrialFibrillationBurden,
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
}

class _RobustBaseline {
  final double? median;
  final double? robustStd;

  const _RobustBaseline({this.median, this.robustStd});
}

class _TrainedScorecardPrediction {
  final double score;
  final List<StressModelContribution> contributions;

  const _TrainedScorecardPrediction({
    required this.score,
    required this.contributions,
  });
}

class _SleepNight {
  final String dateKey;
  final DateTime end;
  final double sleepMinutes;
  final double inBedMinutes;

  const _SleepNight({
    required this.dateKey,
    required this.end,
    required this.sleepMinutes,
    required this.inBedMinutes,
  });

  double get sleepHours => sleepMinutes / 60.0;

  double get sleepEfficiencyPct {
    if (inBedMinutes <= 0) return 0;
    return (sleepMinutes / inBedMinutes * 100.0).clamp(0.0, 100.0);
  }
}

class _SleepNightAccumulator {
  final String dateKey;
  DateTime? latestEnd;
  double genericAsleep = 0;
  double stagedAsleep = 0;
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
      case HealthMetricType.sleepLight:
      case HealthMetricType.sleepRem:
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
    return _SleepNight(
      dateKey: dateKey,
      end: latestEnd ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sleepMinutes: asleep,
      inBedMinutes: math.max(resolvedInBed, asleep),
    );
  }
}
