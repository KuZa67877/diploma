import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/custom_button.dart';

class AuthSocialButtons extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const AuthSocialButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Google',
            onPressed: onGoogle,
            variant: ButtonVariant.medical,
            size: ButtonSize.large,
            icon: const Icon(
              LucideIcons.chrome,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: CustomButton(
            text: 'Apple',
            onPressed: onApple,
            variant: ButtonVariant.medical,
            size: ButtonSize.large,
            icon: const Icon(
              LucideIcons.apple,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
