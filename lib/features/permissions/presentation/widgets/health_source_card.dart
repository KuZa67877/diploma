import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/permissions_ui_models.dart';

class HealthSourceCard extends StatelessWidget {
  final HealthSourceUiModel source;
  final bool isSelected;
  final VoidCallback onSelected;

  const HealthSourceCard({
    super.key,
    required this.source,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                    : AppColors.border.withValues(alpha: 0.5)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: source.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  ),
                  child: Icon(
                    source.icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              localizations.get(source.nameKey),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localizations.get(source.descKey),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
