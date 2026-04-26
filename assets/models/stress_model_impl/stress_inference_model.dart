import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

class StressInferenceResult {
  final double stressScore;
  final double confidence;
  final String status;
  final Map<String, double?> rawFeatures;
  final List<String> missingModalities;
  final String? reason;

  const StressInferenceResult({
    required this.stressScore,
    required this.confidence,
    required this.status,
    required this.rawFeatures,
    required this.missingModalities,
    this.reason,
  });
}

class StressInferenceModel {
  static const String modelAsset = 'assets/models/stress/model_stress.onnx';
  static const String preprocessorAsset =
      'assets/models/stress/preprocessor_v1.json';
  static const String featureContractAsset =
      'assets/models/stress/feature_contract_stress_v1.json';

  OrtSession? _session;
  late final List<String> _featureNames;
  late final List<double?> _imputerStats;
  late final List<double> _center;
  late final List<double> _scale;

  Future<void> init() async {
    final modelBytes = (await rootBundle.load(modelAsset)).buffer.asUint8List();
    final preprocessorJson =
        json.decode(await rootBundle.loadString(preprocessorAsset))
            as Map<String, dynamic>;
    await rootBundle.loadString(featureContractAsset);

    _featureNames = List<String>.from(
      preprocessorJson['feature_names'] as List,
    );
    _imputerStats = List<dynamic>.from(
      preprocessorJson['imputer_statistics'] as List,
    ).map((e) => e == null ? null : (e as num).toDouble()).toList();
    _center = List<double>.from(
      (preprocessorJson['scaler_center'] as List).map(
        (e) => (e as num).toDouble(),
      ),
    );
    _scale = List<double>.from(
      (preprocessorJson['scaler_scale'] as List).map(
        (e) => (e as num).toDouble(),
      ),
    );

    final options = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, options);
  }

  Future<StressInferenceResult> infer({
    required Map<String, List<double>> series,
    double? recentSleepScore,
    double? recentActivityScore,
    int? minutesSinceWorkout,
    DateTime? windowEnd,
  }) async {
    if (_session == null) {
      return const StressInferenceResult(
        stressScore: 0,
        confidence: 0,
        status: 'insufficient',
        rawFeatures: {},
        missingModalities: ['model'],
        reason: 'model_not_ready',
      );
    }

    final end = windowEnd ?? DateTime.now();
    final features = _buildFeatures(
      series: series,
      recentSleepScore: recentSleepScore,
      recentActivityScore: recentActivityScore,
      minutesSinceWorkout: minutesSinceWorkout,
      windowEnd: end,
    );

    final transformed = Float32List(_featureNames.length);
    for (var i = 0; i < _featureNames.length; i++) {
      final raw = features[_featureNames[i]];
      final imputed = raw ?? _imputerStats[i] ?? 0.0;
      final denom = _scale[i] == 0 ? 1.0 : _scale[i];
      transformed[i] = ((imputed - _center[i]) / denom).toDouble();
    }

    final input = OrtValueTensor.createTensorWithDataList(transformed, [
      1,
      _featureNames.length,
    ]);
    final outputs = _session!.run(OrtRunOptions(), {'features': input});
    final dynamic raw = outputs.first?.value;
    final double logit = raw is List
        ? ((raw.first as num).toDouble())
        : (raw as num).toDouble();
    final probStress = 1.0 / (1.0 + math.exp(-logit));
    final stressScore = (1.0 - probStress) * 100.0;

    final missing = features.entries
        .where((e) => e.key.startsWith('missing_') && (e.value ?? 0) > 0.5)
        .map((e) => e.key)
        .toList();
    final coverage = features['coverage_ratio'] ?? 0.0;
    var confidence = coverage;
    if (missing.contains('missing_hrv_sdnn')) {
      confidence *= 0.85;
    }
    if (missing.contains('missing_resp_rate')) {
      confidence *= 0.90;
    }
    if (missing.contains('missing_body_temp') &&
        missing.contains('missing_wrist_temp')) {
      confidence *= 0.90;
    }
    if (missing.contains('missing_hr')) {
      confidence = 0.0;
    }

    final status = confidence == 0
        ? 'insufficient'
        : stressScore >= 70
        ? 'stable'
        : stressScore >= 40
        ? 'attention'
        : 'risk';

    return StressInferenceResult(
      stressScore: stressScore.clamp(0, 100),
      confidence: confidence.clamp(0, 1),
      status: status,
      rawFeatures: features,
      missingModalities: missing,
      reason: confidence == 0 ? 'insufficient_data' : null,
    );
  }

  Map<String, double?> _buildFeatures({
    required Map<String, List<double>> series,
    required DateTime windowEnd,
    double? recentSleepScore,
    double? recentActivityScore,
    int? minutesSinceWorkout,
  }) {
    double? mean(String key) {
      final values = series[key];
      if (values == null || values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    double? std(String key) {
      final values = series[key];
      if (values == null || values.length < 2) return null;
      final m = mean(key)!;
      final variance =
          values.map((v) => math.pow(v - m, 2)).reduce((a, b) => a + b) /
          values.length;
      return math.sqrt(variance);
    }

    double? minVal(String key) =>
        series[key]?.isEmpty ?? true ? null : series[key]!.reduce(math.min);
    double? maxVal(String key) =>
        series[key]?.isEmpty ?? true ? null : series[key]!.reduce(math.max);

    double? slope(String key) {
      final values = series[key];
      if (values == null || values.length < 2) return null;
      final n = values.length.toDouble();
      final xMean = (n - 1) / 2.0;
      final yMean = values.reduce((a, b) => a + b) / n;
      double num = 0, den = 0;
      for (var i = 0; i < values.length; i++) {
        final dx = i - xMean;
        num += dx * (values[i] - yMean);
        den += dx * dx;
      }
      return den == 0 ? 0 : num / den;
    }

    final hrMean = mean('HEART_RATE');
    final rhrMean = mean('RESTING_HEART_RATE');
    final hrvMean = mean('HEART_RATE_VARIABILITY_SDNN');
    final respMean = mean('RESPIRATORY_RATE');
    final steps = series['STEPS']?.fold<double>(0, (a, b) => a + b);
    final distance = series['DISTANCE_WALKING_RUNNING']?.fold<double>(
      0,
      (a, b) => a + b,
    );
    final energy = series['ACTIVE_ENERGY_BURNED']?.fold<double>(
      0,
      (a, b) => a + b,
    );
    final exercise = series['EXERCISE_TIME']?.fold<double>(0, (a, b) => a + b);
    final bodyTemp = mean('BODY_TEMPERATURE');
    final wristTemp = mean('SLEEP_WRIST_TEMPERATURE');
    final spo2 = mean('BLOOD_OXYGEN');

    final presentSeries = [
      series['HEART_RATE'],
      series['HEART_RATE_VARIABILITY_SDNN'],
      series['RESPIRATORY_RATE'],
      series['BODY_TEMPERATURE'],
      series['BLOOD_OXYGEN'],
    ].where((s) => s != null && s.isNotEmpty).length;

    final hour = windowEnd.hour + windowEnd.minute / 60.0;

    final map = <String, double?>{
      'hr_mean': hrMean,
      'hr_std': std('HEART_RATE'),
      'hr_min': minVal('HEART_RATE'),
      'hr_max': maxVal('HEART_RATE'),
      'hr_slope': slope('HEART_RATE'),
      'hr_delta_prev': null,
      'resting_hr_mean': rhrMean,
      'hr_over_rhr': (hrMean != null && rhrMean != null && rhrMean != 0)
          ? hrMean / rhrMean
          : null,
      'hrv_sdnn_mean': hrvMean,
      'hrv_sdnn_std': std('HEART_RATE_VARIABILITY_SDNN'),
      'resp_rate_mean': respMean,
      'resp_rate_std': std('RESPIRATORY_RATE'),
      'steps_sum': steps,
      'distance_sum': distance,
      'active_energy_sum': energy,
      'exercise_time_sum': exercise,
      'body_temp_mean': bodyTemp,
      'wrist_temp_mean': wristTemp,
      'spo2_mean': spo2,
      'coverage_ratio': presentSeries / 5.0,
      'minutes_since_workout': (minutesSinceWorkout ?? 999).toDouble(),
      'recent_sleep_score': recentSleepScore,
      'recent_activity_score': recentActivityScore,
      'hour_sin': math.sin(2 * math.pi * hour / 24.0),
      'hour_cos': math.cos(2 * math.pi * hour / 24.0),
      'activity_load_proxy': ((steps ?? 0) * 0.5) + ((energy ?? 0) * 0.5),
      'physiological_strain_proxy':
          [hrMean, respMean, bodyTemp].whereType<double>().isEmpty
          ? null
          : [
                  hrMean,
                  respMean,
                  bodyTemp,
                ].whereType<double>().reduce((a, b) => a + b) /
                [hrMean, respMean, bodyTemp].whereType<double>().length,
      'missing_hr': hrMean == null ? 1 : 0,
      'missing_resting_hr': rhrMean == null ? 1 : 0,
      'missing_hrv_sdnn': hrvMean == null ? 1 : 0,
      'missing_resp_rate': respMean == null ? 1 : 0,
      'missing_steps': steps == null ? 1 : 0,
      'missing_distance': distance == null ? 1 : 0,
      'missing_active_energy': energy == null ? 1 : 0,
      'missing_exercise_time': exercise == null ? 1 : 0,
      'missing_body_temp': bodyTemp == null ? 1 : 0,
      'missing_wrist_temp': wristTemp == null ? 1 : 0,
      'missing_spo2': spo2 == null ? 1 : 0,
    };

    return map;
  }
}
