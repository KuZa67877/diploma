import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'animated_reveal.dart';
import 'metric_card.dart';

class MetricsSection extends StatelessWidget {
  final List<DashboardMetricUiModel> metrics;
  final VoidCallback onViewAll;

  const MetricsSection({
    super.key,
    required this.metrics,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.get('healthMetrics'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppColors.darkForeground : AppColors.lightForeground,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  localizations.get('viewAll'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
          ),
          child: Column(
            children: List.generate(
              metrics.length,
              (index) => AnimatedReveal(
                delay: 300 + (index * 100),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: index < metrics.length - 1
                        ? AppConstants.spacingMd
                        : 0,
                  ),
                  child: MetricCard(metric: metrics[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
