import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../health_data/domain/entities/health_date_range.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/repositories/health_data_repository.dart';
import '../../domain/entities/activity_sample.dart';
import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/analytics_filter_option.dart';
import '../../domain/entities/analytics_insight.dart';
import '../../domain/entities/heart_rate_sample.dart';
import '../../domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final HealthDataRepository healthDataRepository;

  const AnalyticsRepositoryImpl({required this.healthDataRepository});

  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(
    String filterId,
  ) async {
    try {
      final normalizedFilter = _normalizeFilterId(filterId);
      final range = _rangeForFilter(normalizedFilter);
      final metricsResult = await healthDataRepository.getMetrics(
        HealthMetricsQuery(
          range: range,
          types: const [
            HealthMetricType.heartRate,
            HealthMetricType.steps,
            HealthMetricType.sleepAsleep,
            HealthMetricType.sleepDeep,
            HealthMetricType.weight,
          ],
        ),
      );

      return metricsResult.fold((failure) => Left(failure), (metrics) {
        final wearableMetrics = metrics
            .where((sample) => sample.sourceId != 'local_manual')
            .toList(growable: false);
        final heartRate = _buildHeartRate(wearableMetrics);
        final activity = _buildActivity(wearableMetrics, normalizedFilter);
        final averageHeartRate = _averageHeartRate(heartRate);
        final averageSteps = _averageSteps(activity);
        final insights = _buildInsights(
          metrics: wearableMetrics,
          averageHeartRate: averageHeartRate,
          averageSteps: averageSteps,
        );

        return Right(
          AnalyticsData(
            filters: _filters,
            selectedFilterId: normalizedFilter,
            heartRate: heartRate,
            activity: activity,
            insights: insights,
            recordsCount: wearableMetrics.length,
            sourceCount: wearableMetrics
                .map((sample) => sample.sourceId)
                .toSet()
                .length,
            metricTypeCount: wearableMetrics
                .map((sample) => sample.type)
                .toSet()
                .length,
            averageHeartRate: averageHeartRate,
            averageSteps: averageSteps,
          ),
        );
      });
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  String _normalizeFilterId(String filterId) {
    return switch (filterId) {
      'day' || 'week' || 'month' || 'year' => filterId,
      _ => 'week',
    };
  }

  HealthDateRange _rangeForFilter(String filterId) {
    final now = DateTime.now();
    final start = switch (filterId) {
      'day' => now.subtract(const Duration(days: 1)),
      'week' => now.subtract(const Duration(days: 7)),
      'month' => now.subtract(const Duration(days: 30)),
      'year' => now.subtract(const Duration(days: 365)),
      _ => now.subtract(const Duration(days: 7)),
    };
    return HealthDateRange(start: start, end: now);
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
