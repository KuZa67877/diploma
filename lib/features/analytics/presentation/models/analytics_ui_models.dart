class AnalyticsFilterUiModel {
  final String id;
  final String labelKey;

  const AnalyticsFilterUiModel({required this.id, required this.labelKey});
}

class AnalyticsChartPoint {
  final double x;
  final double y;
  final String label;

  const AnalyticsChartPoint({
    required this.x,
    required this.y,
    this.label = '',
  });
}

class AnalyticsBarData {
  final String label;
  final double value;

  const AnalyticsBarData({required this.label, required this.value});
}

enum AnalyticsMetricChartStyleUi {
  line,
  bar,
}

class AnalyticsMetricUiModel {
  final String id;
  final String titleKey;
  final String unit;
  final AnalyticsMetricChartStyleUi chartStyle;
  final List<AnalyticsChartPoint> points;
  final List<String> relatedMetricIds;
  final bool visibleByDefault;
  final double latestValue;
  final double averageValue;
  final double minValue;
  final double maxValue;

  const AnalyticsMetricUiModel({
    required this.id,
    required this.titleKey,
    required this.unit,
    required this.chartStyle,
    required this.points,
    required this.relatedMetricIds,
    required this.visibleByDefault,
    required this.latestValue,
    required this.averageValue,
    required this.minValue,
    required this.maxValue,
  });
}

class AnalyticsInsightUiModel {
  final String titleKey;
  final String descKey;
  final String severity;

  const AnalyticsInsightUiModel({
    required this.titleKey,
    required this.descKey,
    required this.severity,
  });
}

class AnalyticsViewData {
  final List<AnalyticsFilterUiModel> filters;
  final String selectedFilterId;
  final List<AnalyticsChartPoint> heartRate;
  final List<AnalyticsBarData> activity;
  final List<AnalyticsMetricUiModel> metricSeries;
  final List<String> featuredMetricIds;
  final List<AnalyticsInsightUiModel> insights;
  final int recordsCount;
  final int sourceCount;
  final int metricTypeCount;
  final int averageHeartRate;
  final int averageSteps;
  final double? sleepAiScore;
  final double sleepAiConfidence;
  final String sleepAiStatus;
  final String sleepAiReason;

  const AnalyticsViewData({
    required this.filters,
    required this.selectedFilterId,
    required this.heartRate,
    required this.activity,
    required this.metricSeries,
    required this.featuredMetricIds,
    required this.insights,
    required this.recordsCount,
    required this.sourceCount,
    required this.metricTypeCount,
    required this.averageHeartRate,
    required this.averageSteps,
    this.sleepAiScore,
    this.sleepAiConfidence = 0,
    this.sleepAiStatus = 'unavailable',
    this.sleepAiReason = 'not_available',
  });
}
