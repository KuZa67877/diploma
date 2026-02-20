import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class AuthPrivacyNote extends StatelessWidget {
  const AuthPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(
        AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMuted : AppColors.muted,
        borderRadius: BorderRadius.circular(
          AppConstants.radiusXl,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.shield,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              localizations.get('privacyNote'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
