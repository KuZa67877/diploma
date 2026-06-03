import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/analytics_ui_models.dart';
import 'analytics_metric_support.dart';
import 'analytics_time_filters.dart';

class AnalyticsContent extends StatelessWidget {
  final AnalyticsViewData viewData;
  final ValueChanged<String> onFilterSelected;
  final VoidCallback onOpenExport;
  final ValueChanged<String> onOpenMetricDetail;

  const AnalyticsContent({
    super.key,
    required this.viewData,
    required this.onFilterSelected,
    required this.onOpenExport,
    required this.onOpenMetricDetail,
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
    final featuredMetrics = viewData.featuredMetrics;
    final additionalMetrics = viewData.additionalMetrics;

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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpenExport,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
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
          AnalyticsTimeFilters(
            filters: viewData.filters,
            selectedFilterId: viewData.selectedFilterId,
            onSelected: onFilterSelected,
          ),
          const SizedBox(height: 14),
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizations.get('sleepAiScore'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                    _StatusPill(status: viewData.sleepAiStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  viewData.sleepAiScore == null
                      ? localizations.get('sleepAiNoScore')
                      : '${viewData.sleepAiScore!.toStringAsFixed(1)} / 100',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${localizations.get('sleepAiConfidence')}: '
                  '${(viewData.sleepAiConfidence * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ),
          if (featuredMetrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...featuredMetrics.take(2).map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MetricOverviewCard(
                  metric: metric,
                  onTap: () => onOpenMetricDetail(metric.id),
                ),
              ),
            ),
          ],
          if (additionalMetrics.isNotEmpty) ...[
            const SizedBox(height: 2),
            _CardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.get('moreTrackedMetrics'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${additionalMetrics.length} ${localizations.get('tracked')}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.get('openMetricToSeeLargerChart'),
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  const SizedBox(height: 8),
                  ...additionalMetrics.take(6).map(
                    (metric) => _MetricListRow(
                      metric: metric,
                      onTap: () => onOpenMetricDetail(metric.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _CardContainer(
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
                _InfoRow(
                  label: localizations.get('recordsLoaded'),
                  value: viewData.recordsCount.toString(),
                ),
                _InfoRow(
                  label: localizations.get('connectedSources'),
                  value: viewData.sourceCount.toString(),
                ),
                _InfoRow(
                  label: localizations.get('metricTypes'),
                  value: viewData.metricTypeCount.toString(),
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

class _MetricOverviewCard extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final VoidCallback onTap;

  const _MetricOverviewCard({
    required this.metric,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final localizations = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: _CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AnalyticsMetricVisuals.colorFor(
                              metric.id,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            AnalyticsMetricVisuals.iconFor(metric.id),
                            size: 16,
                            color: AnalyticsMetricVisuals.colorFor(metric.id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            localizations.get(metric.titleKey),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: subtitleColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatMetricValueWithUnit(metric.latestValue, metric.unit),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${localizations.get('average')}: ${formatMetricValue(metric.averageValue, metric.unit)} ${metric.unit}',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: AnalyticsSparklineChart(
                  metric: metric,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(height: 8),
              AnalyticsAxisLabels(
                points: metric.points,
                color: subtitleColor,
                maxLabels: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricListRow extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final VoidCallback onTap;

  const _MetricListRow({
    required this.metric,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AnalyticsMetricVisuals.colorFor(metric.id),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                localizations.get(metric.titleKey),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightForeground,
                ),
              ),
            ),
            Text(
              formatMetricValueWithUnit(metric.latestValue, metric.unit),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.lightForeground,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final color = switch (status) {
      'ok' => AppColors.success,
      'insufficient' => AppColors.warning,
      _ => AppColors.mutedForeground,
    };
    final label = switch (status) {
      'ok' => localizations.get('sleepAiStatusOk'),
      'insufficient' => localizations.get('sleepAiStatusInsufficient'),
      _ => localizations.get('sleepAiStatusUnavailable'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lightForeground,
            ),
          ),
        ],
      ),
    );
  }
}
