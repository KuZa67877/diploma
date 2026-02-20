import 'package:equatable/equatable.dart';
import 'activity_sample.dart';
import 'analytics_filter_option.dart';
import 'analytics_insight.dart';
import 'heart_rate_sample.dart';

class AnalyticsData extends Equatable {
  final List<AnalyticsFilterOption> filters;
  final String selectedFilterId;
  final List<HeartRateSample> heartRate;
  final List<ActivitySample> activity;
  final List<AnalyticsInsight> insights;

  const AnalyticsData({
    required this.filters,
    required this.selectedFilterId,
    required this.heartRate,
    required this.activity,
    required this.insights,
  });

  @override
  List<Object> get props => [filters, selectedFilterId, heartRate, activity, insights];
}
