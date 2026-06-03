import 'package:equatable/equatable.dart';
import 'activity_sample.dart';
import 'analytics_filter_option.dart';
import 'analytics_insight.dart';
import 'analytics_metric_series.dart';
import 'heart_rate_sample.dart';

class AnalyticsData extends Equatable {
  final List<AnalyticsFilterOption> filters;
  final String selectedFilterId;
  final List<HeartRateSample> heartRate;
  final List<ActivitySample> activity;
  final List<AnalyticsMetricSeries> metricSeries;
  final List<String> featuredMetricIds;
  final List<AnalyticsInsight> insights;
  final int recordsCount;
  final int sourceCount;
  final int metricTypeCount;
  final int averageHeartRate;
  final int averageSteps;
  final double? sleepAiScore;
  final double sleepAiConfidence;
  final String sleepAiStatus;
  final String sleepAiReason;

  const AnalyticsData({
    required this.filters,
    required this.selectedFilterId,
    required this.heartRate,
    required this.activity,
    this.metricSeries = const [],
    this.featuredMetricIds = const [],
    required this.insights,
    this.recordsCount = 0,
    this.sourceCount = 0,
    this.metricTypeCount = 0,
    this.averageHeartRate = 0,
    this.averageSteps = 0,
    this.sleepAiScore,
    this.sleepAiConfidence = 0,
    this.sleepAiStatus = 'unavailable',
    this.sleepAiReason = 'not_available',
  });

  @override
  List<Object> get props => [
    filters,
    selectedFilterId,
    heartRate,
    activity,
    metricSeries,
    featuredMetricIds,
    insights,
    recordsCount,
    sourceCount,
    metricTypeCount,
    averageHeartRate,
    averageSteps,
    sleepAiScore ?? -1,
    sleepAiConfidence,
    sleepAiStatus,
    sleepAiReason,
  ];
}
