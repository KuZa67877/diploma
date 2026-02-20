import '../../domain/entities/analytics_data.dart';
import 'activity_sample_model.dart';
import 'analytics_filter_option_model.dart';
import 'analytics_insight_model.dart';
import 'heart_rate_sample_model.dart';

class AnalyticsDataModel extends AnalyticsData {
  const AnalyticsDataModel({
    required super.filters,
    required super.selectedFilterId,
    required super.heartRate,
    required super.activity,
    required super.insights,
  });

  factory AnalyticsDataModel.fromJson(Map<String, dynamic> json) {
    final filters = (json['filters'] as List<dynamic>?)
            ?.map((item) => AnalyticsFilterOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <AnalyticsFilterOptionModel>[];

    final heartRate = (json['heartRate'] as List<dynamic>?)
            ?.map((item) => HeartRateSampleModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <HeartRateSampleModel>[];

    final activity = (json['activity'] as List<dynamic>?)
            ?.map((item) => ActivitySampleModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <ActivitySampleModel>[];

    final insights = (json['insights'] as List<dynamic>?)
            ?.map((item) => AnalyticsInsightModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <AnalyticsInsightModel>[];

    return AnalyticsDataModel(
      filters: filters,
      selectedFilterId: json['selectedFilterId']?.toString() ?? '',
      heartRate: heartRate,
      activity: activity,
      insights: insights,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filters': filters
          .map((item) => (item as AnalyticsFilterOptionModel).toJson())
          .toList(),
      'selectedFilterId': selectedFilterId,
      'heartRate': heartRate
          .map((item) => (item as HeartRateSampleModel).toJson())
          .toList(),
      'activity': activity
          .map((item) => (item as ActivitySampleModel).toJson())
          .toList(),
      'insights': insights
          .map((item) => (item as AnalyticsInsightModel).toJson())
          .toList(),
    };
  }
}
