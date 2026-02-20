import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/activity_sample_model.dart';
import '../models/analytics_data_model.dart';
import '../models/analytics_filter_option_model.dart';
import '../models/analytics_insight_model.dart';
import '../models/heart_rate_sample_model.dart';

abstract class AnalyticsLocalDataSource {
  Future<AnalyticsDataModel> getAnalyticsData(String filterId);
}

class AnalyticsLocalDataSourceImpl implements AnalyticsLocalDataSource {
  static const String _assetPath = 'assets/data/analytics.json';

  @override
  Future<AnalyticsDataModel> getAnalyticsData(String filterId) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final filters = (decoded['filters'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => AnalyticsFilterOptionModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    final insights = (decoded['insights'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => AnalyticsInsightModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    final series = decoded['series'] as Map<String, dynamic>? ?? const {};
    final normalized = filters.any((f) => f.id == filterId) ? filterId : 'week';
    final selectedSeries =
        series[normalized] as Map<String, dynamic>? ?? const {};

    final heartRate = (selectedSeries['heartRate'] as List<dynamic>? ??
            const <dynamic>[])
        .map((item) => HeartRateSampleModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    final activity = (selectedSeries['activity'] as List<dynamic>? ??
            const <dynamic>[])
        .map((item) => ActivitySampleModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    return AnalyticsDataModel(
      filters: filters,
      selectedFilterId: normalized,
      heartRate: heartRate,
      activity: activity,
      insights: insights,
    );
  }
}
