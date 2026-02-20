import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';

enum ChartTrend { up, down, stable }

class MiniChart extends StatelessWidget {
  final List<double> data;
  final ChartTrend trend;

  const MiniChart({
    super.key,
    required this.data,
    required this.trend,
  });

  Color get _trendColor {
    switch (trend) {
      case ChartTrend.up:
        return AppColors.success;
      case ChartTrend.down:
        return AppColors.danger;
      case ChartTrend.stable:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: data.reduce((a, b) => a < b ? a : b) * 0.9,
        maxY: data.reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                .toList(),
            isCurved: true,
            color: _trendColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _trendColor.withValues(alpha: 0.3),
                  _trendColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

