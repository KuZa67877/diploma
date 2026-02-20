import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';

class AiInsightCard extends StatelessWidget {
  final DashboardInsightUiModel insight;

  const AiInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(
            AppConstants.radius2xl,
          ),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent,
                    AppColors.warning,
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusXl,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 20,
                color: Colors.white,
              ),
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
                      color:
                          isDark ? AppColors.darkForeground : AppColors.lightForeground,
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
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
