import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/profile_ui_models.dart';
import 'profile_animated_card.dart';

class ProfileCard extends StatelessWidget {
  final ProfileViewData viewData;

  const ProfileCard({
    super.key,
    required this.viewData,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: ProfileAnimatedCard(
        delay: 100,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: Row(
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
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewData.userName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? AppColors.darkForeground : AppColors.lightForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        viewData.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    localizations.get('edit'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
