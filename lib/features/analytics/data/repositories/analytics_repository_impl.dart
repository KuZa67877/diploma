import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../health_data/domain/entities/health_date_range.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/repositories/health_data_repository.dart';
import '../../domain/entities/activity_sample.dart';
import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/heart_rate_sample.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_local_data_source.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsLocalDataSource localDataSource;
  final HealthDataRepository healthDataRepository;

  const AnalyticsRepositoryImpl({
    required this.localDataSource,
    required this.healthDataRepository,
  });

  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(String filterId) async {
    try {
      final base = await localDataSource.getAnalyticsData(filterId);
      final range = _rangeForFilter(base.selectedFilterId);
      final metricsResult = await healthDataRepository.getMetrics(
        HealthMetricsQuery(
          range: range,
          types: const [
            HealthMetricType.heartRate,
            HealthMetricType.steps,
          ],
        ),
      );

      return metricsResult.fold(
        (_) => Right(base),
        (metrics) {
          final heartRate = _buildHeartRate(metrics);
          final activity = _buildActivity(metrics, base.selectedFilterId);
          return Right(
            AnalyticsData(
              filters: base.filters,
              selectedFilterId: base.selectedFilterId,
              heartRate: heartRate.isEmpty ? base.heartRate : heartRate,
              activity: activity.isEmpty ? base.activity : activity,
              insights: base.insights,
            ),
          );
        },
      );
    } catch (_) {
      return const Left(CacheFailure());
    }
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

    final points = byHour.entries
        .map((entry) {
          final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
          return HeartRateSample(
            hour: entry.key,
            bpm: avg.round(),
          );
        })
        .toList();

    points.sort((a, b) => a.hour.compareTo(b.hour));
    return points;
  }

  List<ActivitySample> _buildActivity(
    List<HealthMetricSample> metrics,
    String filterId,
  ) {
    final stepsSamples =
        metrics.where((sample) => sample.type == HealthMetricType.steps).toList();

    if (stepsSamples.isEmpty) return const [];

    return switch (filterId) {
      'month' => _buildMonthlyActivity(stepsSamples),
      'year' => _buildYearlyActivity(stepsSamples),
      _ => _buildWeeklyActivity(stepsSamples),
    };
  }

  List<ActivitySample> _buildWeeklyActivity(List<HealthMetricSample> samples) {
    final labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Map<int, int> buckets = {
      for (var i = 1; i <= 7; i++) i: 0,
    };

    for (final sample in samples) {
      final weekday = sample.timestamp.weekday;
      buckets[weekday] = (buckets[weekday] ?? 0) + sample.value.round();
    }

    return List.generate(
      7,
      (index) => ActivitySample(
        label: labels[index],
        steps: buckets[index + 1] ?? 0,
      ),
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
