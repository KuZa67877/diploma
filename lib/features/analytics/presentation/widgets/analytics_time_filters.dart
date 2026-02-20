import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/analytics_ui_models.dart';

class AnalyticsTimeFilters extends StatelessWidget {
  final List<AnalyticsFilterUiModel> filters;
  final String selectedFilterId;
  final ValueChanged<String> onSelected;

  const AnalyticsTimeFilters({
    super.key,
    required this.filters,
    required this.selectedFilterId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.muted,
          borderRadius: BorderRadius.circular(
            AppConstants.radiusXl,
          ),
        ),
        child: Row(
          children: filters.map((filter) {
            final isSelected = selectedFilterId == filter.id;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(filter.id),
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusMd,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.darkCard : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMd,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    localizations.get(filter.labelKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDark
                              ? AppColors.darkForeground
                              : AppColors.lightForeground)
                          : (isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
