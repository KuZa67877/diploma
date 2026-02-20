import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class AuthLogoSection extends StatelessWidget {
  final bool isLogin;

  const AuthLogoSection({
    super.key,
    required this.isLogin,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppConstants.radius2xl,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryGlow,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.brain,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            isLogin
                ? localizations.get('welcomeBack')
                : localizations.get('createAccount'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            isLogin
                ? localizations.get('signInToContinue')
                : localizations.get('startYourAIHealth'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
