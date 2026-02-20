import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_button.dart';

class OnboardingBottomActions extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onSignIn;

  const OnboardingBottomActions({
    super.key,
    required this.onComplete,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        children: [
          CustomButton(
            text: localizations.get('getStarted'),
            onPressed: onComplete,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
            fullWidth: true,
            icon: const Icon(
              LucideIcons.arrowRight,
              size: 20,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          CustomButton(
            text: localizations.get('alreadyHaveAccount'),
            onPressed: onSignIn,
            variant: ButtonVariant.ghost,
            size: ButtonSize.large,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
