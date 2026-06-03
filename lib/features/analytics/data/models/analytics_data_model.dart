import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/analytics_metric_series.dart';
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
    super.metricSeries,
    super.featuredMetricIds,
    required super.insights,
    super.sleepAiScore,
    super.sleepAiConfidence,
    super.sleepAiStatus,
    super.sleepAiReason,
  });

  factory AnalyticsDataModel.fromJson(Map<String, dynamic> json) {
    final filters =
        (json['filters'] as List<dynamic>?)
            ?.map(
              (item) => AnalyticsFilterOptionModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList() ??
        const <AnalyticsFilterOptionModel>[];

    final heartRate =
        (json['heartRate'] as List<dynamic>?)
            ?.map(
              (item) =>
                  HeartRateSampleModel.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const <HeartRateSampleModel>[];

    final activity =
        (json['activity'] as List<dynamic>?)
            ?.map(
              (item) =>
                  ActivitySampleModel.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const <ActivitySampleModel>[];

    final insights =
        (json['insights'] as List<dynamic>?)
            ?.map(
              (item) =>
                  AnalyticsInsightModel.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const <AnalyticsInsightModel>[];

    final metricSeries =
        (json['metricSeries'] as List<dynamic>?)
            ?.map(
              (item) => _metricSeriesFromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        const <AnalyticsMetricSeries>[];

    final featuredMetricIds =
        (json['featuredMetricIds'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return AnalyticsDataModel(
      filters: filters,
      selectedFilterId: json['selectedFilterId']?.toString() ?? '',
      heartRate: heartRate,
      activity: activity,
      metricSeries: metricSeries,
      featuredMetricIds: featuredMetricIds,
      insights: insights,
      sleepAiScore: (json['sleepAiScore'] as num?)?.toDouble(),
      sleepAiConfidence: (json['sleepAiConfidence'] as num?)?.toDouble() ?? 0,
      sleepAiStatus: json['sleepAiStatus']?.toString() ?? 'unavailable',
      sleepAiReason: json['sleepAiReason']?.toString() ?? 'not_available',
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
      'metricSeries': metricSeries.map(_metricSeriesToJson).toList(),
      'featuredMetricIds': featuredMetricIds,
      'insights': insights
          .map((item) => (item as AnalyticsInsightModel).toJson())
          .toList(),
      'sleepAiScore': sleepAiScore,
      'sleepAiConfidence': sleepAiConfidence,
      'sleepAiStatus': sleepAiStatus,
      'sleepAiReason': sleepAiReason,
    };
  }
}

AnalyticsMetricSeries _metricSeriesFromJson(Map<String, dynamic> json) {
  final points =
      (json['points'] as List<dynamic>?)
          ?.map((item) {
            final data = item as Map<String, dynamic>;
            return AnalyticsMetricPoint(
              x: (data['x'] as num?)?.toDouble() ?? 0,
              value: (data['value'] as num?)?.toDouble() ?? 0,
              label: data['label']?.toString() ?? '',
            );
          })
          .toList() ??
      const <AnalyticsMetricPoint>[];

  return AnalyticsMetricSeries(
    id: json['id']?.toString() ?? '',
    titleKey: json['titleKey']?.toString() ?? '',
    unit: json['unit']?.toString() ?? '',
    chartStyle:
        json['chartStyle'] == AnalyticsMetricChartStyle.bar.name
        ? AnalyticsMetricChartStyle.bar
        : AnalyticsMetricChartStyle.line,
    points: points,
    relatedMetricIds:
        (json['relatedMetricIds'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[],
    visibleByDefault: json['visibleByDefault'] as bool? ?? true,
    latestValue: (json['latestValue'] as num?)?.toDouble() ?? 0,
    averageValue: (json['averageValue'] as num?)?.toDouble() ?? 0,
    minValue: (json['minValue'] as num?)?.toDouble() ?? 0,
    maxValue: (json['maxValue'] as num?)?.toDouble() ?? 0,
  );
}

Map<String, dynamic> _metricSeriesToJson(AnalyticsMetricSeries series) {
  return {
    'id': series.id,
    'titleKey': series.titleKey,
    'unit': series.unit,
    'chartStyle': series.chartStyle.name,
    'points': series.points
        .map((item) => {
          'x': item.x,
          'value': item.value,
          'label': item.label,
        })
        .toList(),
    'relatedMetricIds': series.relatedMetricIds,
    'visibleByDefault': series.visibleByDefault,
    'latestValue': series.latestValue,
    'averageValue': series.averageValue,
    'minValue': series.minValue,
    'maxValue': series.maxValue,
  };
}
