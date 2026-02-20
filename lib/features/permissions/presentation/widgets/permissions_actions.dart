import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_button.dart';
import 'permissions_animated_reveal.dart';

class PermissionsActions extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onComplete;

  const PermissionsActions({
    super.key,
    required this.isEnabled,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        children: [
          PermissionsAnimatedReveal(
            delay: 500,
            child: CustomButton(
              text: localizations.get('syncHealthData'),
              onPressed: isEnabled ? onComplete : null,
              variant: ButtonVariant.primary,
              size: ButtonSize.large,
              fullWidth: true,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          TextButton(
            onPressed: onComplete,
            child: Text(
              localizations.get('skipForNow'),
              style: TextStyle(
                fontSize: 14,
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
