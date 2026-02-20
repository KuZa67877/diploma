import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import 'profile_animated_card.dart';

class ProfileLogoutButton extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileLogoutButton({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: ProfileAnimatedCard(
        delay: 400,
        child: OutlinedButton(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            side: const BorderSide(
              color: AppColors.danger,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.radiusXl,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.logOut,
                size: 20,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                localizations.get('signOut'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
