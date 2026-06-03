import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/perf/perf_probe.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';

const String kHarvardModelAssetPath =
    'assets/models/harvard_aw/model_harvardAWData_xgboost.onnx';
const String kHarvardPreprocessorV2AssetPath =
    'assets/models/harvard_aw/preprocessor_v2.json';
const String kHarvardPreprocessorV1AssetPath =
    'assets/models/harvard_aw/preprocessor_v1.json';
const String kHarvardMetadataAssetPath =
    'assets/models/harvard_aw/model_metadata.json';
const String kHarvardDefaultModelVersion = 'harvard-aw-xgb-v1';
const String kHarvardModelVersionV2 = 'harvard-aw-xgb-v2';

class HarvardPreprocessorLoadResult {
  final Map<String, dynamic> payload;
  final String sourcePath;

  const HarvardPreprocessorLoadResult({
    required this.payload,
    required this.sourcePath,
  });
}

class HarvardPreprocessorManifest {
  final String version;
  final List<double> mean;
  final List<double> std;
  final List<String> featureNames;
  final Map<String, int> targetMapping;
  final Map<int, String> inverseTargetMapping;

  const HarvardPreprocessorManifest({
    required this.version,
    required this.mean,
    required this.std,
    required this.featureNames,
    required this.targetMapping,
    required this.inverseTargetMapping,
  });
}

Future<HarvardPreprocessorLoadResult> loadHarvardPreprocessorPayload({
  required AssetBundle assetBundle,
  String preprocessorV2AssetPath = kHarvardPreprocessorV2AssetPath,
  String preprocessorV1AssetPath = kHarvardPreprocessorV1AssetPath,
}) async {
  try {
    final rawV2 = await assetBundle.loadString(preprocessorV2AssetPath);
    return HarvardPreprocessorLoadResult(
      payload: _decodeJsonMap(rawV2, preprocessorV2AssetPath),
      sourcePath: preprocessorV2AssetPath,
    );
  } catch (error) {
    if (!_isMissingAssetError(error)) {
      rethrow;
    }
  }

  final rawV1 = await assetBundle.loadString(preprocessorV1AssetPath);
  return HarvardPreprocessorLoadResult(
    payload: _decodeJsonMap(rawV1, preprocessorV1AssetPath),
    sourcePath: preprocessorV1AssetPath,
  );
}

Future<String> loadHarvardModelVersion({
  required AssetBundle assetBundle,
  String metadataAssetPath = kHarvardMetadataAssetPath,
}) async {
  try {
    final metadataRaw = await assetBundle.loadString(metadataAssetPath);
    final payload = _decodeJsonMap(metadataRaw, metadataAssetPath);
    final version = payload['model_version']?.toString().trim();
    if (version == null || version.isEmpty) {
      return kHarvardDefaultModelVersion;
    }
    return version;
  } catch (_) {
    return kHarvardDefaultModelVersion;
  }
}

HarvardPreprocessorManifest parseHarvardPreprocessorManifest(
  Map<String, dynamic> payload,
) {
  final version = payload['version']?.toString() ?? 'preprocessor_v1';
  final scalerRaw = payload['scaler'];
  dynamic meanRaw;
  dynamic stdRaw;
  if (scalerRaw is Map<String, dynamic>) {
    meanRaw = scalerRaw['mean'];
    stdRaw = scalerRaw['std'];
  } else if (scalerRaw is Map) {
    meanRaw = scalerRaw['mean'];
    stdRaw = scalerRaw['std'];
  }
  meanRaw ??= payload['mean'];
  stdRaw ??= payload['std'];

  final mean = _readDoubleList(meanRaw, fieldName: 'mean');
  final std = _readDoubleList(stdRaw, fieldName: 'std');
  final featureNames = _readStringList(
    payload['feature_names'],
    fieldName: 'feature_names',
  );
  if (featureNames.length != mean.length || featureNames.length != std.length) {
    throw const FormatException(
      'Harvard preprocessor manifest has mismatched feature/scaler lengths.',
    );
  }

  final targetMapping = _parseTargetMapping(payload['target_mapping']);
  var inverseTargetMapping = _parseInverseTargetMapping(
    payload['inverse_target_mapping'],
  );
  if (inverseTargetMapping.isEmpty && targetMapping.isNotEmpty) {
    inverseTargetMapping = targetMapping.map(
      (label, id) => MapEntry(id, label),
    );
  }

  return HarvardPreprocessorManifest(
    version: version,
    mean: mean,
    std: std,
    featureNames: featureNames,
    targetMapping: targetMapping,
    inverseTargetMapping: inverseTargetMapping,
  );
}

Map<String, dynamic> _decodeJsonMap(String raw, String sourcePath) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Expected JSON object at $sourcePath');
  }
  return decoded;
}

List<double> _readDoubleList(dynamic value, {required String fieldName}) {
  if (value is! List) {
    throw FormatException('Expected "$fieldName" to be a list.');
  }
  return value
      .map((item) {
        if (item is num) {
          return item.toDouble();
        }
        final parsed = double.tryParse(item.toString());
        if (parsed == null) {
          throw FormatException(
            'Expected numeric value in "$fieldName", got: $item',
          );
        }
        return parsed;
      })
      .toList(growable: false);
}

List<String> _readStringList(dynamic value, {required String fieldName}) {
  if (value is! List) {
    throw FormatException('Expected "$fieldName" to be a list.');
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, int> _parseTargetMapping(dynamic value) {
  if (value is! Map) {
    return const <String, int>{};
  }
  final mapping = <String, int>{};
  for (final entry in value.entries) {
    final parsed = (entry.value is num)
        ? (entry.value as num).toInt()
        : int.tryParse(entry.value.toString());
    if (parsed == null || parsed < 0) {
      continue;
    }
    mapping[entry.key.toString()] = parsed;
  }
  return mapping;
}

Map<int, String> _parseInverseTargetMapping(dynamic value) {
  if (value is! Map) {
    return const <int, String>{};
  }
  final mapping = <int, String>{};
  for (final entry in value.entries) {
    final parsedKey = (entry.key is num)
        ? (entry.key as num).toInt()
        : int.tryParse(entry.key.toString());
    if (parsedKey == null || parsedKey < 0) {
      continue;
    }
    mapping[parsedKey] = entry.value.toString();
  }
  return mapping;
}

bool _isMissingAssetError(Object error) {
  final message = error.toString();
  return message.contains('Unable to load asset');
}

enum HarvardActivityClass {
  insufficientData,
  lying,
  sitting,
  selfPaceWalk,
  running3Met,
  running5Met,
  running7Met,
}

class HarvardActivityRecommendationResult {
  final HarvardActivityClass activityClass;
  final double confidence;
  final List<String> recommendationKeys;
  final String modelVersion;

  const HarvardActivityRecommendationResult({
    required this.activityClass,
    required this.confidence,
    required this.recommendationKeys,
    required this.modelVersion,
  });
}

/// Real notebook-backed inference:
/// - ONNX model: assets/models/harvard_aw/model_harvardAWData_xgboost.onnx
/// - Preprocessor: v2 (fallback to v1 for backward compatibility)
///
/// If assets are unavailable, data is insufficient, or inference fails, the
/// service returns explicit insufficient-data state.
class HarvardActivityRecommendationModel {
  static const int _windowDays = 30;

  bool _initialized = false;
  bool _initFailed = false;
  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  String _inputName = 'float_input';
  String _modelVersion = kHarvardDefaultModelVersion;

  List<double> _mean = const [];
  List<double> _std = const [];
  List<String> _featureNames = const [];
  Map<String, int> _targetMapping = const {};
  Map<int, String> _inverseTargetMapping = const {};
  final _logger = AppLogger.instance;

  Future<HarvardActivityRecommendationResult> infer({
    required OnboardingProfileSnapshot profile,
    required List<HealthMetricSample> samples,
    DateTime? now,
  }) async {
    return PerfProbe.measureAsync(
      'model.harvard.infer',
      () async {
        final current = (now ?? DateTime.now()).toUtc();
        final stats = _buildStats(samples: samples, now: current);
        _logger.info(
          'model.harvard',
          'Starting recommendation inference',
          payload: {
            'samplesTotal': samples.length,
            'windowDays': _windowDays,
            'profile': {
              'age': profile.age,
              'sex': profile.sex,
              'heightCm': profile.heightCm,
              'weightKg': profile.weightKg,
            },
            'stats': {
              'availableSignals': stats.availableSignals,
              'stepsLatest': stats.stepsLatest,
              'heartLatest': stats.heartLatest,
              'caloriesLatest': stats.caloriesLatest,
              'distanceLatest': stats.distanceLatest,
              'restingLatest': stats.restingLatest,
              'heartDays': stats.heartSeries.length,
              'stepsDays': stats.stepsSeries.length,
            },
          },
        );

        if (stats.availableSignals < 2) {
          return _insufficientResult(
            reason: 'not_enough_signals',
            payload: {'availableSignals': stats.availableSignals},
          );
        }

        await _ensureInitialized();

        if (_initFailed ||
            _session == null ||
            _featureNames.isEmpty ||
            _featureNames.length != _mean.length ||
            _featureNames.length != _std.length) {
          return _insufficientResult(
            reason: 'model_not_ready',
            payload: {
              'initFailed': _initFailed,
              'sessionNull': _session == null,
              'featureNames': _featureNames.length,
              'mean': _mean.length,
              'std': _std.length,
            },
          );
        }

        try {
          final rawVector = _buildNotebookFeatureVector(profile, stats);
          final scaled = _scale(rawVector);
          _logger.debug(
            'model.harvard',
            'Feature vector prepared',
            payload: {
              'inputName': _inputName,
              'featureCount': rawVector.length,
              'firstFeatures': _featureNames.take(6).toList(growable: false),
              'firstValues': rawVector.take(6).toList(growable: false),
            },
          );
          final classId = await _runOnnx(scaled);
          if (classId == null) {
            return _insufficientResult(reason: 'onnx_output_unrecognized');
          }
          final label = _inverseTargetMapping[classId];
          final activityClass = _mapLabelToClass(label);
          if (activityClass == HarvardActivityClass.insufficientData) {
            return _insufficientResult(
              reason: 'class_mapping_failed',
              payload: {'classId': classId, 'label': label},
            );
          }
          _logger.info(
            'model.harvard',
            'Inference success',
            payload: {
              'classId': classId,
              'label': label,
              'activityClass': activityClass.name,
            },
          );
          return HarvardActivityRecommendationResult(
            activityClass: activityClass,
            confidence: _confidenceFromSignals(stats.availableSignals),
            recommendationKeys: _recommendationsForClass(activityClass),
            modelVersion: _modelVersion,
          );
        } catch (error, stackTrace) {
          _logger.error(
            'model.harvard',
            'Inference failed with exception',
            payload: {
              'error': error.toString(),
              'stackTrace': stackTrace.toString(),
            },
          );
          return _insufficientResult(reason: 'inference_exception');
        }
      },
      payload: <String, Object?>{'sample_count': samples.length},
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    var loadedPreprocessorPath = kHarvardPreprocessorV2AssetPath;
    try {
      OrtEnv.instance.init();

      final modelData = await rootBundle.load(kHarvardModelAssetPath);
      _sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(
        modelData.buffer.asUint8List(),
        _sessionOptions!,
      );
      if (_session!.inputNames.isNotEmpty) {
        _inputName = _session!.inputNames.first;
      }

      final preprocessor = await loadHarvardPreprocessorPayload(
        assetBundle: rootBundle,
      );
      loadedPreprocessorPath = preprocessor.sourcePath;
      final manifest = parseHarvardPreprocessorManifest(preprocessor.payload);

      _mean = manifest.mean;
      _std = manifest.std;
      _featureNames = manifest.featureNames;
      _targetMapping = manifest.targetMapping;
      _inverseTargetMapping = manifest.inverseTargetMapping;
      _modelVersion = await _resolveModelVersion(
        preprocessorVersion: manifest.version,
      );

      _logger.info(
        'model.harvard',
        'Model initialized',
        payload: {
          'inputName': _inputName,
          'outputNames': _session?.outputNames ?? const [],
          'featureCount': _featureNames.length,
          'targetClasses': _inverseTargetMapping.length,
          'preprocessorAssetPath': loadedPreprocessorPath,
          'modelVersion': _modelVersion,
        },
      );
    } catch (error, stackTrace) {
      _initFailed = true;
      _session = null;
      _logger.error(
        'model.harvard',
        'Model initialization failed',
        payload: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
          'modelAssetPath': kHarvardModelAssetPath,
          'preprocessorAssetPath': loadedPreprocessorPath,
        },
      );
    }
  }

  Future<String> _resolveModelVersion({
    required String preprocessorVersion,
  }) async {
    final metadataVersion = await loadHarvardModelVersion(
      assetBundle: rootBundle,
    );
    if (metadataVersion != kHarvardDefaultModelVersion) {
      return metadataVersion;
    }
    if (preprocessorVersion == 'harvard-preprocessor-v2') {
      return kHarvardModelVersionV2;
    }
    return metadataVersion;
  }

  Future<int?> _runOnnx(List<double> scaledInput) async {
    final session = _session;
    if (session == null) {
      return null;
    }

    final input = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(scaledInput),
      [1, scaledInput.length],
    );
    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, {_inputName: input});

    try {
      if (outputs.isEmpty) {
        _logger.warning('model.harvard', 'ONNX returned no outputs');
        return null;
      }
      _logger.debug(
        'model.harvard',
        'ONNX outputs received',
        payload: {
          'outputNames': session.outputNames,
          'outputsCount': outputs.length,
          'outputTypes': outputs
              .map((item) => item?.value.runtimeType.toString() ?? 'null')
              .toList(growable: false),
        },
      );

      // 1) Prefer explicit label outputs when available.
      final outputNames = session.outputNames;
      for (var index = 0; index < outputs.length; index++) {
        final output = outputs[index];
        if (output == null) {
          continue;
        }
        final outputName = index < outputNames.length
            ? outputNames[index].toLowerCase()
            : '';
        if (!outputName.contains('label')) {
          continue;
        }
        final classId = _extractClassId(output.value);
        if (classId != null) {
          _logger.debug(
            'model.harvard',
            'Class id extracted from label output',
            payload: {'outputName': outputName, 'classId': classId},
          );
          return classId;
        }
      }

      // 2) Try class id extraction from any output.
      for (final output in outputs) {
        if (output == null) {
          continue;
        }
        final classId = _extractClassId(output.value);
        if (classId != null) {
          _logger.debug(
            'model.harvard',
            'Class id extracted from output',
            payload: {'classId': classId},
          );
          return classId;
        }
      }

      // 3) Fallback: infer class from probability tensor/map.
      for (final output in outputs) {
        if (output == null) {
          continue;
        }
        final classId = _extractClassIdFromProbabilities(output.value);
        if (classId != null) {
          _logger.debug(
            'model.harvard',
            'Class id inferred from probabilities',
            payload: {'classId': classId},
          );
          return classId;
        }
      }
      _logger.warning(
        'model.harvard',
        'Unable to parse ONNX output into class id',
      );
      return null;
    } finally {
      input.release();
      runOptions.release();
      for (final value in outputs) {
        value?.release();
      }
    }
  }

  int? _extractClassId(dynamic value) {
    if (value is Int64List && value.isNotEmpty) {
      return value.first;
    }
    if (value is Int32List && value.isNotEmpty) {
      return value.first;
    }
    if (value is Uint8List && value.isNotEmpty) {
      return value.first;
    }
    if (value is String) {
      final byLabel = _targetMapping[value];
      if (byLabel != null) {
        return byLabel;
      }
      return int.tryParse(value);
    }
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is num) {
        return first.toInt();
      }
      if (first is String) {
        final byLabel = _targetMapping[first];
        if (byLabel != null) {
          return byLabel;
        }
        return int.tryParse(first);
      }
      if (first is List && first.isNotEmpty && first.first is num) {
        return (first.first as num).toInt();
      }
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  int? _extractClassIdFromProbabilities(dynamic value) {
    int? argMax(List<double> values) {
      if (values.isEmpty) {
        return null;
      }
      var bestIndex = 0;
      var bestValue = values.first;
      for (var i = 1; i < values.length; i++) {
        final current = values[i];
        if (current > bestValue) {
          bestValue = current;
          bestIndex = i;
        }
      }
      return bestIndex;
    }

    if (value is Float32List && value.isNotEmpty) {
      return argMax(value.toList(growable: false));
    }
    if (value is Float64List && value.isNotEmpty) {
      return argMax(value.toList(growable: false));
    }
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is num) {
        final scores = value
            .whereType<num>()
            .map((item) => item.toDouble())
            .toList(growable: false);
        if (scores.length == value.length) {
          return argMax(scores);
        }
      }
      if (first is List) {
        final inner = first
            .whereType<num>()
            .map((item) => item.toDouble())
            .toList(growable: false);
        if (inner.isNotEmpty) {
          return argMax(inner);
        }
      }
      if (first is Map) {
        final probabilities = first.entries
            .map((entry) {
              final key = entry.key;
              final classId = key is num
                  ? key.toInt()
                  : int.tryParse(key.toString());
              final probability = (entry.value is num)
                  ? (entry.value as num).toDouble()
                  : null;
              if (classId == null || probability == null) {
                return null;
              }
              return MapEntry(classId, probability);
            })
            .whereType<MapEntry<int, double>>()
            .toList(growable: false);
        if (probabilities.isNotEmpty) {
          probabilities.sort((a, b) => b.value.compareTo(a.value));
          return probabilities.first.key;
        }
      }
    }
    if (value is Map && value.isNotEmpty) {
      final probabilities = value.entries
          .map((entry) {
            final key = entry.key;
            final classId = key is num
                ? key.toInt()
                : int.tryParse(key.toString());
            final probability = (entry.value is num)
                ? (entry.value as num).toDouble()
                : null;
            if (classId == null || probability == null) {
              return null;
            }
            return MapEntry(classId, probability);
          })
          .whereType<MapEntry<int, double>>()
          .toList(growable: false);
      if (probabilities.isNotEmpty) {
        probabilities.sort((a, b) => b.value.compareTo(a.value));
        return probabilities.first.key;
      }
    }
    return null;
  }

  HarvardActivityClass _mapLabelToClass(String? label) {
    switch (label) {
      case 'Lying':
        return HarvardActivityClass.lying;
      case 'Sitting':
        return HarvardActivityClass.sitting;
      case 'Self Pace walk':
        return HarvardActivityClass.selfPaceWalk;
      case 'Running 3 METs':
        return HarvardActivityClass.running3Met;
      case 'Running 5 METs':
        return HarvardActivityClass.running5Met;
      case 'Running 7 METs':
        return HarvardActivityClass.running7Met;
      default:
        return HarvardActivityClass.insufficientData;
    }
  }

  List<double> _buildNotebookFeatureVector(
    OnboardingProfileSnapshot profile,
    _ModelStats stats,
  ) {
    final base = <String, double>{
      'age': (profile.age ?? 0).toDouble(),
      'gender': _mapSexToGender(profile.sex),
      'height': profile.heightCm ?? 0,
      'weight': profile.weightKg ?? 0,
      'Applewatch.Steps_LE': stats.stepsLatest,
      'Applewatch.Heart_LE': stats.heartLatest,
      'Applewatch.Calories_LE': stats.caloriesLatest,
      'Applewatch.Distance_LE': stats.distanceLatest,
      'EntropyApplewatchHeartPerDay_LE': stats.heartEntropy,
      'EntropyApplewatchStepsPerDay_LE': stats.stepsEntropy,
      'RestingApplewatchHeartrate_LE': stats.restingLatest,
    };

    final normalizedHeart =
        base['Applewatch.Heart_LE']! - base['RestingApplewatchHeartrate_LE']!;
    base['NormalizedApplewatchHeartrate_LE'] = normalizedHeart;

    final sdNormalized = _ewmStd(stats.normalizedHeartSeries, span: 3);
    base['SDNormalizedApplewatchHR_LE'] = sdNormalized;

    base['ApplewatchIntensity_LE'] = _calculateIntensity(
      normalizedHeart: normalizedHeart,
      steps: base['Applewatch.Steps_LE']!,
    );

    base['CorrelationApplewatchHeartrateSteps_LE'] = _rollingPearsonLast(
      stats.heartSeries,
      stats.stepsSeries,
      window: 30,
    );

    base['ApplewatchStepsXDistance_LE'] =
        base['Applewatch.Steps_LE']! * base['Applewatch.Distance_LE']!;

    return _featureNames
        .map((name) => base[name] ?? 0.0)
        .toList(growable: false);
  }

  List<double> _scale(List<double> values) {
    final out = List<double>.filled(values.length, 0);
    for (var i = 0; i < values.length; i++) {
      final std = _std[i] == 0 ? 1.0 : _std[i];
      out[i] = (values[i] - _mean[i]) / std;
    }
    return out;
  }

  double _mapSexToGender(String? sex) {
    final normalized = (sex ?? '').trim().toLowerCase();
    if (normalized == 'male' || normalized == 'm' || normalized == 'man') {
      return 1.0;
    }
    if (normalized == 'female' || normalized == 'f' || normalized == 'woman') {
      return 0.0;
    }
    return 0.0;
  }

  double _calculateIntensity({
    required double normalizedHeart,
    required double steps,
  }) {
    const weightHr = 0.90;
    const hrMax = 80.0;
    const stepsMax = 50.0;
    const scale = 0.791;
    const offset = -0.079;

    final hrDelta = max(0.0, normalizedHeart);
    final stepsLog = log(steps + 1);
    final hrNorm = (hrDelta / hrMax).clamp(0.0, 1.0);
    final stepsNorm = (stepsLog / log(stepsMax + 1)).clamp(0.0, 1.0);
    final intensityRaw = (weightHr * hrNorm) + ((1 - weightHr) * stepsNorm);
    return (intensityRaw * scale + offset).clamp(0.0, 1.0);
  }

  double _ewmStd(List<double> values, {required int span}) {
    if (values.length < 2) {
      return 0;
    }
    final alpha = 2 / (span + 1);
    var mean = values.first;
    var variance = 0.0;
    for (var i = 1; i < values.length; i++) {
      final current = values[i];
      final delta = current - mean;
      mean += alpha * delta;
      variance = (1 - alpha) * (variance + alpha * delta * delta);
    }
    return sqrt(max(variance, 0.0));
  }

  double _rollingPearsonLast(
    List<double> heartSeries,
    List<double> stepsSeries, {
    required int window,
  }) {
    if (heartSeries.isEmpty || stepsSeries.isEmpty) {
      return 1.0;
    }
    final length = min(heartSeries.length, stepsSeries.length);
    final start = max(0, length - window);
    final x = heartSeries.sublist(start, length);
    final y = stepsSeries.sublist(start, length);
    if (x.length < 3) {
      return 1.0;
    }
    final meanX = x.reduce((a, b) => a + b) / x.length;
    final meanY = y.reduce((a, b) => a + b) / y.length;
    var num = 0.0;
    var denX = 0.0;
    var denY = 0.0;
    for (var i = 0; i < x.length; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }
    if (denX < 1e-6 || denY < 1e-6) {
      return 1.0;
    }
    final corr = num / sqrt(denX * denY);
    if (corr.isNaN || corr.isInfinite) {
      return 1.0;
    }
    return corr.clamp(-1.0, 1.0);
  }

  _ModelStats _buildStats({
    required List<HealthMetricSample> samples,
    required DateTime now,
  }) {
    final start = now.subtract(const Duration(days: _windowDays));
    final relevant = samples
        .where((sample) {
          if (sample.timestamp.isBefore(start) ||
              sample.timestamp.isAfter(now)) {
            return false;
          }
          switch (sample.type) {
            case HealthMetricType.steps:
            case HealthMetricType.heartRate:
            case HealthMetricType.walkingHeartRate:
            case HealthMetricType.activeEnergyBurned:
            case HealthMetricType.totalCaloriesBurned:
            case HealthMetricType.distanceWalkingRunning:
            case HealthMetricType.distanceDelta:
            case HealthMetricType.restingHeartRate:
              return true;
            default:
              return false;
          }
        })
        .toList(growable: false);

    final dayMap = <DateTime, _DayStats>{};
    for (final sample in relevant) {
      final day = DateTime.utc(
        sample.timestamp.year,
        sample.timestamp.month,
        sample.timestamp.day,
      );
      final dayStats = dayMap.putIfAbsent(day, _DayStats.new);
      dayStats.consume(sample);
    }

    final days = dayMap.keys.toList(growable: false)..sort();
    final heartSeries = <double>[];
    final stepsSeries = <double>[];
    final normalizedHeartSeries = <double>[];

    for (final day in days) {
      final d = dayMap[day]!;
      final heart = d.avgHeartRate;
      final steps = d.steps;
      final resting = d.avgRestingHeartRate;
      if (heart != null) {
        heartSeries.add(heart);
      }
      stepsSeries.add(steps);
      if (heart != null && resting != null && resting > 0) {
        normalizedHeartSeries.add(heart - resting);
      }
    }

    double latestOrAverage(
      double? latest,
      List<double> source, [
      double fallback = 0.0,
    ]) {
      if (latest != null) {
        return latest;
      }
      if (source.isNotEmpty) {
        return source.reduce((a, b) => a + b) / source.length;
      }
      return fallback;
    }

    final latestDay = days.isNotEmpty ? dayMap[days.last] : null;
    final stepsValues = days
        .map((day) => dayMap[day]!.steps)
        .toList(growable: false);
    final heartValues = days
        .map((day) => dayMap[day]!.avgHeartRate)
        .whereType<double>()
        .toList(growable: false);

    final latestSteps = latestOrAverage(latestDay?.steps, stepsValues);
    final latestHeart = latestOrAverage(
      latestDay?.avgHeartRate,
      heartValues,
      60,
    );
    final latestCalories = latestOrAverage(
      latestDay?.activeCalories,
      days.map((day) => dayMap[day]!.activeCalories).toList(growable: false),
    );
    final latestDistance = latestOrAverage(
      latestDay?.distance,
      days.map((day) => dayMap[day]!.distance).toList(growable: false),
    );
    final latestResting = latestOrAverage(
      latestDay?.avgRestingHeartRate,
      days
          .map((day) => dayMap[day]!.avgRestingHeartRate)
          .whereType<double>()
          .toList(growable: false),
      60,
    );

    final availableSignals = [
      latestSteps > 0,
      latestHeart > 0,
      latestCalories > 0,
      latestDistance > 0,
      latestResting > 0,
    ].where((x) => x).length;

    return _ModelStats(
      stepsLatest: latestSteps,
      heartLatest: latestHeart,
      caloriesLatest: latestCalories,
      distanceLatest: latestDistance,
      restingLatest: latestResting,
      heartEntropy: _entropy(heartValues),
      stepsEntropy: _entropy(stepsValues),
      heartSeries: heartSeries,
      stepsSeries: stepsSeries,
      normalizedHeartSeries: normalizedHeartSeries,
      availableSignals: availableSignals,
    );
  }

  double _entropy(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    if ((maxV - minV).abs() < 1e-9) {
      return 0;
    }
    final bins = min(365, max(16, values.length));
    final counts = List<int>.filled(bins, 0);
    for (final value in values) {
      final norm = ((value - minV) / (maxV - minV)).clamp(0.0, 0.999999);
      final idx = (norm * bins).floor().clamp(0, bins - 1);
      counts[idx] += 1;
    }

    final n = values.length.toDouble();
    var entropy = 0.0;
    for (final count in counts) {
      if (count == 0) {
        continue;
      }
      final p = count / n;
      entropy -= p * log(p);
    }
    return entropy;
  }

  double _confidenceFromSignals(int availableSignals) {
    final score = (availableSignals / 5).clamp(0.0, 1.0);
    return (0.55 + score * 0.4).clamp(0.0, 0.98);
  }

  HarvardActivityRecommendationResult _insufficientResult({
    String reason = 'unknown',
    Object? payload,
  }) {
    _logger.warning(
      'model.harvard',
      'Returning insufficient-data recommendation',
      payload: {'reason': reason, if (payload != null) 'details': payload},
    );
    return HarvardActivityRecommendationResult(
      activityClass: HarvardActivityClass.insufficientData,
      confidence: 0,
      recommendationKeys: [
        'modelRecInsufficient1',
        'modelRecInsufficient2',
        'modelRecInsufficient3',
      ],
      modelVersion: _modelVersion,
    );
  }

  List<String> _recommendationsForClass(HarvardActivityClass activityClass) {
    switch (activityClass) {
      case HarvardActivityClass.insufficientData:
        return const [
          'modelRecInsufficient1',
          'modelRecInsufficient2',
          'modelRecInsufficient3',
        ];
      case HarvardActivityClass.lying:
      case HarvardActivityClass.sitting:
        return const [
          'modelRecRecovery1',
          'modelRecRecovery2',
          'modelRecRecovery3',
        ];
      case HarvardActivityClass.selfPaceWalk:
      case HarvardActivityClass.running3Met:
        return const ['modelRecBuild1', 'modelRecBuild2', 'modelRecBuild3'];
      case HarvardActivityClass.running5Met:
      case HarvardActivityClass.running7Met:
        return const [
          'modelRecPerformance1',
          'modelRecPerformance2',
          'modelRecPerformance3',
        ];
    }
  }
}

class _ModelStats {
  final double stepsLatest;
  final double heartLatest;
  final double caloriesLatest;
  final double distanceLatest;
  final double restingLatest;
  final double heartEntropy;
  final double stepsEntropy;
  final List<double> heartSeries;
  final List<double> stepsSeries;
  final List<double> normalizedHeartSeries;
  final int availableSignals;

  const _ModelStats({
    required this.stepsLatest,
    required this.heartLatest,
    required this.caloriesLatest,
    required this.distanceLatest,
    required this.restingLatest,
    required this.heartEntropy,
    required this.stepsEntropy,
    required this.heartSeries,
    required this.stepsSeries,
    required this.normalizedHeartSeries,
    required this.availableSignals,
  });
}

class _DayStats {
  double steps = 0;
  double activeCalories = 0;
  double distance = 0;
  double _heartSum = 0;
  int _heartCount = 0;
  double _restingHeartSum = 0;
  int _restingHeartCount = 0;

  void consume(HealthMetricSample sample) {
    switch (sample.type) {
      case HealthMetricType.steps:
        steps += sample.value;
        break;
      case HealthMetricType.activeEnergyBurned:
      case HealthMetricType.totalCaloriesBurned:
        activeCalories += sample.value;
        break;
      case HealthMetricType.distanceWalkingRunning:
      case HealthMetricType.distanceDelta:
        distance += sample.value;
        break;
      case HealthMetricType.heartRate:
      case HealthMetricType.walkingHeartRate:
        _heartSum += sample.value;
        _heartCount += 1;
        break;
      case HealthMetricType.restingHeartRate:
        _restingHeartSum += sample.value;
        _restingHeartCount += 1;
        break;
      default:
        break;
    }
  }

  double? get avgHeartRate => _heartCount == 0 ? null : _heartSum / _heartCount;

  double? get avgRestingHeartRate =>
      _restingHeartCount == 0 ? null : _restingHeartSum / _restingHeartCount;
}
