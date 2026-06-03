import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/perf/perf_probe.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';

class SleepQualityInferenceResult {
  final double? score;
  final double confidence;
  final bool insufficientData;
  final String modelVersion;
  final String selectedModel;
  final int nightsUsed;
  final String reason;
  final SleepNightDiagnostics? latestNight;

  const SleepQualityInferenceResult({
    required this.score,
    required this.confidence,
    required this.insufficientData,
    required this.modelVersion,
    required this.selectedModel,
    required this.nightsUsed,
    required this.reason,
    this.latestNight,
  });

  factory SleepQualityInferenceResult.insufficient({
    String reason = 'unknown',
    String modelVersion = 'sleep-quality-v2',
    String selectedModel = 'unknown',
    int nightsUsed = 0,
    SleepNightDiagnostics? latestNight,
  }) {
    return SleepQualityInferenceResult(
      score: null,
      confidence: 0,
      insufficientData: true,
      modelVersion: modelVersion,
      selectedModel: selectedModel,
      nightsUsed: nightsUsed,
      reason: reason,
      latestNight: latestNight,
    );
  }
}

class SleepNightDiagnostics {
  final DateTime startUtc;
  final DateTime endUtc;
  final double sleepMinutes;
  final double inBedMinutes;
  final double sleepEfficiencyPct;
  final double asleepHour;
  final double wakeupHour;
  final double coverageHours;
  final double windowCount;
  final double? hrMean;
  final double? hrStd;
  final double? hrMin;
  final double? hrMax;
  final double? rmssdMean;
  final double? sdnnMean;
  final double? stepsMean;
  final double? distanceMean;
  final double? caloriesMean;
  final List<String> missingOptionalModalities;

  const SleepNightDiagnostics({
    required this.startUtc,
    required this.endUtc,
    required this.sleepMinutes,
    required this.inBedMinutes,
    required this.sleepEfficiencyPct,
    required this.asleepHour,
    required this.wakeupHour,
    required this.coverageHours,
    required this.windowCount,
    required this.hrMean,
    required this.hrStd,
    required this.hrMin,
    required this.hrMax,
    required this.rmssdMean,
    required this.sdnnMean,
    required this.stepsMean,
    required this.distanceMean,
    required this.caloriesMean,
    required this.missingOptionalModalities,
  });
}

class SleepQualityInferenceModel {
  static const String _modelAssetPath =
      'assets/models/sleep_quality/model_sleep_quality.onnx';
  static const String _preprocessorAssetPath =
      'assets/models/sleep_quality/preprocessor_v2.json';
  static const String _metadataAssetPath =
      'assets/models/sleep_quality/model_metadata.json';
  static const String _contractAssetPath =
      'assets/models/sleep_quality/feature_contract_health_v2.json';
  static const String _fallbackModelVersion = 'sleep-quality-v3';
  static const String _fallbackSelectedModel = 'student_residual_mlp';

  bool _initialized = false;
  bool _initFailed = false;
  String? _initFailureDetail;
  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  String _inputName = 'float_input';
  String _modelVersion = _fallbackModelVersion;
  String _selectedModel = _fallbackSelectedModel;

  List<String> _featureNames = const [];
  List<double> _median = const [];
  List<double> _clipLow = const [];
  List<double> _clipHigh = const [];
  List<double> _mean = const [];
  List<double> _std = const [];
  double _mlpTargetMean = 0.0;
  double _mlpTargetStd = 1.0;
  String _preprocessorVersion = 'preprocessor_v2';
  String _preprocessorFeatureMode = 'unknown';
  String _preprocessorObjective = 'unknown';

  int _minimumHistoryDays = 14;
  int _minimumNightsForInference = 5;
  int _minimumNightsForBaseline = 7;
  List<HealthMetricType> _requiredMetricTypes = const [
    HealthMetricType.sleepAsleep,
    HealthMetricType.heartRate,
    HealthMetricType.steps,
  ];
  List<HealthMetricType> _optionalMetricTypes = const [];

  final _logger = AppLogger.instance;

  Future<SleepQualityInferenceResult> infer({
    required List<HealthMetricSample> samples,
    DateTime? now,
  }) async {
    return PerfProbe.measureAsync(
      'model.sleep_quality.infer',
      () async {
        await _ensureInitialized();
        if (_initFailed || _session == null || _featureNames.isEmpty) {
          final detail = _initFailureDetail?.trim();
          return SleepQualityInferenceResult.insufficient(
            reason: detail == null || detail.isEmpty
                ? 'model_not_ready'
                : 'model_not_ready: $detail',
            modelVersion: _modelVersion,
            selectedModel: _selectedModel,
          );
        }

        final utcNow = (now ?? DateTime.now()).toUtc();
        final relevantSamples = samples
            .where(
              (item) => item.sourceId.trim().toLowerCase() != 'local_manual',
            )
            .where((item) => _trackedTypes.contains(item.type))
            .where((item) => !item.timestamp.toUtc().isAfter(utcNow))
            .toList(growable: false);
        final recentNights = _buildNightlyFeatures(
          _resolveRecentSamples(samples: relevantSamples, nowUtc: utcNow),
        );
        final latestNightDiagnostics = recentNights.isEmpty
            ? null
            : _buildNightDiagnostics(recentNights.last);

        final requirementsOk = _validateDataRequirements(
          samples: relevantSamples,
          nowUtc: utcNow,
        );
        if (!requirementsOk.ok) {
          _logger.warning(
            'model.sleep_quality',
            'Insufficient data for inference',
            payload: {
              'reason': requirementsOk.reason,
              'nights': requirementsOk.nights,
              'minimumHistoryDays': _minimumHistoryDays,
              'minimumNightsForInference': _minimumNightsForInference,
              'requiredMetricTypes': _requiredMetricTypes
                  .map((t) => t.name)
                  .toList(),
            },
          );
          return SleepQualityInferenceResult.insufficient(
            reason: requirementsOk.reason,
            modelVersion: _modelVersion,
            selectedModel: _selectedModel,
            nightsUsed: requirementsOk.nights,
            latestNight: latestNightDiagnostics,
          );
        }

        final nights = _buildNightlyFeatures(relevantSamples);
        if (nights.isEmpty) {
          _logger.warning(
            'model.sleep_quality',
            'No valid nights after feature extraction',
          );
          return SleepQualityInferenceResult.insufficient(
            reason: 'no_nights',
            modelVersion: _modelVersion,
            selectedModel: _selectedModel,
            latestNight: latestNightDiagnostics,
          );
        }

        final latestNight = nights.last;
        final rawVector = _featureNames
            .map((name) => latestNight.features[name] ?? double.nan)
            .toList(growable: false);
        final scaledInput = _imputeAndScale(rawVector);

        try {
          final value = await _runOnnx(scaledInput);
          if (value == null || value.isNaN || value.isInfinite) {
            return SleepQualityInferenceResult.insufficient(
              reason: 'onnx_output_unrecognized',
              modelVersion: _modelVersion,
              selectedModel: _selectedModel,
              nightsUsed: nights.length,
              latestNight: _buildNightDiagnostics(latestNight),
            );
          }

          final score = _restoreModelOutput(value).clamp(0.0, 100.0);
          final confidence = _estimateConfidence(
            samples: relevantSamples,
            nights: nights,
            nowUtc: utcNow,
          );
          _logger.info(
            'model.sleep_quality',
            'Inference success',
            payload: {
              'score': score,
              'confidence': confidence,
              'nightsUsed': nights.length,
              'modelVersion': _modelVersion,
              'selectedModel': _selectedModel,
            },
          );

          return SleepQualityInferenceResult(
            score: score,
            confidence: confidence,
            insufficientData: false,
            modelVersion: _modelVersion,
            selectedModel: _selectedModel,
            nightsUsed: nights.length,
            reason: 'ok',
            latestNight: _buildNightDiagnostics(latestNight),
          );
        } catch (error, stackTrace) {
          _logger.error(
            'model.sleep_quality',
            'Inference failed',
            payload: {'error': '$error', 'stackTrace': '$stackTrace'},
          );
          return SleepQualityInferenceResult.insufficient(
            reason: 'inference_exception',
            modelVersion: _modelVersion,
            selectedModel: _selectedModel,
            nightsUsed: nights.length,
            latestNight: _buildNightDiagnostics(latestNight),
          );
        }
      },
      payload: <String, Object?>{'sample_count': samples.length},
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    try {
      OrtEnv.instance.init();

      final modelData = await rootBundle.load(_modelAssetPath);
      _sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(
        modelData.buffer.asUint8List(),
        _sessionOptions!,
      );
      if (_session!.inputNames.isNotEmpty) {
        _inputName = _session!.inputNames.first;
      }

      final preprocessorRaw = await rootBundle.loadString(
        _preprocessorAssetPath,
      );
      final preprocessorPayload =
          jsonDecode(preprocessorRaw) as Map<String, dynamic>;
      _featureNames = (preprocessorPayload['feature_names'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(growable: false);
      _median = (preprocessorPayload['median'] as List<dynamic>)
          .map((item) => (item as num).toDouble())
          .toList(growable: false);
      _clipLow = (preprocessorPayload['clip_low'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toDouble())
          .toList(growable: false);
      _clipHigh =
          (preprocessorPayload['clip_high'] as List<dynamic>? ?? const [])
              .map((item) => (item as num).toDouble())
              .toList(growable: false);
      _mean = (preprocessorPayload['mean'] as List<dynamic>)
          .map((item) => (item as num).toDouble())
          .toList(growable: false);
      _std = (preprocessorPayload['std'] as List<dynamic>)
          .map((item) => (item as num).toDouble())
          .toList(growable: false);
      _mlpTargetMean =
          (preprocessorPayload['mlp_target_mean'] as num?)?.toDouble() ?? 0.0;
      _mlpTargetStd =
          (preprocessorPayload['mlp_target_std'] as num?)?.toDouble() ?? 1.0;
      if (!_mlpTargetStd.isFinite || _mlpTargetStd.abs() < 1e-8) {
        _mlpTargetStd = 1.0;
      }
      _preprocessorVersion =
          preprocessorPayload['version']?.toString() ?? 'preprocessor_v1';
      _preprocessorFeatureMode =
          preprocessorPayload['feature_mode']?.toString() ?? 'unknown';
      _preprocessorObjective =
          preprocessorPayload['objective']?.toString() ?? 'unknown';

      final metadataRaw = await rootBundle.loadString(_metadataAssetPath);
      final metadataPayload = jsonDecode(metadataRaw) as Map<String, dynamic>;
      _modelVersion =
          metadataPayload['model_version']?.toString() ?? _fallbackModelVersion;
      _selectedModel =
          metadataPayload['selected_model']?.toString() ??
          _fallbackSelectedModel;
      final mlpOutputScaling =
          metadataPayload['mlp_output_scaling'] as Map<String, dynamic>?;
      if (mlpOutputScaling != null) {
        final mean = (mlpOutputScaling['mean'] as num?)?.toDouble();
        final std = (mlpOutputScaling['std'] as num?)?.toDouble();
        if (mean != null && mean.isFinite) {
          _mlpTargetMean = mean;
        }
        if (std != null && std.isFinite && std.abs() >= 1e-8) {
          _mlpTargetStd = std;
        }
      }

      final contractRaw = await rootBundle.loadString(_contractAssetPath);
      final contractPayload = jsonDecode(contractRaw) as Map<String, dynamic>;
      final requirements =
          contractPayload['requirements'] as Map<String, dynamic>? ?? const {};
      _minimumHistoryDays = _asInt(
        requirements['minimum_history_days'],
        fallback: 14,
      );
      _minimumNightsForInference = _asInt(
        requirements['minimum_sleep_nights_for_inference'],
        fallback: 5,
      );
      _minimumNightsForBaseline = _asInt(
        requirements['minimum_nights_for_baseline'],
        fallback: 7,
      );
      _requiredMetricTypes = _parseMetricList(
        requirements['required_health_metric_types_any_platform']
            as List<dynamic>?,
        const [
          HealthMetricType.sleepAsleep,
          HealthMetricType.heartRate,
          HealthMetricType.steps,
        ],
      );
      _optionalMetricTypes = _parseMetricList(
        requirements['optional_health_metric_types'] as List<dynamic>?,
        const [],
      );

      _logger.info(
        'model.sleep_quality',
        'Model initialized',
        payload: {
          'featureCount': _featureNames.length,
          'modelVersion': _modelVersion,
          'selectedModel': _selectedModel,
          'preprocessorVersion': _preprocessorVersion,
          'preprocessorFeatureMode': _preprocessorFeatureMode,
          'preprocessorObjective': _preprocessorObjective,
          'clipBoundsCount': _clipLow.length,
          'mlpTargetMean': _mlpTargetMean,
          'mlpTargetStd': _mlpTargetStd,
          'minimumHistoryDays': _minimumHistoryDays,
          'minimumNightsForInference': _minimumNightsForInference,
        },
      );
    } catch (error, stackTrace) {
      _initFailed = true;
      _session = null;
      _initFailureDetail = error.toString();
      _logger.error(
        'model.sleep_quality',
        'Initialization failed',
        payload: {
          'error': '$error',
          'stackTrace': '$stackTrace',
          'modelAssetPath': _modelAssetPath,
          'preprocessorAssetPath': _preprocessorAssetPath,
          'metadataAssetPath': _metadataAssetPath,
          'contractAssetPath': _contractAssetPath,
        },
      );
    }
  }

  Future<double?> _runOnnx(List<double> scaledInput) async {
    final session = _session;
    if (session == null) return null;

    final input = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(scaledInput),
      [1, scaledInput.length],
    );
    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, {_inputName: input});

    try {
      if (outputs.isEmpty) return null;
      for (final output in outputs) {
        final value = output?.value;
        final parsed = _extractNumeric(value);
        if (parsed != null && parsed.isFinite) {
          return parsed;
        }
      }
      return null;
    } finally {
      input.release();
      runOptions.release();
      for (final value in outputs) {
        value?.release();
      }
    }
  }

  double? _extractNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is Float32List && value.isNotEmpty) return value.first.toDouble();
    if (value is Float64List && value.isNotEmpty) return value.first.toDouble();
    if (value is Int32List && value.isNotEmpty) return value.first.toDouble();
    if (value is Int64List && value.isNotEmpty) return value.first.toDouble();
    if (value is List && value.isNotEmpty) return _extractNumeric(value.first);
    if (value is Map && value.isNotEmpty) {
      return _extractNumeric(value.values.first);
    }
    return null;
  }

  _DataCheckResult _validateDataRequirements({
    required List<HealthMetricSample> samples,
    required DateTime nowUtc,
  }) {
    if (samples.isEmpty) {
      return const _DataCheckResult(false, 'no_samples', 0);
    }

    final recentSamples = _resolveRecentSamples(
      samples: samples,
      nowUtc: nowUtc,
    );
    if (recentSamples.isEmpty) {
      return const _DataCheckResult(false, 'no_recent_samples', 0);
    }

    final recentTypes = recentSamples.map((sample) => sample.type).toSet();
    for (final type in _requiredMetricTypes) {
      if (!_isRequiredTypeSatisfied(type, recentTypes)) {
        return _DataCheckResult(false, 'missing_required_${type.name}', 0);
      }
    }

    final nights = _buildNightlyFeatures(recentSamples);
    if (nights.length < _minimumNightsForInference) {
      return _DataCheckResult(false, 'not_enough_nights', nights.length);
    }

    final firstStart = nights.first.startUtc;
    final lastEnd = nights.last.endUtc;
    final historyDays = max(
      0,
      (lastEnd.difference(firstStart).inMinutes / 1440.0).ceil(),
    );
    if (historyDays < _minimumHistoryDays) {
      return _DataCheckResult(false, 'history_too_short', nights.length);
    }

    return _DataCheckResult(true, 'ok', nights.length);
  }

  double _estimateConfidence({
    required List<HealthMetricSample> samples,
    required List<_NightFeatureRow> nights,
    required DateTime nowUtc,
  }) {
    final recent = _resolveRecentSamples(samples: samples, nowUtc: nowUtc);
    final recentTypes = recent.map((item) => item.type).toSet();

    final requiredHit = _requiredMetricTypes
        .where((item) => _isRequiredTypeSatisfied(item, recentTypes))
        .length;
    final optionalHit = _optionalMetricTypes
        .where((item) => recentTypes.contains(item))
        .length;

    final requiredCoverage = requiredHit / max(_requiredMetricTypes.length, 1);
    final optionalCoverage = optionalHit / max(_optionalMetricTypes.length, 1);
    final nightsFactor =
        (nights.length / max(_minimumNightsForInference * 2, 1)).clamp(
          0.0,
          1.0,
        );
    final latestCoverageHours = (nights.last.features['coverage_hours'] ?? 0)
        .clamp(0.0, 10.0);
    final coverageFactor = (latestCoverageHours / 6.0).clamp(0.0, 1.0);

    final confidence =
        (0.32 * requiredCoverage) +
        (0.18 * optionalCoverage) +
        (0.25 * nightsFactor) +
        (0.15 * coverageFactor) +
        (0.10 * _latestNightModalityFactor(nights.last));
    return confidence.clamp(0.0, 0.98);
  }

  List<HealthMetricSample> _resolveRecentSamples({
    required List<HealthMetricSample> samples,
    required DateTime nowUtc,
  }) {
    final horizonStart = nowUtc.subtract(Duration(days: _minimumHistoryDays));
    return samples
        .where((sample) => !sample.timestamp.toUtc().isBefore(horizonStart))
        .toList(growable: false);
  }

  SleepNightDiagnostics _buildNightDiagnostics(_NightFeatureRow row) {
    final sleepMinutes = (row.features['sleep_asleep_minutes'] ?? 0).clamp(
      0.0,
      24 * 60.0,
    );
    final inBedMinutes = (row.features['sleep_in_bed_minutes'] ?? 0).clamp(
      0.0,
      24 * 60.0,
    );
    final sleepEfficiency = inBedMinutes > 0
        ? (sleepMinutes / inBedMinutes) * 100.0
        : 0.0;

    return SleepNightDiagnostics(
      startUtc: row.startUtc,
      endUtc: row.endUtc,
      sleepMinutes: sleepMinutes,
      inBedMinutes: inBedMinutes,
      sleepEfficiencyPct: sleepEfficiency.clamp(0.0, 100.0),
      asleepHour: (row.features['asleep_hour'] ?? 0).clamp(0.0, 24.0),
      wakeupHour: (row.features['wakeup_hour'] ?? 0).clamp(0.0, 24.0),
      coverageHours: (row.features['coverage_hours'] ?? 0).clamp(0.0, 24.0),
      windowCount: (row.features['window_count'] ?? 0).clamp(0.0, 20000.0),
      hrMean: _finiteOrNull(row.features['HR_mean']),
      hrStd: _finiteOrNull(row.features['HR_std']),
      hrMin: _finiteOrNull(row.features['HR_min']),
      hrMax: _finiteOrNull(row.features['HR_max']),
      rmssdMean: _finiteOrNull(row.features['rmssd_mean']),
      sdnnMean: _finiteOrNull(row.features['sdnn_mean']),
      stepsMean: _finiteOrNull(row.features['steps_mean']),
      distanceMean: _finiteOrNull(row.features['distance_mean']),
      caloriesMean: _finiteOrNull(row.features['calories_mean']),
      missingOptionalModalities: _resolveMissingOptionalModalities(
        row.features,
      ),
    );
  }

  double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite) return null;
    return value;
  }

  bool _isRequiredTypeSatisfied(
    HealthMetricType requiredType,
    Set<HealthMetricType> recentTypes,
  ) {
    if (requiredType == HealthMetricType.sleepAsleep) {
      return _hasSleepAsleepEquivalent(recentTypes);
    }
    return recentTypes.contains(requiredType);
  }

  bool _hasSleepAsleepEquivalent(Set<HealthMetricType> recentTypes) {
    if (recentTypes.contains(HealthMetricType.sleepAsleep)) {
      return true;
    }
    final proxyTypes = {
      HealthMetricType.sleepSession,
      HealthMetricType.sleepInBed,
      HealthMetricType.sleepDeep,
      HealthMetricType.sleepLight,
      HealthMetricType.sleepRem,
    };
    return recentTypes.any(proxyTypes.contains);
  }

  List<_NightFeatureRow> _buildNightlyFeatures(
    List<HealthMetricSample> samples,
  ) {
    final sleepSamples = samples
        .where((item) => _sleepTypes.contains(item.type) && item.value.isFinite)
        .toList(growable: false);
    if (sleepSamples.isEmpty) return const [];

    final grouped = <DateTime, List<_SleepSegment>>{};
    for (final sample in sleepSamples) {
      final segment = _segmentFromSample(sample);
      if (segment == null) continue;
      final night = _nightKey(segment.startUtc.toLocal());
      grouped.putIfAbsent(night, () => <_SleepSegment>[]).add(segment);
    }

    if (grouped.isEmpty) return const [];

    final candidates =
        grouped.entries
            .map((entry) => _buildNightRow(entry.key, entry.value, samples))
            .whereType<_NightFeatureRow>()
            .toList(growable: false)
          ..sort((a, b) => a.nightDate.compareTo(b.nightDate));

    if (candidates.isEmpty) return const [];
    _augmentBaseline(candidates);
    return candidates;
  }

  _NightFeatureRow? _buildNightRow(
    DateTime nightDate,
    List<_SleepSegment> segments,
    List<HealthMetricSample> allSamples,
  ) {
    if (segments.isEmpty) return null;
    segments.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final startUtc = segments.first.startUtc;
    final endUtc = segments
        .map((item) => item.endUtc)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (!endUtc.isAfter(startUtc)) return null;

    final windowMinutes = max(
      1.0,
      endUtc.difference(startUtc).inMinutes.toDouble(),
    );
    final asleepMinutes = segments
        .where((item) => item.type == HealthMetricType.sleepAsleep)
        .fold<double>(0, (sum, item) => sum + item.durationMinutes);
    final sessionMinutes = segments
        .where((item) => item.type == HealthMetricType.sleepSession)
        .fold<double>(0, (sum, item) => sum + item.durationMinutes);
    final deepLightRemMinutes = segments
        .where(
          (item) =>
              item.type == HealthMetricType.sleepDeep ||
              item.type == HealthMetricType.sleepLight ||
              item.type == HealthMetricType.sleepRem,
        )
        .fold<double>(0, (sum, item) => sum + item.durationMinutes);

    final resolvedAsleep = asleepMinutes > 0
        ? asleepMinutes
        : (sessionMinutes > 0 ? sessionMinutes : deepLightRemMinutes);
    if (resolvedAsleep <= 0) return null;

    final inBedMinutes = segments
        .where((item) => item.type == HealthMetricType.sleepInBed)
        .fold<double>(0, (sum, item) => sum + item.durationMinutes);
    final awakeMinutes = segments
        .where(
          (item) =>
              item.type == HealthMetricType.sleepAwake ||
              item.type == HealthMetricType.sleepAwakeInBed,
        )
        .fold<double>(0, (sum, item) => sum + item.durationMinutes);
    final resolvedInBed = max(
      windowMinutes,
      inBedMinutes > 0
          ? inBedMinutes
          : (sessionMinutes > 0
                ? sessionMinutes
                : (resolvedAsleep + awakeMinutes)),
    );

    final windowSamples = allSamples
        .where((sample) {
          final ts = sample.timestamp.toUtc();
          return !ts.isBefore(startUtc) && !ts.isAfter(endUtc);
        })
        .toList(growable: false);

    final hrValues = _valuesFor(windowSamples, const [
      HealthMetricType.heartRate,
      HealthMetricType.walkingHeartRate,
    ]);
    final hrTimes = _timestampsFor(windowSamples, const [
      HealthMetricType.heartRate,
      HealthMetricType.walkingHeartRate,
    ]);
    final stepsValues = _valuesFor(windowSamples, const [
      HealthMetricType.steps,
    ]);
    final distanceValues = _valuesFor(windowSamples, const [
      HealthMetricType.distanceWalkingRunning,
      HealthMetricType.distanceDelta,
    ]);
    final caloriesValues = _valuesFor(windowSamples, const [
      HealthMetricType.activeEnergyBurned,
      HealthMetricType.totalCaloriesBurned,
    ]);
    final sdnnValues = _valuesFor(windowSamples, const [
      HealthMetricType.heartRateVariabilitySdnn,
    ]);
    final rmssdValues = _valuesFor(windowSamples, const [
      HealthMetricType.heartRateVariabilityRmssd,
    ]);

    final feature = <String, double>{};
    _putStats(feature, 'HR', hrValues);
    _putStats(feature, 'steps', stepsValues);
    _putStats(feature, 'distance', distanceValues);
    _putStats(feature, 'calories', caloriesValues);
    _putStats(feature, 'sdnn', sdnnValues);
    _putStats(feature, 'rmssd', rmssdValues);
    _setModalityMissingFlags(
      feature,
      hrPresent: hrValues.isNotEmpty,
      stepsPresent: stepsValues.isNotEmpty,
      distancePresent: distanceValues.isNotEmpty,
      caloriesPresent: caloriesValues.isNotEmpty,
      sdnnPresent: sdnnValues.isNotEmpty,
      rmssdPresent: rmssdValues.isNotEmpty,
    );

    final hrCount = hrValues.length;
    final coverageHours = _coverageHoursFromTimestamps(hrTimes);
    feature['window_count'] = hrCount.toDouble();
    feature['coverage_hours'] = coverageHours;
    feature['window_density'] = hrCount / windowMinutes;
    feature['sleep_window_hours_clock'] = windowMinutes / 60.0;

    final startLocal = startUtc.toLocal();
    final endLocal = endUtc.toLocal();
    feature['asleep_hour'] = _hourFraction(startLocal);
    feature['wakeup_hour'] = _hourFraction(endLocal);
    feature['weekday'] = (startLocal.weekday - 1).toDouble();
    feature['hr_trend'] = _trendSlope(hrValues, hrTimes);
    _addEngineeredHealthFeatures(feature);

    // keep explicit values for diagnostics/fallback usage
    feature['sleep_asleep_minutes'] = resolvedAsleep;
    feature['sleep_in_bed_minutes'] = resolvedInBed;

    return _NightFeatureRow(
      nightDate: nightDate,
      startUtc: startUtc,
      endUtc: endUtc,
      features: feature,
    );
  }

  void _augmentBaseline(List<_NightFeatureRow> nights) {
    const baselineCols = [
      'HR_mean',
      'rmssd_mean',
      'sdnn_mean',
      'steps_mean',
      'distance_mean',
      'calories_mean',
      'window_count',
      'coverage_hours',
      'asleep_hour',
      'wakeup_hour',
    ];

    final history = <String, List<double>>{
      for (final col in baselineCols) col: <double>[],
    };

    for (var i = 0; i < nights.length; i++) {
      final row = nights[i];
      row.features['nights_since_start'] = i.toDouble();

      for (final col in baselineCols) {
        final past = history[col]!;
        final window = past.length <= 7 ? past : past.sublist(past.length - 7);
        if (window.length >= min(3, _minimumNightsForBaseline)) {
          final mean = _avg(window);
          final std = _stddev(window);
          final current = row.features[col] ?? double.nan;
          row.features['${col}_baseline7'] = mean;
          row.features['${col}_delta7'] = current.isFinite
              ? current - mean
              : double.nan;
          row.features['${col}_z7'] = current.isFinite
              ? (current - mean) / (std + 1e-6)
              : double.nan;
        } else {
          row.features['${col}_baseline7'] = double.nan;
          row.features['${col}_delta7'] = double.nan;
          row.features['${col}_z7'] = double.nan;
        }
      }

      for (final col in baselineCols) {
        final value = row.features[col];
        if (value != null && value.isFinite) {
          history[col]!.add(value);
        }
      }
    }
  }

  _SleepSegment? _segmentFromSample(HealthMetricSample sample) {
    final explicitStart = sample.intervalStart?.toUtc();
    final explicitEnd = sample.intervalEnd?.toUtc();
    if (explicitStart != null &&
        explicitEnd != null &&
        explicitEnd.isAfter(explicitStart)) {
      final durationMinutes =
          explicitEnd.difference(explicitStart).inMilliseconds / 60000.0;
      if (!durationMinutes.isFinite || durationMinutes <= 0) return null;
      return _SleepSegment(
        type: sample.type,
        startUtc: explicitStart,
        endUtc: explicitEnd,
        durationMinutes: durationMinutes,
      );
    }

    final minutes = sample.value;
    if (!minutes.isFinite || minutes <= 0) return null;
    final endUtc = sample.endAt;
    final durationMs = (minutes * 60 * 1000).round();
    final startUtc = endUtc.subtract(Duration(milliseconds: durationMs));
    return _SleepSegment(
      type: sample.type,
      startUtc: startUtc,
      endUtc: endUtc,
      durationMinutes: minutes,
    );
  }

  DateTime _nightKey(DateTime localStart) {
    final shifted = localStart.hour < 12
        ? localStart.subtract(const Duration(days: 1))
        : localStart;
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  List<double> _valuesFor(
    List<HealthMetricSample> samples,
    List<HealthMetricType> types,
  ) {
    final typeSet = types.toSet();
    return samples
        .where((item) => typeSet.contains(item.type))
        .map((item) => item.value)
        .where((value) => value.isFinite)
        .toList(growable: false);
  }

  List<DateTime> _timestampsFor(
    List<HealthMetricSample> samples,
    List<HealthMetricType> types,
  ) {
    final typeSet = types.toSet();
    return samples
        .where((item) => typeSet.contains(item.type))
        .map((item) => item.timestamp.toUtc())
        .toList(growable: false)
      ..sort();
  }

  void _putStats(
    Map<String, double> target,
    String prefix,
    List<double> values,
  ) {
    if (values.isEmpty) {
      target['${prefix}_mean'] = double.nan;
      target['${prefix}_std'] = double.nan;
      target['${prefix}_min'] = double.nan;
      target['${prefix}_max'] = double.nan;
      target['${prefix}_p10'] = double.nan;
      target['${prefix}_p90'] = double.nan;
      return;
    }
    final sorted = List<double>.from(values)..sort();
    final mean = _avg(sorted);
    final std = _stddev(sorted);
    target['${prefix}_mean'] = mean;
    target['${prefix}_std'] = std;
    target['${prefix}_min'] = sorted.first;
    target['${prefix}_max'] = sorted.last;
    target['${prefix}_p10'] = _percentile(sorted, 0.10);
    target['${prefix}_p90'] = _percentile(sorted, 0.90);
  }

  void _setModalityMissingFlags(
    Map<String, double> feature, {
    required bool hrPresent,
    required bool stepsPresent,
    required bool distancePresent,
    required bool caloriesPresent,
    required bool sdnnPresent,
    required bool rmssdPresent,
  }) {
    feature['hr_missing'] = hrPresent ? 0.0 : 1.0;
    feature['steps_missing'] = stepsPresent ? 0.0 : 1.0;
    feature['distance_missing'] = distancePresent ? 0.0 : 1.0;
    feature['calories_missing'] = caloriesPresent ? 0.0 : 1.0;
    feature['sdnn_missing'] = sdnnPresent ? 0.0 : 1.0;
    feature['rmssd_missing'] = rmssdPresent ? 0.0 : 1.0;
  }

  void _addEngineeredHealthFeatures(Map<String, double> feature) {
    final asleepHour = feature['asleep_hour'];
    final wakeupHour = feature['wakeup_hour'];
    final weekday = feature['weekday'];
    final coverageHours = feature['coverage_hours'];
    final windowCount = feature['window_count'];
    final sleepWindowHours = feature['sleep_window_hours_clock'];
    final hrMean = feature['HR_mean'];
    final rmssdMean = feature['rmssd_mean'];
    final sdnnMean = feature['sdnn_mean'];
    final stepsMean = feature['steps_mean'];

    feature['asleep_hour_sin'] = _cyclicSin(asleepHour, 24.0);
    feature['asleep_hour_cos'] = _cyclicCos(asleepHour, 24.0);
    feature['wakeup_hour_sin'] = _cyclicSin(wakeupHour, 24.0);
    feature['wakeup_hour_cos'] = _cyclicCos(wakeupHour, 24.0);
    feature['weekday_sin'] = _cyclicSin(weekday, 7.0);
    feature['weekday_cos'] = _cyclicCos(weekday, 7.0);

    feature['coverage_hours_log1p'] = _safeLog1pNonNegative(coverageHours);
    feature['window_count_log1p'] = _safeLog1pNonNegative(windowCount);
    feature['sleep_window_hours_log1p'] = _safeLog1pNonNegative(
      sleepWindowHours,
    );

    feature['hr_rmssd_interaction'] = _safeInteraction(hrMean, rmssdMean);
    feature['hr_sdnn_interaction'] = _safeInteraction(hrMean, sdnnMean);
    feature['steps_coverage_interaction'] = _safeStepsCoverage(
      stepsMean,
      coverageHours,
    );

    if (asleepHour == null ||
        !asleepHour.isFinite ||
        wakeupHour == null ||
        !wakeupHour.isFinite) {
      feature['sleep_phase_span_abs'] = double.nan;
      feature['sleep_phase_span_wrap'] = double.nan;
      return;
    }
    final spanAbs = (wakeupHour - asleepHour).abs();
    feature['sleep_phase_span_abs'] = spanAbs;
    feature['sleep_phase_span_wrap'] = max(0.0, 24.0 - spanAbs);
  }

  double _cyclicSin(double? value, double period) {
    if (value == null || !value.isFinite || period <= 0) {
      return double.nan;
    }
    return sin((2 * pi * value) / period);
  }

  double _cyclicCos(double? value, double period) {
    if (value == null || !value.isFinite || period <= 0) {
      return double.nan;
    }
    return cos((2 * pi * value) / period);
  }

  double _safeLog1pNonNegative(double? value) {
    if (value == null || !value.isFinite) {
      return double.nan;
    }
    return log(max(value, 0.0) + 1.0);
  }

  double _safeInteraction(double? a, double? b) {
    if (a == null || !a.isFinite || b == null || !b.isFinite) {
      return double.nan;
    }
    return a * b;
  }

  double _safeStepsCoverage(double? stepsMean, double? coverageHours) {
    if (stepsMean == null ||
        !stepsMean.isFinite ||
        coverageHours == null ||
        !coverageHours.isFinite) {
      return double.nan;
    }
    return sqrt(max(stepsMean, 0.0)) * max(coverageHours, 0.0);
  }

  List<String> _resolveMissingOptionalModalities(Map<String, double> feature) {
    const mapping = {
      'distance_missing': 'distance',
      'calories_missing': 'calories',
      'sdnn_missing': 'sdnn',
      'rmssd_missing': 'rmssd',
    };
    final missing = <String>[];
    mapping.forEach((key, label) {
      final value = feature[key];
      if (value != null && value.isFinite && value >= 0.5) {
        missing.add(label);
      }
    });
    return List.unmodifiable(missing);
  }

  double _latestNightModalityFactor(_NightFeatureRow row) {
    const keys = [
      'distance_missing',
      'calories_missing',
      'sdnn_missing',
      'rmssd_missing',
    ];
    var present = 0;
    for (final key in keys) {
      final value = row.features[key];
      if (value != null && value.isFinite && value < 0.5) {
        present += 1;
      }
    }
    return present / keys.length;
  }

  List<double> _imputeAndScale(List<double> rawValues) {
    final output = List<double>.filled(rawValues.length, 0.0);
    for (var i = 0; i < rawValues.length; i++) {
      final raw = rawValues[i];
      final imputed = raw.isFinite ? raw : _medianAt(i);
      final clipped = _clipToBounds(
        imputed,
        low: _clipLowAt(i),
        high: _clipHighAt(i),
      );
      final mean = _meanAt(i);
      final std = _stdAt(i);
      output[i] = (clipped - mean) / (std == 0 ? 1.0 : std);
    }
    return output;
  }

  double _medianAt(int index) => index < _median.length ? _median[index] : 0.0;
  double _clipLowAt(int index) =>
      index < _clipLow.length ? _clipLow[index] : double.negativeInfinity;
  double _clipHighAt(int index) =>
      index < _clipHigh.length ? _clipHigh[index] : double.infinity;
  double _meanAt(int index) => index < _mean.length ? _mean[index] : 0.0;
  double _stdAt(int index) => index < _std.length ? _std[index] : 1.0;

  double _clipToBounds(
    double value, {
    required double low,
    required double high,
  }) {
    final lo = low.isFinite ? low : double.negativeInfinity;
    final hi = high.isFinite ? high : double.infinity;
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
  }

  double _restoreModelOutput(double rawValue) {
    if (_selectedModel.toLowerCase() != 'mlp') {
      return rawValue;
    }
    final restored = (rawValue * _mlpTargetStd) + _mlpTargetMean;
    return restored.isFinite ? restored : rawValue;
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<HealthMetricType> _parseMetricList(
    List<dynamic>? raw,
    List<HealthMetricType> fallback,
  ) {
    if (raw == null || raw.isEmpty) return fallback;
    final parsed = raw
        .map((item) => HealthMetricTypeX.fromKey(item.toString()))
        .where((type) => type != HealthMetricType.unknown)
        .toList(growable: false);
    return parsed.isEmpty ? fallback : parsed;
  }

  double _hourFraction(DateTime dt) {
    return dt.hour + (dt.minute / 60.0) + (dt.second / 3600.0);
  }

  double _coverageHoursFromTimestamps(List<DateTime> timestamps) {
    if (timestamps.length < 2) return 0.0;
    final span = timestamps.last.difference(timestamps.first).inMinutes / 60.0;
    return span.isFinite && span > 0 ? span : 0.0;
  }

  double _trendSlope(List<double> values, List<DateTime> times) {
    if (values.length < 3 ||
        times.length < 3 ||
        values.length != times.length) {
      return 0.0;
    }

    final xs = times
        .map((item) => item.millisecondsSinceEpoch / 1000.0)
        .toList(growable: false);
    final ys = List<double>.from(values);
    final xMean = _avg(xs);
    final yMean = _avg(ys);

    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < xs.length; i++) {
      final dx = xs[i] - xMean;
      final dy = ys[i] - yMean;
      num += dx * dy;
      den += dx * dx;
    }
    if (den.abs() < 1e-9) return 0.0;
    return num / den;
  }

  double _avg(List<double> values) {
    if (values.isEmpty) return 0.0;
    final total = values.fold<double>(0.0, (sum, item) => sum + item);
    return total / values.length;
  }

  double _stddev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = _avg(values);
    final variance =
        values
            .map((item) => (item - mean) * (item - mean))
            .fold<double>(0.0, (sum, item) => sum + item) /
        values.length;
    return sqrt(max(variance, 0.0));
  }

  double _percentile(List<double> sortedValues, double p) {
    if (sortedValues.isEmpty) return 0.0;
    if (sortedValues.length == 1) return sortedValues.first;
    final rank = (sortedValues.length - 1) * p.clamp(0.0, 1.0);
    final low = rank.floor();
    final high = rank.ceil();
    if (low == high) return sortedValues[low];
    final weight = rank - low;
    return (sortedValues[low] * (1 - weight)) + (sortedValues[high] * weight);
  }

  Set<HealthMetricType> get _sleepTypes => const {
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepInBed,
    HealthMetricType.sleepSession,
    HealthMetricType.sleepAwake,
    HealthMetricType.sleepAwakeInBed,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepRem,
  };

  Set<HealthMetricType> get _trackedTypes => {
    ..._sleepTypes,
    HealthMetricType.heartRate,
    HealthMetricType.walkingHeartRate,
    HealthMetricType.restingHeartRate,
    HealthMetricType.heartRateVariabilitySdnn,
    HealthMetricType.heartRateVariabilityRmssd,
    HealthMetricType.steps,
    HealthMetricType.distanceWalkingRunning,
    HealthMetricType.distanceDelta,
    HealthMetricType.activeEnergyBurned,
    HealthMetricType.totalCaloriesBurned,
  };
}

class _SleepSegment {
  final HealthMetricType type;
  final DateTime startUtc;
  final DateTime endUtc;
  final double durationMinutes;

  const _SleepSegment({
    required this.type,
    required this.startUtc,
    required this.endUtc,
    required this.durationMinutes,
  });
}

class _NightFeatureRow {
  final DateTime nightDate;
  final DateTime startUtc;
  final DateTime endUtc;
  final Map<String, double> features;

  const _NightFeatureRow({
    required this.nightDate,
    required this.startUtc,
    required this.endUtc,
    required this.features,
  });
}

class _DataCheckResult {
  final bool ok;
  final String reason;
  final int nights;

  const _DataCheckResult(this.ok, this.reason, this.nights);
}
