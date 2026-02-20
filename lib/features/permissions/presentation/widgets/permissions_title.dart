import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class PermissionsTitle extends StatelessWidget {
  const PermissionsTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('connectHealthData'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Text(
          localizations.get('syncYourMetrics'),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
