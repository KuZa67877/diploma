import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/analytics_ui_models.dart';

class AnalyticsInsightCard extends StatelessWidget {
  final AnalyticsInsightUiModel insight;

  const AnalyticsInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (insight.severity) {
      case 'warning':
        bgColor = AppColors.warningLight;
        iconColor = AppColors.warning;
        icon = LucideIcons.alertTriangle;
        break;
      case 'success':
        bgColor = AppColors.successLight;
        iconColor = AppColors.success;
        icon = LucideIcons.trendingUp;
        break;
      default:
        bgColor = AppColors.aiPurpleLight;
        iconColor = AppColors.aiPurple;
        icon = LucideIcons.brain;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.get(insight.titleKey),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.lightForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.get(insight.descKey),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
