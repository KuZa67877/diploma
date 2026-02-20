import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/analytics_ui_models.dart';
import 'analytics_animated_card.dart';
import 'analytics_insight_card.dart';

class AnalyticsInsightsSection extends StatelessWidget {
  final List<AnalyticsInsightUiModel> insights;

  const AnalyticsInsightsSection({
    super.key,
    required this.insights,
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
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                localizations.get('aiInsights'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppColors.darkForeground : AppColors.lightForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        ...insights.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppConstants.spacingLg,
              right: AppConstants.spacingLg,
              bottom:
                  entry.key < insights.length - 1 ? AppConstants.spacingMd : 0,
            ),
            child: AnalyticsAnimatedCard(
              delay: 400 + (entry.key * 100),
              child: AnalyticsInsightCard(insight: entry.value),
            ),
          );
        }),
      ],
    );
  }
}
