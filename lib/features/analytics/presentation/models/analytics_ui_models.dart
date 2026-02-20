class AnalyticsFilterUiModel {
  final String id;
  final String labelKey;

  const AnalyticsFilterUiModel({
    required this.id,
    required this.labelKey,
  });
}

class AnalyticsChartPoint {
  final double x;
  final double y;

  const AnalyticsChartPoint({
    required this.x,
    required this.y,
  });
}

class AnalyticsBarData {
  final String label;
  final int steps;

  const AnalyticsBarData({
    required this.label,
    required this.steps,
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
  final List<AnalyticsInsightUiModel> insights;

  const AnalyticsViewData({
    required this.filters,
    required this.selectedFilterId,
    required this.heartRate,
    required this.activity,
    required this.insights,
  });
}
