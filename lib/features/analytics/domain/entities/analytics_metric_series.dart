import 'package:equatable/equatable.dart';

enum AnalyticsMetricChartStyle {
  line,
  bar,
}

class AnalyticsMetricPoint extends Equatable {
  final double x;
  final double value;
  final String label;

  const AnalyticsMetricPoint({
    required this.x,
    required this.value,
    required this.label,
  });

  @override
  List<Object> get props => [x, value, label];
}

class AnalyticsMetricSeries extends Equatable {
  final String id;
  final String titleKey;
  final String unit;
  final AnalyticsMetricChartStyle chartStyle;
  final List<AnalyticsMetricPoint> points;
  final List<String> relatedMetricIds;
  final bool visibleByDefault;
  final double latestValue;
  final double averageValue;
  final double minValue;
  final double maxValue;

  const AnalyticsMetricSeries({
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

  @override
  List<Object> get props => [
    id,
    titleKey,
    unit,
    chartStyle,
    points,
    relatedMetricIds,
    visibleByDefault,
    latestValue,
    averageValue,
    minValue,
    maxValue,
  ];
}
