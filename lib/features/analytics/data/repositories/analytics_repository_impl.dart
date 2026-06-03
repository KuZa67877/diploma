import 'package:dartz/dartz.dart';
import '../../../../core/constants/health_metric_catalog.dart';
import '../../../../core/error/failures.dart';
import '../../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../../health_data/domain/entities/health_date_range.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/repositories/health_data_repository.dart';
import '../../domain/entities/activity_sample.dart';
import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/analytics_filter_option.dart';
import '../../domain/entities/analytics_insight.dart';
import '../../domain/entities/analytics_metric_series.dart';
import '../../domain/entities/heart_rate_sample.dart';
import '../../domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final HealthDataRepository healthDataRepository;
  final HealthModelOutputRemoteDataSource modelOutputRemoteDataSource;

  const AnalyticsRepositoryImpl({
    required this.healthDataRepository,
    required this.modelOutputRemoteDataSource,
  });

  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(
    String filterId,
  ) async {
    try {
      final now = DateTime.now();
      final normalizedFilter = _normalizeFilterId(filterId);
      var anchor = now;
      var analyticsMetrics = await _loadAnalyticsMetrics(
        _rangeForFilter(normalizedFilter, now: now),
      );
      if (analyticsMetrics.isEmpty) {
        final fallbackMetrics = await _loadAnalyticsMetrics(
          _analyticsDiscoveryRange(now),
        );
        if (fallbackMetrics.isNotEmpty) {
          anchor = _latestMetricTimestamp(fallbackMetrics) ?? now;
          analyticsMetrics = _filterMetricsToRange(
            fallbackMetrics,
            _rangeForFilter(normalizedFilter, now: anchor),
          );
        }
      } else {
        anchor = _latestMetricTimestamp(analyticsMetrics) ?? now;
      }

      final heartRate = _buildHeartRate(analyticsMetrics);
      final activity = _buildActivity(analyticsMetrics, normalizedFilter);
      final metricSeries = _buildMetricSeries(
        analyticsMetrics,
        normalizedFilter,
        anchor,
      );
      final averageHeartRate = _averageHeartRate(heartRate);
      final averageSteps = _averageSteps(activity);
      final insights = _buildInsights(
        metrics: analyticsMetrics,
        averageHeartRate: averageHeartRate,
        averageSteps: averageSteps,
      );
      final sleepAi = await _resolveSleepAiFromOutputs();

      return Right(
        AnalyticsData(
          filters: _filters,
          selectedFilterId: normalizedFilter,
          heartRate: heartRate,
          activity: activity,
          metricSeries: metricSeries,
          featuredMetricIds: _buildFeaturedMetricIds(metricSeries),
          insights: insights,
          recordsCount: analyticsMetrics.length,
          sourceCount: analyticsMetrics
              .map((sample) => sample.sourceId)
              .toSet()
              .length,
          metricTypeCount: analyticsMetrics
              .map((sample) => sample.type)
              .toSet()
              .length,
          averageHeartRate: averageHeartRate,
          averageSteps: averageSteps,
          sleepAiScore: sleepAi.score,
          sleepAiConfidence: sleepAi.confidence,
          sleepAiStatus: sleepAi.status,
          sleepAiReason: sleepAi.reason,
        ),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  static const List<HealthMetricType> _analyticsMetricTypes = [
    ...HealthMetricCatalog.project54PriorityTypes,
    HealthMetricType.sleepAsleep,
    HealthMetricType.sleepDeep,
  ];

  static const List<_MetricBlueprint> _metricBlueprints = [
    _MetricBlueprint(
      id: 'heart_rate',
      titleKey: 'heartRate',
      types: [HealthMetricType.heartRate],
      unit: 'bpm',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.average,
      relatedMetricIds: ['steps', 'sleep', 'blood_oxygen', 'respiratory_rate'],
      visibleByDefault: true,
    ),
    _MetricBlueprint(
      id: 'steps',
      titleKey: 'steps',
      types: [HealthMetricType.steps],
      unit: 'steps',
      chartStyle: AnalyticsMetricChartStyle.bar,
      aggregation: _MetricAggregation.sum,
      relatedMetricIds: ['heart_rate', 'active_energy', 'sleep', 'weight'],
      visibleByDefault: true,
    ),
    _MetricBlueprint(
      id: 'sleep',
      titleKey: 'sleep',
      types: [HealthMetricType.sleep, HealthMetricType.sleepAsleep],
      unit: 'h',
      chartStyle: AnalyticsMetricChartStyle.bar,
      aggregation: _MetricAggregation.sum,
      relatedMetricIds: ['heart_rate', 'steps', 'blood_oxygen', 'weight'],
      visibleByDefault: true,
    ),
    _MetricBlueprint(
      id: 'weight',
      titleKey: 'weight',
      types: [HealthMetricType.weight],
      unit: 'kg',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.latest,
      relatedMetricIds: ['active_energy', 'steps', 'sleep', 'body_temperature'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'blood_oxygen',
      titleKey: 'bloodOxygen',
      types: [HealthMetricType.bloodOxygen],
      unit: '%',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.average,
      relatedMetricIds: ['heart_rate', 'respiratory_rate', 'sleep'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'blood_pressure_systolic',
      titleKey: 'bloodPressureSystolic',
      types: [HealthMetricType.bloodPressureSystolic],
      unit: 'mmHg',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.latest,
      relatedMetricIds: ['blood_pressure_diastolic', 'heart_rate', 'weight'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'blood_pressure_diastolic',
      titleKey: 'bloodPressureDiastolic',
      types: [HealthMetricType.bloodPressureDiastolic],
      unit: 'mmHg',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.latest,
      relatedMetricIds: ['blood_pressure_systolic', 'heart_rate', 'weight'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'respiratory_rate',
      titleKey: 'respiratoryRate',
      types: [HealthMetricType.respiratoryRate],
      unit: '/min',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.average,
      relatedMetricIds: ['blood_oxygen', 'heart_rate', 'sleep'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'body_temperature',
      titleKey: 'bodyTemperature',
      types: [HealthMetricType.bodyTemperature],
      unit: '°C',
      chartStyle: AnalyticsMetricChartStyle.line,
      aggregation: _MetricAggregation.latest,
      relatedMetricIds: ['sleep', 'heart_rate', 'respiratory_rate'],
      visibleByDefault: false,
    ),
    _MetricBlueprint(
      id: 'active_energy',
      titleKey: 'activeEnergyBurned',
      types: [HealthMetricType.activeEnergyBurned],
      unit: 'kcal',
      chartStyle: AnalyticsMetricChartStyle.bar,
      aggregation: _MetricAggregation.sum,
      relatedMetricIds: ['steps', 'heart_rate', 'weight'],
      visibleByDefault: false,
    ),
  ];

  String _normalizeFilterId(String filterId) {
    return switch (filterId) {
      'day' || 'week' || 'month' || 'year' => filterId,
      _ => 'week',
    };
  }

  HealthDateRange _rangeForFilter(String filterId, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final start = switch (filterId) {
      'day' => current.subtract(const Duration(days: 1)),
      'week' => current.subtract(const Duration(days: 7)),
      'month' => current.subtract(const Duration(days: 30)),
      'year' => current.subtract(const Duration(days: 365)),
      _ => current.subtract(const Duration(days: 7)),
    };
    return HealthDateRange(start: start, end: current);
  }

  HealthDateRange _analyticsDiscoveryRange(DateTime now) {
    return HealthDateRange(
      start: now.subtract(const Duration(days: 400)),
      end: now,
    );
  }

  Future<List<HealthMetricSample>> _loadAnalyticsMetrics(
    HealthDateRange range,
  ) async {
    final connectedResult = await healthDataRepository.getMetrics(
      HealthMetricsQuery(range: range, types: _analyticsMetricTypes),
    );
    final localResult = await healthDataRepository.getMetrics(
      HealthMetricsQuery(
        range: range,
        types: _analyticsMetricTypes,
        sourceId: 'local_manual',
        onlyConnectedSources: false,
      ),
    );

    Failure? failure;
    List<HealthMetricSample>? connectedMetrics;
    List<HealthMetricSample>? localMetrics;

    connectedResult.fold(
      (resultFailure) => failure = resultFailure,
      (value) => connectedMetrics = value,
    );
    localResult.fold(
      (resultFailure) => failure ??= resultFailure,
      (value) => localMetrics = value,
    );

    if (failure != null) {
      throw failure!;
    }

    final deduped = <String, HealthMetricSample>{};
    for (final sample in [...?connectedMetrics, ...?localMetrics]) {
      deduped[sample.id] = sample;
    }
    return deduped.values.toList(growable: false);
  }

  DateTime? _latestMetricTimestamp(List<HealthMetricSample> metrics) {
    if (metrics.isEmpty) {
      return null;
    }

    var latest = metrics.first.timestamp;
    for (final sample in metrics.skip(1)) {
      if (sample.timestamp.isAfter(latest)) {
        latest = sample.timestamp;
      }
    }
    return latest;
  }

  List<HealthMetricSample> _filterMetricsToRange(
    List<HealthMetricSample> metrics,
    HealthDateRange range,
  ) {
    return metrics.where((sample) {
      final start = sample.startAt;
      final end = sample.endAt;
      return !end.isBefore(range.start) && !start.isAfter(range.end);
    }).toList(growable: false);
  }

  List<HeartRateSample> _buildHeartRate(List<HealthMetricSample> metrics) {
    final heartRates = metrics
        .where((sample) => sample.type == HealthMetricType.heartRate)
        .toList();

    final Map<int, List<double>> byHour = {};
    for (final sample in heartRates) {
      final hour = sample.timestamp.hour;
      byHour.putIfAbsent(hour, () => []).add(sample.value);
    }

    final points = byHour.entries.map((entry) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return HeartRateSample(hour: entry.key, bpm: avg.round());
    }).toList();

    points.sort((a, b) => a.hour.compareTo(b.hour));
    return points;
  }

  int _averageHeartRate(List<HeartRateSample> points) {
    if (points.isEmpty) {
      return 0;
    }
    final total = points.map((point) => point.bpm).reduce((a, b) => a + b);
    return (total / points.length).round();
  }

  List<ActivitySample> _buildActivity(
    List<HealthMetricSample> metrics,
    String filterId,
  ) {
    final stepsSamples = metrics
        .where((sample) => sample.type == HealthMetricType.steps)
        .toList();

    if (stepsSamples.isEmpty) return const [];

    return switch (filterId) {
      'month' => _buildMonthlyActivity(stepsSamples),
      'year' => _buildYearlyActivity(stepsSamples),
      _ => _buildWeeklyActivity(stepsSamples),
    };
  }

  int _averageSteps(List<ActivitySample> activity) {
    if (activity.isEmpty) {
      return 0;
    }
    final total = activity.map((item) => item.steps).reduce((a, b) => a + b);
    return (total / activity.length).round();
  }

  List<AnalyticsMetricSeries> _buildMetricSeries(
    List<HealthMetricSample> metrics,
    String filterId,
    DateTime now,
  ) {
    final buckets = _buildBuckets(filterId, now);

    return _metricBlueprints
        .map((blueprint) => _buildSeriesForBlueprint(blueprint, metrics, buckets))
        .whereType<AnalyticsMetricSeries>()
        .toList(growable: false);
  }

  AnalyticsMetricSeries? _buildSeriesForBlueprint(
    _MetricBlueprint blueprint,
    List<HealthMetricSample> metrics,
    List<_TimeBucket> buckets,
  ) {
    final relevant = metrics
        .where((sample) => blueprint.types.contains(sample.type))
        .toList(growable: false);
    if (relevant.isEmpty) {
      return null;
    }

    final points = <AnalyticsMetricPoint>[];

    for (final bucket in buckets) {
      final bucketSamples = relevant
          .where(
            (sample) =>
                !sample.timestamp.isBefore(bucket.start) &&
                sample.timestamp.isBefore(bucket.end),
          )
          .toList(growable: false);
      if (bucketSamples.isEmpty && blueprint.chartStyle == AnalyticsMetricChartStyle.line) {
        continue;
      }

      final value = bucketSamples.isEmpty
          ? 0.0
          : _aggregateBucketValues(bucketSamples, blueprint.aggregation);
      points.add(
        AnalyticsMetricPoint(
          x: bucket.index.toDouble(),
          value: value,
          label: bucket.label,
        ),
      );
    }

    final populated = points.where((point) => point.value > 0).toList(growable: false);
    if (populated.isEmpty) {
      return null;
    }

    final values = populated.map((point) => point.value).toList(growable: false);
    final latest = populated.last.value;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final averageValue = values.reduce((a, b) => a + b) / values.length;

    return AnalyticsMetricSeries(
      id: blueprint.id,
      titleKey: blueprint.titleKey,
      unit: blueprint.unit,
      chartStyle: blueprint.chartStyle,
      points: points,
      relatedMetricIds: blueprint.relatedMetricIds,
      visibleByDefault: blueprint.visibleByDefault,
      latestValue: latest,
      averageValue: averageValue,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  double _aggregateBucketValues(
    List<HealthMetricSample> samples,
    _MetricAggregation aggregation,
  ) {
    final normalized = samples
        .map(_normalizeSampleValue)
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return 0;
    }

    return switch (aggregation) {
      _MetricAggregation.sum => normalized.reduce((a, b) => a + b),
      _MetricAggregation.average =>
        normalized.reduce((a, b) => a + b) / normalized.length,
      _MetricAggregation.latest => normalized.last,
    };
  }

  double _normalizeSampleValue(HealthMetricSample sample) {
    final unit = sample.unit.toLowerCase();
    return switch (sample.type) {
      HealthMetricType.sleepAsleep || HealthMetricType.sleepDeep => unit.contains('sec')
          ? sample.value / 3600
          : unit.contains('min')
          ? sample.value / 60
          : sample.value,
      HealthMetricType.distanceWalkingRunning =>
        unit.contains('km') ? sample.value : sample.value / 1000,
      HealthMetricType.bodyTemperature when unit.contains('f') =>
        (sample.value - 32) * 5 / 9,
      _ => sample.value,
    };
  }

  List<String> _buildFeaturedMetricIds(List<AnalyticsMetricSeries> series) {
    final availableIds = series.map((item) => item.id).toSet();
    const preferred = ['heart_rate', 'steps', 'sleep', 'weight'];
    final featured = preferred
        .where(availableIds.contains)
        .take(4)
        .toList(growable: false);
    return featured.isNotEmpty
        ? featured
        : series.take(4).map((item) => item.id).toList(growable: false);
  }

  List<_TimeBucket> _buildBuckets(String filterId, DateTime now) {
    return switch (filterId) {
      'day' => _buildDayBuckets(now),
      'month' => _buildMonthBuckets(now),
      'year' => _buildYearBuckets(now),
      _ => _buildWeekBuckets(now),
    };
  }

  List<_TimeBucket> _buildDayBuckets(DateTime now) {
    final end = DateTime(now.year, now.month, now.day, now.hour + 1);
    final start = end.subtract(const Duration(hours: 24));
    return List.generate(8, (index) {
      final bucketStart = start.add(Duration(hours: index * 3));
      final bucketEnd = bucketStart.add(const Duration(hours: 3));
      return _TimeBucket(
        index: index,
        start: bucketStart,
        end: bucketEnd,
        label: bucketStart.hour.toString().padLeft(2, '0'),
      );
    }, growable: false);
  }

  List<_TimeBucket> _buildWeekBuckets(DateTime now) {
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (index) {
      final bucketStart = start.add(Duration(days: index));
      final bucketEnd = bucketStart.add(const Duration(days: 1));
      return _TimeBucket(
        index: index,
        start: bucketStart,
        end: bucketEnd,
        label: labels[bucketStart.weekday - 1],
      );
    }, growable: false);
  }

  List<_TimeBucket> _buildMonthBuckets(DateTime now) {
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 28));
    return List.generate(4, (index) {
      final bucketStart = start.add(Duration(days: index * 7));
      final bucketEnd = bucketStart.add(const Duration(days: 7));
      return _TimeBucket(
        index: index,
        start: bucketStart,
        end: bucketEnd,
        label: 'W${index + 1}',
      );
    }, growable: false);
  }

  List<_TimeBucket> _buildYearBuckets(DateTime now) {
    final currentMonth = DateTime(now.year, now.month);
    final labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return List.generate(12, (index) {
      final monthStart = _addMonths(currentMonth, -(11 - index));
      final monthEnd = _addMonths(monthStart, 1);
      return _TimeBucket(
        index: index,
        start: monthStart,
        end: monthEnd,
        label: labels[monthStart.month - 1],
      );
    }, growable: false);
  }

  DateTime _addMonths(DateTime value, int months) {
    final year = value.year + ((value.month - 1 + months) ~/ 12);
    final month = (value.month - 1 + months) % 12 + 1;
    return DateTime(year, month);
  }

  List<AnalyticsInsight> _buildInsights({
    required List<HealthMetricSample> metrics,
    required int averageHeartRate,
    required int averageSteps,
  }) {
    if (metrics.isEmpty) {
      return const [
        AnalyticsInsight(
          type: 'info',
          titleKey: 'activityGoalAtRisk',
          descKey: 'activityGoalDesc',
          severity: 'info',
        ),
      ];
    }

    final result = <AnalyticsInsight>[];
    if (averageHeartRate >= 95 && averageHeartRate > 0) {
      result.add(
        const AnalyticsInsight(
          type: 'anomaly',
          titleKey: 'elevatedHeartRate',
          descKey: 'elevatedHeartRateDesc',
          severity: 'warning',
        ),
      );
    }

    if (averageSteps >= 7000) {
      result.add(
        const AnalyticsInsight(
          type: 'positive',
          titleKey: 'sleepQualityImproving',
          descKey: 'sleepQualityDesc',
          severity: 'success',
        ),
      );
    } else if (averageSteps > 0 && averageSteps < 7000) {
      result.add(
        const AnalyticsInsight(
          type: 'prediction',
          titleKey: 'activityGoalAtRisk',
          descKey: 'activityGoalDesc',
          severity: 'info',
        ),
      );
    }

    if (result.isEmpty) {
      result.add(
        const AnalyticsInsight(
          type: 'info',
          titleKey: 'sleepQualityImproving',
          descKey: 'sleepQualityDesc',
          severity: 'success',
        ),
      );
    }

    return result;
  }

  static const List<AnalyticsFilterOption> _filters = [
    AnalyticsFilterOption(id: 'day', labelKey: 'day'),
    AnalyticsFilterOption(id: 'week', labelKey: 'week'),
    AnalyticsFilterOption(id: 'month', labelKey: 'month'),
    AnalyticsFilterOption(id: 'year', labelKey: 'year'),
  ];

  Future<_SleepAiSnapshot> _resolveSleepAiFromOutputs() async {
    try {
      final outputs = await modelOutputRemoteDataSource
          .getLatestOutputsByModelIds(const ['sleep_quality']);
      final record = outputs['sleep_quality'];
      if (record == null) {
        return const _SleepAiSnapshot(
          score: null,
          confidence: 0,
          status: 'unavailable',
          reason: 'sleep_model_output_missing',
        );
      }

      return _SleepAiSnapshot(
        score: _normalizeSleepScore(record.score),
        confidence: record.confidence,
        status: switch (record.status) {
          'ready' || 'ok' => 'ok',
          'insufficient' => 'insufficient',
          _ => 'unavailable',
        },
        reason: record.reason ?? 'sleep_model_output_missing',
      );
    } on Failure {
      return const _SleepAiSnapshot(
        score: null,
        confidence: 0,
        status: 'unavailable',
        reason: 'sleep_model_output_unavailable',
      );
    } catch (_) {
      return const _SleepAiSnapshot(
        score: null,
        confidence: 0,
        status: 'unavailable',
        reason: 'sleep_model_output_unavailable',
      );
    }
  }

  double? _normalizeSleepScore(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return value.clamp(0.0, 100.0);
  }

  List<ActivitySample> _buildWeeklyActivity(List<HealthMetricSample> samples) {
    final labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Map<int, int> buckets = {for (var i = 1; i <= 7; i++) i: 0};

    for (final sample in samples) {
      final weekday = sample.timestamp.weekday;
      buckets[weekday] = (buckets[weekday] ?? 0) + sample.value.round();
    }

    return List.generate(
      7,
      (index) =>
          ActivitySample(label: labels[index], steps: buckets[index + 1] ?? 0),
      growable: false,
    );
  }

  List<ActivitySample> _buildMonthlyActivity(List<HealthMetricSample> samples) {
    final Map<int, int> buckets = {1: 0, 2: 0, 3: 0, 4: 0};

    for (final sample in samples) {
      final day = sample.timestamp.day;
      final bucket = switch (day) {
        <= 7 => 1,
        <= 14 => 2,
        <= 21 => 3,
        _ => 4,
      };
      buckets[bucket] = (buckets[bucket] ?? 0) + sample.value.round();
    }

    return List.generate(
      4,
      (index) => ActivitySample(
        label: 'W${index + 1}',
        steps: buckets[index + 1] ?? 0,
      ),
      growable: false,
    );
  }

  List<ActivitySample> _buildYearlyActivity(List<HealthMetricSample> samples) {
    final Map<int, int> buckets = {1: 0, 2: 0, 3: 0, 4: 0};

    for (final sample in samples) {
      final month = sample.timestamp.month;
      final quarter = ((month - 1) ~/ 3) + 1;
      buckets[quarter] = (buckets[quarter] ?? 0) + sample.value.round();
    }

    return List.generate(
      4,
      (index) => ActivitySample(
        label: 'Q${index + 1}',
        steps: buckets[index + 1] ?? 0,
      ),
      growable: false,
    );
  }
}

enum _MetricAggregation {
  average,
  sum,
  latest,
}

class _MetricBlueprint {
  final String id;
  final String titleKey;
  final List<HealthMetricType> types;
  final String unit;
  final AnalyticsMetricChartStyle chartStyle;
  final _MetricAggregation aggregation;
  final List<String> relatedMetricIds;
  final bool visibleByDefault;

  const _MetricBlueprint({
    required this.id,
    required this.titleKey,
    required this.types,
    required this.unit,
    required this.chartStyle,
    required this.aggregation,
    required this.relatedMetricIds,
    required this.visibleByDefault,
  });
}

class _TimeBucket {
  final int index;
  final DateTime start;
  final DateTime end;
  final String label;

  const _TimeBucket({
    required this.index,
    required this.start,
    required this.end,
    required this.label,
  });
}

class _SleepAiSnapshot {
  final double? score;
  final double confidence;
  final String status;
  final String reason;

  const _SleepAiSnapshot({
    required this.score,
    required this.confidence,
    required this.status,
    required this.reason,
  });
}
