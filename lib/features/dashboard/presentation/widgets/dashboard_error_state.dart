import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class DashboardErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DashboardErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 32,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            TextButton(
              onPressed: onRetry,
              child: Text(localizations.get('retry')),
            ),
          ],
        ),
      ),
    );
  }
}
