import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navItems = [
      _NavItem(id: 'home', icon: LucideIcons.heart, labelKey: 'home'),
      _NavItem(
        id: 'wellbeing',
        icon: LucideIcons.calendarDays,
        labelKey: 'wellbeing',
      ),
      _NavItem(
        id: 'analytics',
        icon: LucideIcons.activity,
        labelKey: 'analytics',
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.8)
                  : AppColors.border.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentIndex == index;
              return _NavItemWidget(
                item: item,
                isActive: isActive,
                onTap: () => onTap(index),
                localizations: localizations,
                isDark: isDark,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String id;
  final IconData icon;
  final String labelKey;

  const _NavItem({
    required this.id,
    required this.icon,
    required this.labelKey,
  });
}

class _NavItemWidget extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final AppLocalizations localizations;
  final bool isDark;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.localizations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      child: AnimatedContainer(
        duration: AppConstants.shortAnimationDuration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isActive
                  ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                  : (isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground),
            ),
            const SizedBox(height: 4),
            Text(
              localizations.get(item.labelKey),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                    : (isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
