import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_button.dart';

class AiDiagnosticsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AiDiagnosticsButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: CustomButton(
        text: localizations.get('runAIDiagnostics'),
        onPressed: onPressed,
        variant: ButtonVariant.ai,
        size: ButtonSize.large,
        fullWidth: true,
        icon: const Icon(
          LucideIcons.brain,
          size: 20,
        ),
      ),
    );
  }
}
