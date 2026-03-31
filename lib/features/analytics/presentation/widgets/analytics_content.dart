import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/analytics_ui_models.dart';

class AnalyticsContent extends StatelessWidget {
  final AnalyticsViewData viewData;
  final ValueChanged<String> onFilterSelected;

  const AnalyticsContent({
    super.key,
    required this.viewData,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.get('healthAnalytics'),
                  style: TextStyle(
                    fontSize: 32 / 1.33,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.download,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      localizations.get('export'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            localizations.get('trackTrendsMetricsShared'),
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
          const SizedBox(height: 14),
          _FilterRow(
            filters: viewData.filters,
            selectedFilterId: viewData.selectedFilterId,
            onSelected: onFilterSelected,
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.get('dailySteps'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  viewData.averageSteps > 0
                      ? '${localizations.get('average')}: '
                            '${viewData.averageSteps} '
                            '${localizations.get('steps').toLowerCase()}'
                      : localizations.get('noStepsDataYet'),
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: _StepsBarChart(activity: viewData.activity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.get('heartRateTrend'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewData.averageHeartRate > 0
                      ? '${localizations.get('average')}: '
                            '${viewData.averageHeartRate} bpm'
                      : localizations.get('noHeartRateDataYet'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: _TrendLineChart(points: viewData.heartRate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD5C6)),
            ),
            child: Text(
              _insightText(localizations, viewData),
              style: TextStyle(fontSize: 12, color: titleColor),
            ),
          ),
          const SizedBox(height: 10),
          _CardContainer(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 28,
                      startDegreeOffset: 180,
                      sections: [
                        PieChartSectionData(
                          value:
                              (viewData.recordsCount <= 0
                                      ? 1
                                      : viewData.recordsCount)
                                  .toDouble(),
                          radius: 10,
                          color: AppColors.primary,
                          title: '',
                        ),
                        PieChartSectionData(
                          value:
                              (viewData.sourceCount <= 0
                                      ? 1
                                      : viewData.sourceCount)
                                  .toDouble(),
                          radius: 10,
                          color: AppColors.warning,
                          title: '',
                        ),
                        PieChartSectionData(
                          value:
                              (viewData.metricTypeCount <= 0
                                      ? 1
                                      : viewData.metricTypeCount)
                                  .toDouble(),
                          radius: 10,
                          color: AppColors.primaryLight,
                          title: '',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.get('dataQualityBreakdown'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${localizations.get('recordsLoaded')}: ${viewData.recordsCount}',
                        style: TextStyle(fontSize: 12, color: titleColor),
                      ),
                      Text(
                        '${localizations.get('connectedSources')}: ${viewData.sourceCount}',
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                      Text(
                        '${localizations.get('metricTypes')}: ${viewData.metricTypeCount}',
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _insightText(AppLocalizations localizations, AnalyticsViewData data) {
    final insight = data.insights.isNotEmpty ? data.insights.first : null;
    if (insight == null) {
      return localizations.get('aiInsightNoData');
    }

    return switch (insight.titleKey) {
      'elevatedHeartRate' => localizations.get('aiInsightElevatedHeartRate'),
      'activityGoalAtRisk' => localizations.get('aiInsightActivityGoalAtRisk'),
      'sleepQualityImproving' => localizations.get(
        'aiInsightSleepQualityImproving',
      ),
      _ => localizations.get('aiInsightAnalyzing'),
    };
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: child,
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<AnalyticsFilterUiModel> filters;
  final String selectedFilterId;
  final ValueChanged<String> onSelected;

  const _FilterRow({
    required this.filters,
    required this.selectedFilterId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final visibleFilters = filters.take(3).toList(growable: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMuted : AppColors.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: visibleFilters.map((filter) {
          final active = filter.id == selectedFilterId;
          return GestureDetector(
            onTap: () => onSelected(filter.id),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? (isDark ? AppColors.darkCard : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                localizations.get(filter.labelKey).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? (isDark
                            ? AppColors.darkForeground
                            : AppColors.lightForeground)
                      : (isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  final List<AnalyticsChartPoint> points;

  const _TrendLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final spots = points.map((p) => FlSpot(p.x, p.y)).toList(growable: false)
      ..sort((a, b) => a.x.compareTo(b.x));

    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 5;
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
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
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3.8,
                color: AppColors.primary,
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsBarChart extends StatelessWidget {
  final List<AnalyticsBarData> activity;

  const _StepsBarChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox.shrink();
    final maxSteps = activity
        .map((e) => e.steps)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: activity.take(6).toList(growable: false).asMap().entries.map((
        entry,
      ) {
        final idx = entry.key;
        final item = entry.value;
        final ratio = (item.steps / maxSteps).clamp(0.2, 1.0);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx == 5 ? 0 : 6),
            height: 74 * ratio,
            decoration: BoxDecoration(
              color: idx == 3 || idx == 5
                  ? AppColors.primary
                  : AppColors.primaryLight.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }).toList(),
    );
  }
}
