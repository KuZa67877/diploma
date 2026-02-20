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
      _NavItem(
        id: 'home',
        icon: LucideIcons.home,
        labelKey: 'home',
      ),
      _NavItem(
        id: 'data',
        icon: LucideIcons.database,
        labelKey: 'data',
      ),
      _NavItem(
        id: 'analytics',
        icon: LucideIcons.barChart3,
        labelKey: 'analytics',
      ),
      _NavItem(
        id: 'reports',
        icon: LucideIcons.fileText,
        labelKey: 'reports',
      ),
      _NavItem(
        id: 'profile',
        icon: LucideIcons.user,
        labelKey: 'profile',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                  .withValues(alpha: 0.1)
              : Colors.transparent,
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
