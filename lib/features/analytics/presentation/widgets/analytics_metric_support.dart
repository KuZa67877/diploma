import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/analytics_ui_models.dart';

extension AnalyticsViewDataX on AnalyticsViewData {
  AnalyticsMetricUiModel? metricById(String id) {
    for (final metric in metricSeries) {
      if (metric.id == id) {
        return metric;
      }
    }
    return null;
  }

  List<AnalyticsMetricUiModel> get featuredMetrics {
    final featured = featuredMetricIds
        .map(metricById)
        .whereType<AnalyticsMetricUiModel>()
        .toList(growable: false);
    return featured.isNotEmpty
        ? featured
        : metricSeries.take(4).toList(growable: false);
  }

  List<AnalyticsMetricUiModel> get additionalMetrics {
    final featuredIds = featuredMetrics.map((metric) => metric.id).toSet();
    return metricSeries
        .where((metric) => !featuredIds.contains(metric.id))
        .toList(growable: false);
  }
}

class AnalyticsMetricVisuals {
  const AnalyticsMetricVisuals._();

  static Color colorFor(String id) {
    return switch (id) {
      'heart_rate' => AppColors.primaryGlow,
      'steps' => const Color(0xFF7C8CF8),
      'sleep' => const Color(0xFF6EC5B8),
      'weight' => const Color(0xFF8B7CF6),
      'blood_oxygen' => const Color(0xFF24A3D8),
      'blood_pressure_systolic' => AppColors.warning,
      'blood_pressure_diastolic' => const Color(0xFFF97316),
      'respiratory_rate' => const Color(0xFFF59E0B),
      'body_temperature' => const Color(0xFFF87171),
      'active_energy' => AppColors.secondary,
      _ => AppColors.primary,
    };
  }

  static IconData iconFor(String id) {
    return switch (id) {
      'heart_rate' => Icons.favorite_outline_rounded,
      'steps' => Icons.directions_walk_rounded,
      'sleep' => Icons.bedtime_rounded,
      'weight' => Icons.monitor_weight_outlined,
      'blood_oxygen' => Icons.air_rounded,
      'blood_pressure_systolic' || 'blood_pressure_diastolic' =>
        Icons.monitor_heart_outlined,
      'respiratory_rate' => Icons.air_rounded,
      'body_temperature' => Icons.thermostat_rounded,
      'active_energy' => Icons.local_fire_department_outlined,
      _ => Icons.show_chart_rounded,
    };
  }
}

String formatMetricValue(double value, String unit) {
  return switch (unit) {
    'steps' => '${value.round()}',
    'bpm' => '${value.round()}',
    '%' => '${value.round()}',
    'mmHg' => '${value.round()}',
    'kg' => value.toStringAsFixed(1),
    '°C' => value.toStringAsFixed(1),
    'h' => value.toStringAsFixed(1),
    'kcal' => value.round().toString(),
    '/min' => value.toStringAsFixed(1),
    _ => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1),
  };
}

String formatMetricValueWithUnit(double value, String unit) {
  final formatted = formatMetricValue(value, unit);
  return switch (unit) {
    'steps' => '$formatted steps',
    '/min' => '$formatted /min',
    '' => formatted,
    _ => '$formatted $unit',
  };
}

class AnalyticsSparklineChart extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final bool isDark;

  const AnalyticsSparklineChart({
    super.key,
    required this.metric,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (metric.points.isEmpty) {
      return const SizedBox.shrink();
    }

    return switch (metric.chartStyle) {
      AnalyticsMetricChartStyleUi.bar => _SparkBarChart(
        metric: metric,
        isDark: isDark,
      ),
      AnalyticsMetricChartStyleUi.line => _SparkLineChart(
        metric: metric,
        isDark: isDark,
      ),
    };
  }
}

class AnalyticsSeriesChart extends StatelessWidget {
  final AnalyticsMetricUiModel primaryMetric;
  final List<AnalyticsMetricUiModel> compareMetrics;
  final bool normalized;
  final bool includeBarPane;
  final bool darkSurface;

  const AnalyticsSeriesChart({
    super.key,
    required this.primaryMetric,
    this.compareMetrics = const [],
    this.normalized = false,
    this.includeBarPane = false,
    this.darkSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryIsLine =
        primaryMetric.chartStyle == AnalyticsMetricChartStyleUi.line;
    final primaryIsBar =
        primaryMetric.chartStyle == AnalyticsMetricChartStyleUi.bar;
    final lineMetrics = <AnalyticsMetricUiModel>[
      if (primaryIsLine) primaryMetric,
      ...compareMetrics.where(
        (metric) => metric.chartStyle == AnalyticsMetricChartStyleUi.line,
      ),
    ];
    AnalyticsMetricUiModel? barMetric;
    if (includeBarPane) {
      if (primaryIsBar) {
        barMetric = primaryMetric;
      } else {
        for (final metric in compareMetrics) {
          if (metric.chartStyle == AnalyticsMetricChartStyleUi.bar) {
            barMetric = metric;
            break;
          }
        }
      }
    }

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 25,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: darkSurface
                        ? const Color(0xFF3B444D)
                        : AppColors.border.withValues(alpha: 0.7),
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: darkSurface
                        ? const Color(0xFF3B444D)
                        : AppColors.border.withValues(alpha: 0.55),
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineMetrics
                    .where((metric) => metric.points.isNotEmpty)
                    .map(
                      (metric) => LineChartBarData(
                        spots: _toNormalizedSpots(metric, normalized),
                        isCurved: true,
                        color: AnalyticsMetricVisuals.colorFor(metric.id),
                        barWidth: metric.id == primaryMetric.id ? 3.4 : 2.4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData:
                            metric.id == primaryMetric.id && primaryIsLine
                            ? BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AnalyticsMetricVisuals.colorFor(
                                      metric.id,
                                    ).withValues(alpha: 0.18),
                                    AnalyticsMetricVisuals.colorFor(
                                      metric.id,
                                    ).withValues(alpha: 0),
                                  ],
                                ),
                              )
                            : BarAreaData(show: false),
                      ),
                    )
                    .toList(growable: false),
                extraLinesData: lineMetrics.isEmpty
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 50,
                            color: darkSurface
                                ? const Color(0xFF3B444D)
                                : AppColors.border.withValues(alpha: 0.7),
                            strokeWidth: 1,
                            dashArray: const [3, 3],
                          ),
                        ],
                      )
                    : const ExtraLinesData(),
              ),
            ),
          ),
        ),
        if (barMetric != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: _SparkBarChart(
              metric: barMetric,
              isDark: darkSurface,
            ),
          ),
        ],
      ],
    );
  }

  List<FlSpot> _toNormalizedSpots(
    AnalyticsMetricUiModel metric,
    bool shouldNormalize,
  ) {
    final points = metric.points;
    if (points.isEmpty) {
      return const <FlSpot>[];
    }

    final min = metric.minValue;
    final max = metric.maxValue;
    final span = (max - min).abs();

    return points.map((point) {
      final y = shouldNormalize || span <= 0.001
          ? span <= 0.001
                ? 50.0
                : ((point.y - min) / span) * 100
          : point.y;
      return FlSpot(point.x, shouldNormalize ? y : _scaleToVisibleRange(metric, point.y));
    }).toList(growable: false);
  }

  double _scaleToVisibleRange(AnalyticsMetricUiModel metric, double value) {
    final span = (metric.maxValue - metric.minValue).abs();
    if (span <= 0.001) {
      return 50;
    }
    return ((value - metric.minValue) / span) * 100;
  }
}

class AnalyticsAxisLabels extends StatelessWidget {
  final List<AnalyticsChartPoint> points;
  final Color color;
  final int maxLabels;

  const AnalyticsAxisLabels({
    super.key,
    required this.points,
    required this.color,
    this.maxLabels = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final step = points.length <= maxLabels
        ? 1
        : (points.length / (maxLabels - 1)).ceil();
    final visible = <AnalyticsChartPoint>[];
    for (var index = 0; index < points.length; index += step) {
      visible.add(points[index]);
    }
    if (visible.last.label != points.last.label) {
      visible.add(points.last);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: visible
          .map(
            (point) => Text(
              point.label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SparkLineChart extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final bool isDark;

  const _SparkLineChart({
    required this.metric,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final spots = metric.points
        .map(
          (point) => FlSpot(
            point.x,
            _scaleToVisibleRange(point.y, metric.minValue, metric.maxValue),
          ),
        )
        .toList(growable: false);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AnalyticsMetricVisuals.colorFor(metric.id),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AnalyticsMetricVisuals.colorFor(metric.id).withValues(alpha: 0.12),
                  AnalyticsMetricVisuals.colorFor(metric.id).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkBarChart extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final bool isDark;

  const _SparkBarChart({
    required this.metric,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (metric.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = metric.points
        .map((point) => point.y)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: metric.points.take(8).toList(growable: false).asMap().entries.map(
        (entry) {
          final point = entry.value;
          final ratio = maxValue <= 0 ? 0.2 : (point.y / maxValue).clamp(0.18, 1.0);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: entry.key == metric.points.take(8).length - 1 ? 0 : 6),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 68 * ratio,
                  decoration: BoxDecoration(
                    color: AnalyticsMetricVisuals.colorFor(metric.id).withValues(
                      alpha: entry.key == metric.points.take(8).length - 2 ? 1 : 0.72,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          );
        },
      ).toList(growable: false),
    );
  }
}

double _scaleToVisibleRange(double value, double min, double max) {
  final span = (max - min).abs();
  if (span <= 0.001) {
    return 50;
  }
  return ((value - min) / span) * 100;
}
