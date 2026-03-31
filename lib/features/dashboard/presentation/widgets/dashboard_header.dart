import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';

class DashboardHeader extends StatelessWidget {
  final DashboardViewData viewData;
  final VoidCallback onOpenProfile;

  const DashboardHeader({
    super.key,
    required this.viewData,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.get(viewData.greetingKey),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                viewData.userName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkForeground
                      : AppColors.lightForeground,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.5)
                      : AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                LucideIcons.user,
                size: 20,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
