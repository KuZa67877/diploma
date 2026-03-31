import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// Заголовок экрана источников данных здоровья.
class HealthSourcesHeader extends StatelessWidget {
  /// Коллбек возврата назад.
  final VoidCallback onBack;

  /// Создает заголовок.
  const HealthSourcesHeader({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Icon(
                LucideIcons.chevronLeft,
                size: 16,
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
