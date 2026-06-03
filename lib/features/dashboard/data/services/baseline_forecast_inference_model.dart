import 'dart:math' as math;

import '../../../../core/perf/perf_probe.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';

class BaselineForecastInferenceResult {
  final String modelId;
  final String modelVersion;
  final DateTime inferenceTimestamp;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime forecastFor;
  final double? overallDeviationScore;
  final double confidence;
  final String status;
  final String source;
  final String reason;
  final bool insufficientData;
  final BaselineForecastDataQuality dataQuality;
  final Map<String, BaselineForecastMetricResult> metrics;
  final BaselineForecastSummary summary;
  final Map<String, Object?> features;

  const BaselineForecastInferenceResult({
    required this.modelId,
    required this.modelVersion,
    required this.inferenceTimestamp,
    required this.windowStart,
    required this.windowEnd,
    required this.forecastFor,
    required this.overallDeviationScore,
    required this.confidence,
    required this.status,
    required this.source,
    required this.reason,
    required this.insufficientData,
    required this.dataQuality,
    required this.metrics,
    required this.summary,
    required this.features,
  });

  factory BaselineForecastInferenceResult.insufficient({
    required DateTime now,
    DateTime? forecastFor,
    String reason = 'insufficient_data',
  }) {
    final forecastDay = BaselineForecastInferenceModel.startOfUtcDay(
      forecastFor ?? now,
    );
    return BaselineForecastInferenceResult(
      modelId: BaselineForecastInferenceModel.modelId,
      modelVersion: BaselineForecastInferenceModel.modelVersion,
      inferenceTimestamp: now,
      windowStart: forecastDay.subtract(
        BaselineForecastInferenceModel.historyWindow,
      ),
      windowEnd: forecastDay.add(const Duration(days: 1)),
      forecastFor: forecastDay,
      overallDeviationScore: null,
      confidence: 0,
      status: 'insufficient',
      source: 'cold_start',
      reason: reason,
      insufficientData: true,
      dataQuality: BaselineForecastDataQuality.empty,
      metrics: const {},
      summary: const BaselineForecastSummary(
        overallDeviationScore: null,
        status: 'insufficient',
        mainReasons: ['insufficient_data'],
      ),
      features: const {'reason': 'insufficient_data'},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'model_version': modelVersion,
      'window_start': windowStart.toIso8601String(),
      'window_end': windowEnd.toIso8601String(),
      'forecast_for': forecastFor.toIso8601String(),
      'overall_deviation_score': overallDeviationScore,
      'confidence': confidence,
      'status': status,
      'source': source,
      'reason': reason,
      'metrics': metrics.map((key, value) => MapEntry(key, value.toJson())),
      'summary': summary.toJson(),
      'data_quality': dataQuality.toJson(),
      'features': features,
    };
  }
}

class BaselineForecastMetricResult {
  final String metric;
  final double? expected;
  final double? actual;
  final double? delta;
  final double? deltaPercent;
  final double? expectedRangeLow;
  final double? expectedRangeHigh;
  final double? robustZ;
  final String severity;
  final double confidence;
  final double dataQuality;
  final int validDays;
  final String method;
  final bool actualIsPartial;
  final Map<String, double?> featureSnapshot;

  const BaselineForecastMetricResult({
    required this.metric,
    required this.expected,
    required this.actual,
    required this.delta,
    required this.deltaPercent,
    required this.expectedRangeLow,
    required this.expectedRangeHigh,
    required this.robustZ,
    required this.severity,
    required this.confidence,
    required this.dataQuality,
    required this.validDays,
    required this.method,
    required this.actualIsPartial,
    required this.featureSnapshot,
  });

  Map<String, dynamic> toJson() {
    return {
      'expected': expected,
      'actual': actual,
      'delta': delta,
      'delta_percent': deltaPercent,
      'expected_range_low': expectedRangeLow,
      'expected_range_high': expectedRangeHigh,
      'robust_z': robustZ,
      'severity': severity,
      'confidence': confidence,
      'data_quality': dataQuality,
      'valid_days': validDays,
      'method': method,
      'actual_is_partial': actualIsPartial,
      'feature_snapshot': featureSnapshot,
    };
  }
}

class BaselineForecastDataQuality {
  final double overall;
  final double historyCoverage;
  final double actualCoverage;
  final double missingnessRatio;
  final Map<String, double> metrics;

  const BaselineForecastDataQuality({
    required this.overall,
    required this.historyCoverage,
    required this.actualCoverage,
    required this.missingnessRatio,
    required this.metrics,
  });

  static const empty = BaselineForecastDataQuality(
    overall: 0,
    historyCoverage: 0,
    actualCoverage: 0,
    missingnessRatio: 1,
    metrics: {},
  );

  Map<String, dynamic> toJson() {
    return {
      'overall': overall,
      'history_coverage': historyCoverage,
      'actual_coverage': actualCoverage,
      'missingness_ratio': missingnessRatio,
      'metrics': metrics,
    };
  }
}

class BaselineForecastSummary {
  final double? overallDeviationScore;
  final String status;
  final List<String> mainReasons;

  const BaselineForecastSummary({
    required this.overallDeviationScore,
    required this.status,
    required this.mainReasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'overall_deviation_score': overallDeviationScore,
      'status': status,
      'main_reasons': mainReasons,
      'notes': const ['not_a_diagnosis', 'personal_baseline_deviation_only'],
    };
  }
}

class BaselineForecastInferenceModel {
  static const String modelId = 'baseline_forecast_v1';
  static const String modelVersion = '1.0.0';
  static const Duration historyWindow = Duration(days: 30);
  static const Duration _loadWindow = Duration(days: 45);
  static const double _ridgeLambda = 0.8;
  static const double _epsilon = 1e-6;

  BaselineForecastInferenceResult inferSync({
    required List<HealthMetricSample> samples,
    DateTime? now,
    DateTime? forecastFor,
  }) {
    return PerfProbe.measureSync(
      'model.baseline_forecast.infer_sync',
      () {
        final utcNow = (now ?? DateTime.now()).toUtc();
        final forecastDay = startOfUtcDay(forecastFor ?? utcNow);
        final windowStart = forecastDay.subtract(historyWindow);
        final windowEnd = forecastDay.add(const Duration(days: 1));
        final relevantSamples = samples
            .where(
              (sample) =>
                  sample.sourceId.trim().toLowerCase() != 'local_manual',
            )
            .where((sample) => _trackedTypes.contains(sample.type))
            .where((sample) => !sample.timestamp.toUtc().isAfter(utcNow))
            .where(
              (sample) => sample.timestamp.toUtc().isAfter(
                forecastDay.subtract(_loadWindow),
              ),
            )
            .toList(growable: false);

        if (relevantSamples.isEmpty) {
          return BaselineForecastInferenceResult.insufficient(
            now: utcNow,
            forecastFor: forecastDay,
            reason: 'no_wearable_samples',
          );
        }

        final daily = _buildDailyMetrics(
          samples: relevantSamples,
          startDay: forecastDay.subtract(_loadWindow),
          endExclusive: windowEnd,
        );

        final metricResults = <String, BaselineForecastMetricResult>{};
        final dailyFeatureVector = <String, Object?>{};

        for (final spec in _targetSpecs) {
          final result = _forecastMetric(
            spec: spec,
            daily: daily,
            forecastDay: forecastDay,
            now: utcNow,
          );
          metricResults[spec.key] = result;
          dailyFeatureVector[spec.key] = result.featureSnapshot;
        }

        final scoredMetrics = metricResults.values
            .where((metric) => metric.expected != null)
            .toList(growable: false);
        final comparableMetrics = metricResults.values
            .where((metric) => metric.delta != null && metric.robustZ != null)
            .toList(growable: false);
        final overallScore = comparableMetrics.isEmpty
            ? null
            : _overallDeviationScore(comparableMetrics);
        final status = _statusForScore(overallScore);
        final reasons = _mainReasons(metricResults.values);
        final quality = _dataQuality(metricResults.values);
        final confidence = _resultConfidence(metricResults.values, quality);
        final insufficient = scoredMetrics.length < 3 || quality.overall < 0.25;

        return BaselineForecastInferenceResult(
          modelId: modelId,
          modelVersion: modelVersion,
          inferenceTimestamp: utcNow,
          windowStart: windowStart,
          windowEnd: windowEnd,
          forecastFor: forecastDay,
          overallDeviationScore: overallScore,
          confidence: confidence,
          status: insufficient ? 'insufficient' : status,
          source: scoredMetrics.isEmpty
              ? 'cold_start'
              : _sourceFor(scoredMetrics),
          reason: scoredMetrics.isEmpty
              ? 'insufficient_baseline'
              : insufficient
              ? 'low_forecast_coverage'
              : 'ok',
          insufficientData: insufficient,
          dataQuality: quality,
          metrics: Map.unmodifiable(metricResults),
          summary: BaselineForecastSummary(
            overallDeviationScore: overallScore,
            status: insufficient ? 'insufficient' : status,
            mainReasons: reasons.isEmpty ? ['within_expected_range'] : reasons,
          ),
          features: {
            'forecast_for': forecastDay.toIso8601String(),
            'history_days': historyWindow.inDays,
            'forecastable_metrics': scoredMetrics.length,
            'comparable_metrics': comparableMetrics.length,
            'daily_feature_vector': dailyFeatureVector,
            'metrics': metricResults.map(
              (key, value) => MapEntry(key, value.toJson()),
            ),
            'summary': BaselineForecastSummary(
              overallDeviationScore: overallScore,
              status: insufficient ? 'insufficient' : status,
              mainReasons: reasons.isEmpty
                  ? ['within_expected_range']
                  : reasons,
            ).toJson(),
          },
        );
      },
      payload: <String, Object?>{'sample_count': samples.length},
    );
  }

  static DateTime startOfUtcDay(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  BaselineForecastMetricResult _forecastMetric({
    required _MetricSpec spec,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime forecastDay,
    required DateTime now,
  }) {
    final historyByDay = _historyByDay(
      daily: daily,
      metricKey: spec.key,
      beforeDay: forecastDay,
      days: historyWindow.inDays,
    );
    final historyValues = historyByDay.values
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    final validDays = historyValues.length;
    final actual = daily[forecastDay]?.values[spec.key];
    final actualIsPartial = _isActualPartial(
      spec: spec,
      forecastDay: forecastDay,
      now: now,
      actual: actual,
    );
    final featureSnapshot = _featureSnapshot(
      metricKey: spec.key,
      daily: daily,
      forecastDay: forecastDay,
      validDays: validDays,
    );
    final dataQuality = _metricDataQuality(
      validDays: validDays,
      actual: actual,
      actualIsPartial: actualIsPartial,
    );

    if (validDays < 3) {
      return BaselineForecastMetricResult(
        metric: spec.key,
        expected: null,
        actual: actual,
        delta: null,
        deltaPercent: null,
        expectedRangeLow: null,
        expectedRangeHigh: null,
        robustZ: null,
        severity: 'insufficient',
        confidence: dataQuality.clamp(0.0, 0.2),
        dataQuality: dataQuality,
        validDays: validDays,
        method: 'cold_start_no_expected',
        actualIsPartial: actualIsPartial,
        featureSnapshot: featureSnapshot,
      );
    }

    final forecast = _pointForecast(
      spec: spec,
      daily: daily,
      forecastDay: forecastDay,
      validDays: validDays,
    );
    final expected = forecast.expected;
    final residualMad = _backtestResidualMad(
      spec: spec,
      daily: daily,
      forecastDay: forecastDay,
    );
    final historicalMad = _mad(historyValues);
    final robustSpread = math.max(
      spec.minSpread,
      math.max(
        expected.abs() * spec.percentSpread,
        1.4826 * math.max(residualMad ?? 0, historicalMad),
      ),
    );
    final low = spec.lowerBoundZero
        ? math.max(0.0, expected - (1.64 * robustSpread))
        : expected - (1.64 * robustSpread);
    final high = expected + (1.64 * robustSpread);
    final median30 = _median(historyValues);
    final mad30 = historicalMad;
    final comparable = actual != null && !actualIsPartial;
    final delta = comparable ? actual - expected : null;
    final deltaPercent = comparable
        ? ((actual - expected) / math.max(expected.abs(), _epsilon)) * 100.0
        : null;
    final robustZ = comparable
        ? (actual - median30) / math.max(1.4826 * mad30, spec.minSpread)
        : null;
    final severity = _severity(
      actual: actual,
      actualIsPartial: actualIsPartial,
      robustZ: robustZ,
      low: low,
      high: high,
    );
    final confidence = _metricConfidence(
      validDays: validDays,
      dataQuality: dataQuality,
      residualMad: residualMad,
      spread: robustSpread,
      method: forecast.method,
    );

    return BaselineForecastMetricResult(
      metric: spec.key,
      expected: _round(expected),
      actual: actual == null ? null : _round(actual),
      delta: delta == null ? null : _round(delta),
      deltaPercent: deltaPercent == null ? null : _round(deltaPercent),
      expectedRangeLow: _round(low),
      expectedRangeHigh: _round(high),
      robustZ: robustZ == null ? null : _round(robustZ),
      severity: severity,
      confidence: confidence,
      dataQuality: dataQuality,
      validDays: validDays,
      method: forecast.method,
      actualIsPartial: actualIsPartial,
      featureSnapshot: featureSnapshot,
    );
  }

  _MetricForecast _pointForecast({
    required _MetricSpec spec,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime forecastDay,
    required int validDays,
  }) {
    final median7 = _rollingValues(
      metricKey: spec.key,
      daily: daily,
      beforeDay: forecastDay,
      days: 7,
    );
    final median14 = _rollingValues(
      metricKey: spec.key,
      daily: daily,
      beforeDay: forecastDay,
      days: 14,
    );
    final median30 = _rollingValues(
      metricKey: spec.key,
      daily: daily,
      beforeDay: forecastDay,
      days: 30,
    );
    final median = _median(
      validDays >= 14 && median14.isNotEmpty ? median14 : median7,
    );

    if (validDays < 7) {
      return _MetricForecast(expected: median, method: 'rolling_median');
    }

    final ewma = _ewma(
      _datedValues(
        metricKey: spec.key,
        daily: daily,
        beforeDay: forecastDay,
        days: 30,
      ),
    );

    if (validDays < 14) {
      final expected = (median * 0.60) + ((ewma ?? median) * 0.40);
      return _MetricForecast(
        expected: _clipForecast(expected, spec, median30),
        method: 'rolling_median_ewma',
      );
    }

    final ridge = _ridgePrediction(
      spec: spec,
      daily: daily,
      forecastDay: forecastDay,
    );
    final robustMedian = median30.isNotEmpty ? _median(median30) : median;
    final ewmaValue = ewma ?? robustMedian;

    if (ridge == null) {
      final expected = (robustMedian * 0.60) + (ewmaValue * 0.40);
      return _MetricForecast(
        expected: _clipForecast(expected, spec, median30),
        method: 'rolling_median_ewma',
      );
    }

    final expected =
        (robustMedian * 0.45) + (ewmaValue * 0.30) + (ridge * 0.25);
    return _MetricForecast(
      expected: _clipForecast(expected, spec, median30),
      method: 'median_ewma_ridge_blend',
    );
  }

  double? _ridgePrediction({
    required _MetricSpec spec,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime forecastDay,
  }) {
    final rows = <List<double>>[];
    final targets = <double>[];
    final firstTrainingDay = forecastDay.subtract(const Duration(days: 29));

    for (
      var day = firstTrainingDay;
      day.isBefore(forecastDay);
      day = day.add(const Duration(days: 1))
    ) {
      final target = daily[day]?.values[spec.key];
      if (target == null || !target.isFinite) {
        continue;
      }
      final previousValues = _rollingValues(
        metricKey: spec.key,
        daily: daily,
        beforeDay: day,
        days: 14,
      );
      if (previousValues.length < 5) {
        continue;
      }
      rows.add(_regressionFeatures(spec.key, daily, day));
      targets.add(target);
    }

    if (rows.length < 6) {
      return null;
    }

    final forecastFeatures = _regressionFeatures(spec.key, daily, forecastDay);
    return _fitRidgeAndPredict(rows, targets, forecastFeatures);
  }

  List<double> _regressionFeatures(
    String metricKey,
    Map<DateTime, _DailyMetrics> daily,
    DateTime targetDay,
  ) {
    final median14 = _safeMedian(
      _rollingValues(
        metricKey: metricKey,
        daily: daily,
        beforeDay: targetDay,
        days: 14,
      ),
    );
    double valueOrMedian(int lag) {
      return daily[targetDay.subtract(Duration(days: lag))]
              ?.values[metricKey] ??
          median14;
    }

    final mean7 = _safeMean(
      _rollingValues(
        metricKey: metricKey,
        daily: daily,
        beforeDay: targetDay,
        days: 7,
      ),
      fallback: median14,
    );
    final std7 = _std(
      _rollingValues(
        metricKey: metricKey,
        daily: daily,
        beforeDay: targetDay,
        days: 7,
      ),
    );
    final slope7 = _slope(
      _datedValues(
        metricKey: metricKey,
        daily: daily,
        beforeDay: targetDay,
        days: 7,
      ),
    );
    final activityLoad = _previousDayActivityLoad(daily, targetDay);
    final sleepQuality = _previousDaySleepQualityProxy(daily, targetDay);
    final stressProxy = _previousDayStressProxy(daily, targetDay);
    final dayAngle = (targetDay.weekday - 1) / 7.0 * 2.0 * math.pi;

    return [
      valueOrMedian(1),
      valueOrMedian(2),
      valueOrMedian(3),
      valueOrMedian(7),
      valueOrMedian(14),
      mean7,
      median14,
      std7,
      slope7,
      activityLoad ?? 0,
      sleepQuality ?? 0,
      stressProxy ?? 0,
      math.sin(dayAngle),
      math.cos(dayAngle),
      targetDay.weekday >= DateTime.saturday ? 1 : 0,
    ];
  }

  double? _fitRidgeAndPredict(
    List<List<double>> rows,
    List<double> targets,
    List<double> forecastFeatures,
  ) {
    if (rows.isEmpty || rows.length != targets.length) {
      return null;
    }
    final featureCount = rows.first.length;
    final means = List<double>.filled(featureCount, 0);
    final scales = List<double>.filled(featureCount, 1);

    for (var j = 0; j < featureCount; j++) {
      final column = rows.map((row) => row[j]).toList(growable: false);
      means[j] = _mean(column);
      final std = _std(column);
      scales[j] = std < _epsilon ? 1 : std;
    }

    final design = rows
        .map(
          (row) => [
            1.0,
            for (var j = 0; j < featureCount; j++)
              (row[j] - means[j]) / scales[j],
          ],
        )
        .toList(growable: false);
    final columns = featureCount + 1;
    final a = List.generate(columns, (_) => List<double>.filled(columns, 0));
    final b = List<double>.filled(columns, 0);

    for (var i = 0; i < design.length; i++) {
      final row = design[i];
      final y = targets[i];
      for (var j = 0; j < columns; j++) {
        b[j] += row[j] * y;
        for (var k = 0; k < columns; k++) {
          a[j][k] += row[j] * row[k];
        }
      }
    }

    for (var j = 1; j < columns; j++) {
      a[j][j] += _ridgeLambda;
    }

    final coefficients = _solveLinearSystem(a, b);
    if (coefficients == null) {
      return null;
    }

    final x = [
      1.0,
      for (var j = 0; j < featureCount; j++)
        (forecastFeatures[j] - means[j]) / scales[j],
    ];
    var prediction = 0.0;
    for (var j = 0; j < x.length; j++) {
      prediction += x[j] * coefficients[j];
    }
    return prediction.isFinite ? prediction : null;
  }

  List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
    final n = b.length;
    final matrix = List.generate(n, (i) => [...a[i], b[i]], growable: false);

    for (var col = 0; col < n; col++) {
      var pivot = col;
      var pivotAbs = matrix[col][col].abs();
      for (var row = col + 1; row < n; row++) {
        final candidate = matrix[row][col].abs();
        if (candidate > pivotAbs) {
          pivot = row;
          pivotAbs = candidate;
        }
      }
      if (pivotAbs < _epsilon) {
        return null;
      }
      if (pivot != col) {
        final tmp = matrix[col];
        matrix[col] = matrix[pivot];
        matrix[pivot] = tmp;
      }

      final divisor = matrix[col][col];
      for (var j = col; j <= n; j++) {
        matrix[col][j] /= divisor;
      }

      for (var row = 0; row < n; row++) {
        if (row == col) {
          continue;
        }
        final factor = matrix[row][col];
        if (factor.abs() < _epsilon) {
          continue;
        }
        for (var j = col; j <= n; j++) {
          matrix[row][j] -= factor * matrix[col][j];
        }
      }
    }

    return List.generate(n, (i) => matrix[i][n], growable: false);
  }

  Map<DateTime, _DailyMetrics> _buildDailyMetrics({
    required List<HealthMetricSample> samples,
    required DateTime startDay,
    required DateTime endExclusive,
  }) {
    final grouped = <DateTime, List<HealthMetricSample>>{};
    for (final sample in samples) {
      final ts = sample.timestamp.toUtc();
      if (ts.isBefore(startDay) || !ts.isBefore(endExclusive)) {
        continue;
      }
      final day = startOfUtcDay(ts);
      grouped.putIfAbsent(day, () => []).add(sample);
    }

    final result = <DateTime, _DailyMetrics>{};
    for (final entry in grouped.entries) {
      result[entry.key] = _aggregateDay(entry.value);
    }
    return result;
  }

  _DailyMetrics _aggregateDay(List<HealthMetricSample> samples) {
    final values = <String, double>{};
    final counts = <String, int>{};

    for (final spec in _targetSpecs) {
      final aggregated = _aggregateMetric(spec, samples);
      if (aggregated == null || !aggregated.isFinite) {
        continue;
      }
      values[spec.key] = _winsorizeToSpec(aggregated, spec);
      counts[spec.key] = _countSamplesFor(spec, samples);
    }

    final awake =
        _sumByType(samples, HealthMetricType.sleepAwake) +
        _sumByType(samples, HealthMetricType.sleepAwakeInBed);
    if (awake > 0) {
      values['sleep_awake_minutes'] = awake;
    }

    values['high_hr_event_count'] = _eventCount(
      samples,
      HealthMetricType.highHeartRateEvent,
    );
    values['low_hr_event_count'] = _eventCount(
      samples,
      HealthMetricType.lowHeartRateEvent,
    );
    values['irregular_hr_event_count'] = _eventCount(
      samples,
      HealthMetricType.irregularHeartRateEvent,
    );

    return _DailyMetrics(values: values, sampleCounts: counts);
  }

  double? _aggregateMetric(_MetricSpec spec, List<HealthMetricSample> samples) {
    switch (spec.aggregation) {
      case _Aggregation.hrv:
        final rmssd = _valuesFor(
          samples,
          HealthMetricType.heartRateVariabilityRmssd,
        );
        if (rmssd.isNotEmpty) {
          return _median(rmssd);
        }
        final sdnn = _valuesFor(
          samples,
          HealthMetricType.heartRateVariabilitySdnn,
        );
        return sdnn.isEmpty ? null : _median(sdnn);
      case _Aggregation.temperature:
        final values = <double>[
          ..._valuesFor(samples, HealthMetricType.sleepWristTemperature),
          ..._valuesFor(samples, HealthMetricType.skinTemperature),
          ..._valuesFor(samples, HealthMetricType.bodyTemperature),
        ];
        return values.isEmpty ? null : _median(values);
      case _Aggregation.sleepDuration:
        final asleep = _sumByType(samples, HealthMetricType.sleepAsleep);
        if (asleep > 0) {
          return asleep;
        }
        final stages =
            _sumByType(samples, HealthMetricType.sleepDeep) +
            _sumByType(samples, HealthMetricType.sleepLight) +
            _sumByType(samples, HealthMetricType.sleepRem);
        return stages > 0 ? stages : null;
      case _Aggregation.sum:
        final total = spec.types.fold<double>(
          0,
          (sum, type) => sum + _sumByType(samples, type),
        );
        return total > 0 ? total : null;
      case _Aggregation.median:
        final values = spec.types
            .expand((type) => _valuesFor(samples, type))
            .toList(growable: false);
        return values.isEmpty ? null : _median(values);
    }
  }

  int _countSamplesFor(_MetricSpec spec, List<HealthMetricSample> samples) {
    return samples.where((sample) => spec.types.contains(sample.type)).length;
  }

  double _sumByType(List<HealthMetricSample> samples, HealthMetricType type) {
    return samples
        .where((sample) => sample.type == type)
        .map((sample) => sample.value)
        .where((value) => value.isFinite && value > 0)
        .fold<double>(0, (sum, value) => sum + value);
  }

  List<double> _valuesFor(
    List<HealthMetricSample> samples,
    HealthMetricType type,
  ) {
    return samples
        .where((sample) => sample.type == type)
        .map((sample) => sample.value)
        .where((value) => value.isFinite && value > 0)
        .toList(growable: false);
  }

  double _eventCount(List<HealthMetricSample> samples, HealthMetricType type) {
    return samples
        .where((sample) => sample.type == type)
        .fold<double>(0, (sum, sample) => sum + math.max(sample.value, 1));
  }

  Map<DateTime, double?> _historyByDay({
    required Map<DateTime, _DailyMetrics> daily,
    required String metricKey,
    required DateTime beforeDay,
    required int days,
  }) {
    final result = <DateTime, double?>{};
    for (var offset = days; offset >= 1; offset--) {
      final day = beforeDay.subtract(Duration(days: offset));
      result[day] = daily[day]?.values[metricKey];
    }
    return result;
  }

  List<double> _rollingValues({
    required String metricKey,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime beforeDay,
    required int days,
  }) {
    final values = <double>[];
    for (var offset = days; offset >= 1; offset--) {
      final value =
          daily[beforeDay.subtract(Duration(days: offset))]?.values[metricKey];
      if (value != null && value.isFinite) {
        values.add(value);
      }
    }
    return values;
  }

  List<_DatedValue> _datedValues({
    required String metricKey,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime beforeDay,
    required int days,
  }) {
    final values = <_DatedValue>[];
    for (var offset = days; offset >= 1; offset--) {
      final day = beforeDay.subtract(Duration(days: offset));
      final value = daily[day]?.values[metricKey];
      if (value != null && value.isFinite) {
        values.add(_DatedValue(day: day, value: value));
      }
    }
    return values;
  }

  Map<String, double?> _featureSnapshot({
    required String metricKey,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime forecastDay,
    required int validDays,
  }) {
    double? lag(int days) {
      return daily[forecastDay.subtract(Duration(days: days))]
          ?.values[metricKey];
    }

    final values3 = _rollingValues(
      metricKey: metricKey,
      daily: daily,
      beforeDay: forecastDay,
      days: 3,
    );
    final values7 = _rollingValues(
      metricKey: metricKey,
      daily: daily,
      beforeDay: forecastDay,
      days: 7,
    );
    final values14 = _rollingValues(
      metricKey: metricKey,
      daily: daily,
      beforeDay: forecastDay,
      days: 14,
    );
    final values30 = _rollingValues(
      metricKey: metricKey,
      daily: daily,
      beforeDay: forecastDay,
      days: 30,
    );

    return {
      'lag_1': lag(1),
      'lag_2': lag(2),
      'lag_3': lag(3),
      'lag_7': lag(7),
      'lag_14': lag(14),
      'rolling_mean_3': values3.isEmpty ? null : _mean(values3),
      'rolling_mean_7': values7.isEmpty ? null : _mean(values7),
      'rolling_mean_14': values14.isEmpty ? null : _mean(values14),
      'rolling_mean_30': values30.isEmpty ? null : _mean(values30),
      'rolling_median_7': values7.isEmpty ? null : _median(values7),
      'rolling_median_14': values14.isEmpty ? null : _median(values14),
      'rolling_median_30': values30.isEmpty ? null : _median(values30),
      'rolling_std_7': values7.length < 2 ? null : _std(values7),
      'rolling_std_14': values14.length < 2 ? null : _std(values14),
      'rolling_std_30': values30.length < 2 ? null : _std(values30),
      'slope_7': _slope(
        _datedValues(
          metricKey: metricKey,
          daily: daily,
          beforeDay: forecastDay,
          days: 7,
        ),
      ),
      'slope_14': _slope(
        _datedValues(
          metricKey: metricKey,
          daily: daily,
          beforeDay: forecastDay,
          days: 14,
        ),
      ),
      'day_of_week': forecastDay.weekday.toDouble(),
      'is_weekend': forecastDay.weekday >= DateTime.saturday ? 1 : 0,
      'valid_days': validDays.toDouble(),
      'sleep_debt': _sleepDebt(daily, forecastDay),
      'previous_day_activity_load': _previousDayActivityLoad(
        daily,
        forecastDay,
      ),
      'previous_day_sleep_quality_proxy': _previousDaySleepQualityProxy(
        daily,
        forecastDay,
      ),
      'previous_day_stress_proxy': _previousDayStressProxy(daily, forecastDay),
    };
  }

  double? _backtestResidualMad({
    required _MetricSpec spec,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime forecastDay,
  }) {
    final residuals = <double>[];
    for (var offset = 14; offset >= 1; offset--) {
      final day = forecastDay.subtract(Duration(days: offset));
      final actual = daily[day]?.values[spec.key];
      if (actual == null || !actual.isFinite) {
        continue;
      }
      final prior = _rollingValues(
        metricKey: spec.key,
        daily: daily,
        beforeDay: day,
        days: 14,
      );
      if (prior.length < 3) {
        continue;
      }
      final expected = prior.length >= 7
          ? (_median(prior) * 0.60) +
                ((_ewma(
                          _datedValues(
                            metricKey: spec.key,
                            daily: daily,
                            beforeDay: day,
                            days: 14,
                          ),
                        ) ??
                        _median(prior)) *
                    0.40)
          : _median(prior);
      residuals.add(actual - expected);
    }

    if (residuals.length < 3) {
      return null;
    }
    return _mad(residuals);
  }

  double? _ewma(List<_DatedValue> values, {double alpha = 0.35}) {
    if (values.isEmpty) {
      return null;
    }
    var current = values.first.value;
    for (final value in values.skip(1)) {
      current = (alpha * value.value) + ((1 - alpha) * current);
    }
    return current;
  }

  double _clipForecast(
    double value,
    _MetricSpec spec,
    List<double> historyValues,
  ) {
    if (historyValues.length < 5) {
      return _winsorizeToSpec(value, spec);
    }
    final sorted = [...historyValues]..sort();
    final p05 = _percentile(sorted, 0.05);
    final p95 = _percentile(sorted, 0.95);
    final spread = math.max(1.4826 * _mad(historyValues), spec.minSpread);
    return _winsorizeToSpec(
      value.clamp(p05 - (2 * spread), p95 + (2 * spread)).toDouble(),
      spec,
    );
  }

  double _winsorizeToSpec(double value, _MetricSpec spec) {
    var next = value;
    if (spec.lowerBoundZero) {
      next = math.max(0, next);
    }
    if (spec.minPhysiological != null) {
      next = math.max(spec.minPhysiological!, next);
    }
    if (spec.maxPhysiological != null) {
      next = math.min(spec.maxPhysiological!, next);
    }
    return next;
  }

  bool _isActualPartial({
    required _MetricSpec spec,
    required DateTime forecastDay,
    required DateTime now,
    required double? actual,
  }) {
    if (actual == null) {
      return false;
    }
    final today = startOfUtcDay(now);
    if (forecastDay.isBefore(today)) {
      return false;
    }
    if (forecastDay.isAfter(today)) {
      return true;
    }
    if (spec.partialUntilHourUtc == null) {
      return false;
    }
    return now.toUtc().hour < spec.partialUntilHourUtc!;
  }

  double _metricDataQuality({
    required int validDays,
    required double? actual,
    required bool actualIsPartial,
  }) {
    final historyScore = (validDays / historyWindow.inDays).clamp(0.0, 1.0);
    final actualScore = actual == null ? 0.0 : (actualIsPartial ? 0.35 : 1.0);
    return ((historyScore * 0.78) + (actualScore * 0.22))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _metricConfidence({
    required int validDays,
    required double dataQuality,
    required double? residualMad,
    required double spread,
    required String method,
  }) {
    final historyScore = (validDays / historyWindow.inDays).clamp(0.0, 1.0);
    final methodScore = switch (method) {
      'rolling_median' => 0.45,
      'rolling_median_ewma' => 0.62,
      'median_ewma_ridge_blend' => 0.78,
      _ => 0.25,
    };
    final residualScore = residualMad == null
        ? 0.45
        : (1.0 - (residualMad / math.max(spread, _epsilon))).clamp(0.2, 0.9);
    return ((historyScore * 0.35) +
            (dataQuality * 0.30) +
            (methodScore * 0.20) +
            (residualScore * 0.15))
        .clamp(0.0, 0.92)
        .toDouble();
  }

  BaselineForecastDataQuality _dataQuality(
    Iterable<BaselineForecastMetricResult> metrics,
  ) {
    final list = metrics.toList(growable: false);
    if (list.isEmpty) {
      return BaselineForecastDataQuality.empty;
    }
    final qualityByMetric = {
      for (final metric in list) metric.metric: _round(metric.dataQuality),
    };
    final overall = _mean(list.map((metric) => metric.dataQuality).toList());
    final historyCoverage = _mean(
      list
          .map(
            (metric) =>
                (metric.validDays / historyWindow.inDays).clamp(0.0, 1.0),
          )
          .toList(),
    );
    final actualCoverage =
        list.where((metric) => metric.actual != null).length / list.length;
    return BaselineForecastDataQuality(
      overall: _round(overall),
      historyCoverage: _round(historyCoverage),
      actualCoverage: _round(actualCoverage),
      missingnessRatio: _round(1.0 - historyCoverage),
      metrics: qualityByMetric,
    );
  }

  double _resultConfidence(
    Iterable<BaselineForecastMetricResult> metrics,
    BaselineForecastDataQuality quality,
  ) {
    final forecastable = metrics
        .where((metric) => metric.expected != null)
        .toList(growable: false);
    if (forecastable.isEmpty) {
      return 0;
    }
    final metricConfidence = _mean(
      forecastable.map((metric) => metric.confidence).toList(growable: false),
    );
    final coverageScore = (forecastable.length / _targetSpecs.length)
        .clamp(0.0, 1.0)
        .toDouble();
    return _round(
      ((metricConfidence * 0.55) +
              (quality.overall * 0.30) +
              (coverageScore * 0.15))
          .clamp(0.0, 0.92)
          .toDouble(),
    );
  }

  double _overallDeviationScore(
    Iterable<BaselineForecastMetricResult> comparableMetrics,
  ) {
    var weighted = 0.0;
    var weights = 0.0;
    for (final metric in comparableMetrics) {
      final spec = _specByKey(metric.metric);
      final z = metric.robustZ?.abs() ?? 0;
      final normalized = (z / 3.0).clamp(0.0, 1.0).toDouble();
      final severityBoost = switch (metric.severity) {
        'high' => 1.0,
        'moderate' => math.max(normalized, 0.66),
        'mild' => math.max(normalized, 0.34),
        _ => normalized,
      };
      weighted += severityBoost * spec.weight;
      weights += spec.weight;
    }
    if (weights <= 0) {
      return 0;
    }
    return _round((weighted / weights) * 100.0);
  }

  String _statusForScore(double? score) {
    if (score == null) {
      return 'pending_actuals';
    }
    if (score >= 61) {
      return 'high_deviation';
    }
    if (score >= 31) {
      return 'attention';
    }
    return 'stable';
  }

  String _sourceFor(List<BaselineForecastMetricResult> metrics) {
    if (metrics.any((metric) => metric.method == 'median_ewma_ridge_blend')) {
      return 'median_ewma_ridge_blend';
    }
    if (metrics.any((metric) => metric.method == 'rolling_median_ewma')) {
      return 'rolling_median_ewma';
    }
    return 'rolling_median';
  }

  List<String> _mainReasons(Iterable<BaselineForecastMetricResult> metrics) {
    final reasons = <_ReasonCandidate>[];
    for (final metric in metrics) {
      if (metric.delta == null ||
          metric.expected == null ||
          metric.severity == 'normal' ||
          metric.severity == 'pending' ||
          metric.severity == 'insufficient') {
        continue;
      }
      final direction = metric.delta! >= 0 ? 'above' : 'below';
      reasons.add(
        _ReasonCandidate(
          code: '${metric.metric}_${direction}_expected',
          impact: metric.robustZ?.abs() ?? 0,
        ),
      );
    }
    reasons.sort((a, b) => b.impact.compareTo(a.impact));
    return reasons.take(6).map((reason) => reason.code).toList(growable: false);
  }

  String _severity({
    required double? actual,
    required bool actualIsPartial,
    required double? robustZ,
    required double low,
    required double high,
  }) {
    if (actual == null) {
      return 'pending';
    }
    if (actualIsPartial) {
      return 'pending';
    }
    final absZ = robustZ?.abs() ?? 0;
    if (absZ >= 3.0) {
      return 'high';
    }
    if (absZ >= 2.0) {
      return 'moderate';
    }
    if (absZ >= 1.0 || actual < low || actual > high) {
      return 'mild';
    }
    return 'normal';
  }

  double? _sleepDebt(Map<DateTime, _DailyMetrics> daily, DateTime forecastDay) {
    final sleepValues = _rollingValues(
      metricKey: 'sleep_duration',
      daily: daily,
      beforeDay: forecastDay,
      days: 7,
    );
    final sleepBaseline = _rollingValues(
      metricKey: 'sleep_duration',
      daily: daily,
      beforeDay: forecastDay,
      days: 30,
    );
    if (sleepValues.isEmpty || sleepBaseline.length < 3) {
      return null;
    }
    return _median(sleepBaseline) - _mean(sleepValues);
  }

  double? _previousDayActivityLoad(
    Map<DateTime, _DailyMetrics> daily,
    DateTime targetDay,
  ) {
    final previousDay = targetDay.subtract(const Duration(days: 1));
    final previous = daily[previousDay];
    if (previous == null) {
      return null;
    }
    final components = <double>[];
    for (final key in ['steps', 'active_energy', 'exercise_time']) {
      final value = previous.values[key];
      if (value == null) {
        continue;
      }
      final z = _robustZFor(
        metricKey: key,
        value: value,
        daily: daily,
        beforeDay: targetDay,
      );
      if (z != null) {
        components.add(z);
      }
    }
    if (components.isEmpty) {
      return null;
    }
    return _mean(components);
  }

  double? _previousDaySleepQualityProxy(
    Map<DateTime, _DailyMetrics> daily,
    DateTime targetDay,
  ) {
    final previous = daily[targetDay.subtract(const Duration(days: 1))];
    if (previous == null) {
      return null;
    }
    final sleep = previous.values['sleep_duration'];
    final awake = previous.values['sleep_awake_minutes'] ?? 0;
    final deep = previous.values['deep_sleep'];
    final rem = previous.values['rem_sleep'];
    if (sleep == null || sleep <= 0) {
      return null;
    }
    final restorative = ((deep ?? 0) + (rem ?? 0)) / sleep;
    final fragmentation = awake / math.max(sleep + awake, 1);
    return restorative - fragmentation;
  }

  double? _previousDayStressProxy(
    Map<DateTime, _DailyMetrics> daily,
    DateTime targetDay,
  ) {
    final previous = daily[targetDay.subtract(const Duration(days: 1))];
    if (previous == null) {
      return null;
    }
    final rhr = previous.values['resting_hr'];
    final hrv = previous.values['hrv'];
    final respiration = previous.values['respiratory_rate'];
    final parts = <double>[];
    if (rhr != null) {
      final z = _robustZFor(
        metricKey: 'resting_hr',
        value: rhr,
        daily: daily,
        beforeDay: targetDay,
      );
      if (z != null) parts.add(z);
    }
    if (hrv != null) {
      final z = _robustZFor(
        metricKey: 'hrv',
        value: hrv,
        daily: daily,
        beforeDay: targetDay,
      );
      if (z != null) parts.add(-z);
    }
    if (respiration != null) {
      final z = _robustZFor(
        metricKey: 'respiratory_rate',
        value: respiration,
        daily: daily,
        beforeDay: targetDay,
      );
      if (z != null) parts.add(z);
    }
    if (parts.isEmpty) {
      return null;
    }
    return _mean(parts);
  }

  double? _robustZFor({
    required String metricKey,
    required double value,
    required Map<DateTime, _DailyMetrics> daily,
    required DateTime beforeDay,
  }) {
    final values = _rollingValues(
      metricKey: metricKey,
      daily: daily,
      beforeDay: beforeDay,
      days: 30,
    );
    if (values.length < 3) {
      return null;
    }
    final mad = _mad(values);
    final spec = _specByKey(metricKey);
    return (value - _median(values)) / math.max(1.4826 * mad, spec.minSpread);
  }

  _MetricSpec _specByKey(String key) {
    for (final spec in _targetSpecs) {
      if (spec.key == key) {
        return spec;
      }
    }
    return _genericSpec;
  }

  double _safeMean(List<double> values, {required double fallback}) {
    return values.isEmpty ? fallback : _mean(values);
  }

  double _safeMedian(List<double> values) {
    return values.isEmpty ? 0 : _median(values);
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.fold<double>(0, (sum, value) => sum + value) / values.length;
  }

  static double _std(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final mean = _mean(values);
    final variance =
        values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .fold<double>(0, (sum, value) => sum + value) /
        (values.length - 1);
    return math.sqrt(variance);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static double _mad(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final median = _median(values);
    final deviations = values
        .map((value) => (value - median).abs())
        .toList(growable: false);
    return _median(deviations);
  }

  static double _percentile(List<double> sortedValues, double p) {
    if (sortedValues.isEmpty) {
      return 0;
    }
    if (sortedValues.length == 1) {
      return sortedValues.first;
    }
    final position = (sortedValues.length - 1) * p.clamp(0.0, 1.0);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) {
      return sortedValues[lower];
    }
    final weight = position - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }

  double _slope(List<_DatedValue> values) {
    if (values.length < 2) {
      return 0;
    }
    final xValues = List<double>.generate(
      values.length,
      (index) => index.toDouble(),
    );
    final yValues = values.map((value) => value.value).toList(growable: false);
    final xMean = _mean(xValues);
    final yMean = _mean(yValues);
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < values.length; i++) {
      numerator += (xValues[i] - xMean) * (yValues[i] - yMean);
      denominator += math.pow(xValues[i] - xMean, 2).toDouble();
    }
    if (denominator.abs() < _epsilon) {
      return 0;
    }
    return numerator / denominator;
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return value;
    }
    return double.parse(value.toStringAsFixed(3));
  }

  static const _genericSpec = _MetricSpec(
    key: 'generic',
    types: [],
    aggregation: _Aggregation.median,
    minSpread: 1,
    percentSpread: 0.05,
    lowerBoundZero: false,
    weight: 1,
  );

  static const List<_MetricSpec> _targetSpecs = [
    _MetricSpec(
      key: 'resting_hr',
      types: [HealthMetricType.restingHeartRate],
      aggregation: _Aggregation.median,
      minSpread: 3,
      percentSpread: 0.04,
      lowerBoundZero: true,
      minPhysiological: 35,
      maxPhysiological: 140,
      weight: 1.2,
    ),
    _MetricSpec(
      key: 'hrv',
      types: [
        HealthMetricType.heartRateVariabilityRmssd,
        HealthMetricType.heartRateVariabilitySdnn,
      ],
      aggregation: _Aggregation.hrv,
      minSpread: 6,
      percentSpread: 0.12,
      lowerBoundZero: true,
      minPhysiological: 5,
      maxPhysiological: 250,
      weight: 1.2,
    ),
    _MetricSpec(
      key: 'respiratory_rate',
      types: [HealthMetricType.respiratoryRate],
      aggregation: _Aggregation.median,
      minSpread: 1,
      percentSpread: 0.05,
      lowerBoundZero: true,
      minPhysiological: 6,
      maxPhysiological: 35,
      weight: 1.0,
    ),
    _MetricSpec(
      key: 'sleep_duration',
      types: [
        HealthMetricType.sleepAsleep,
        HealthMetricType.sleepDeep,
        HealthMetricType.sleepLight,
        HealthMetricType.sleepRem,
      ],
      aggregation: _Aggregation.sleepDuration,
      minSpread: 35,
      percentSpread: 0.08,
      lowerBoundZero: true,
      maxPhysiological: 900,
      weight: 1.0,
      partialUntilHourUtc: 10,
    ),
    _MetricSpec(
      key: 'deep_sleep',
      types: [HealthMetricType.sleepDeep],
      aggregation: _Aggregation.sum,
      minSpread: 18,
      percentSpread: 0.15,
      lowerBoundZero: true,
      maxPhysiological: 300,
      weight: 0.8,
      partialUntilHourUtc: 10,
    ),
    _MetricSpec(
      key: 'rem_sleep',
      types: [HealthMetricType.sleepRem],
      aggregation: _Aggregation.sum,
      minSpread: 18,
      percentSpread: 0.15,
      lowerBoundZero: true,
      maxPhysiological: 300,
      weight: 0.8,
      partialUntilHourUtc: 10,
    ),
    _MetricSpec(
      key: 'steps',
      types: [HealthMetricType.steps],
      aggregation: _Aggregation.sum,
      minSpread: 1000,
      percentSpread: 0.18,
      lowerBoundZero: true,
      weight: 0.75,
      partialUntilHourUtc: 20,
    ),
    _MetricSpec(
      key: 'active_energy',
      types: [HealthMetricType.activeEnergyBurned],
      aggregation: _Aggregation.sum,
      minSpread: 80,
      percentSpread: 0.18,
      lowerBoundZero: true,
      weight: 0.75,
      partialUntilHourUtc: 20,
    ),
    _MetricSpec(
      key: 'exercise_time',
      types: [HealthMetricType.exerciseTime],
      aggregation: _Aggregation.sum,
      minSpread: 12,
      percentSpread: 0.25,
      lowerBoundZero: true,
      maxPhysiological: 360,
      weight: 0.65,
      partialUntilHourUtc: 20,
    ),
    _MetricSpec(
      key: 'blood_oxygen',
      types: [HealthMetricType.bloodOxygen],
      aggregation: _Aggregation.median,
      minSpread: 1.2,
      percentSpread: 0.015,
      lowerBoundZero: true,
      minPhysiological: 70,
      maxPhysiological: 100,
      weight: 0.9,
    ),
    _MetricSpec(
      key: 'temperature',
      types: [
        HealthMetricType.sleepWristTemperature,
        HealthMetricType.skinTemperature,
        HealthMetricType.bodyTemperature,
      ],
      aggregation: _Aggregation.temperature,
      minSpread: 0.12,
      percentSpread: 0.004,
      lowerBoundZero: false,
      minPhysiological: 30,
      maxPhysiological: 42,
      weight: 0.9,
    ),
  ];

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
    HealthMetricType.sleepSession,
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepAwake,
    HealthMetricType.sleepAwakeInBed,
    HealthMetricType.sleepLight,
    HealthMetricType.sleepDeep,
    HealthMetricType.sleepRem,
    HealthMetricType.steps,
    HealthMetricType.distanceWalkingRunning,
    HealthMetricType.activeEnergyBurned,
    HealthMetricType.exerciseTime,
    HealthMetricType.workout,
    HealthMetricType.highHeartRateEvent,
    HealthMetricType.lowHeartRateEvent,
    HealthMetricType.irregularHeartRateEvent,
  };
}

class _DailyMetrics {
  final Map<String, double> values;
  final Map<String, int> sampleCounts;

  const _DailyMetrics({required this.values, required this.sampleCounts});
}

class _MetricSpec {
  final String key;
  final List<HealthMetricType> types;
  final _Aggregation aggregation;
  final double minSpread;
  final double percentSpread;
  final bool lowerBoundZero;
  final double weight;
  final double? minPhysiological;
  final double? maxPhysiological;
  final int? partialUntilHourUtc;

  const _MetricSpec({
    required this.key,
    required this.types,
    required this.aggregation,
    required this.minSpread,
    required this.percentSpread,
    required this.lowerBoundZero,
    required this.weight,
    this.minPhysiological,
    this.maxPhysiological,
    this.partialUntilHourUtc,
  });
}

enum _Aggregation { median, sum, hrv, temperature, sleepDuration }

class _MetricForecast {
  final double expected;
  final String method;

  const _MetricForecast({required this.expected, required this.method});
}

class _DatedValue {
  final DateTime day;
  final double value;

  const _DatedValue({required this.day, required this.value});
}

class _ReasonCandidate {
  final String code;
  final double impact;

  const _ReasonCandidate({required this.code, required this.impact});
}
