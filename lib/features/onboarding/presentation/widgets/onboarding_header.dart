import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import 'onboarding_logo.dart';

class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXl,
      ),
      child: Column(
        children: [
          const OnboardingLogo(),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            localizations.get('appName'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppConstants.spacingXs),
              Text(
                localizations.get('tagline'),
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
