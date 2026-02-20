import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'mini_chart.dart';

class MetricCard extends StatelessWidget {
  final DashboardMetricUiModel metric;

  const MetricCard({
    super.key,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: Icon(
                metric.icon,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.get(metric.labelKey),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        metric.value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.lightForeground,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        metric.unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              height: 40,
              child: MiniChart(
                data: metric.data,
                trend: metric.trend,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getTrendColor(metric.trend).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTrendIcon(metric.trend),
                size: 12,
                color: _getTrendColor(metric.trend),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTrendIcon(ChartTrend trend) {
    switch (trend) {
      case ChartTrend.up:
        return LucideIcons.trendingUp;
      case ChartTrend.down:
        return LucideIcons.trendingDown;
      case ChartTrend.stable:
        return LucideIcons.minus;
    }
  }

  Color _getTrendColor(ChartTrend trend) {
    switch (trend) {
      case ChartTrend.up:
        return AppColors.success;
      case ChartTrend.down:
        return AppColors.danger;
      case ChartTrend.stable:
        return AppColors.mutedForeground;
    }
  }
}
