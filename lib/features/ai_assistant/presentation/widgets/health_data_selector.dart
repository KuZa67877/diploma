import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/ai_health_data_type.dart';

class HealthDataSelector extends StatelessWidget {
  final Set<AiHealthDataType> selectedTypes;
  final ValueChanged<AiHealthDataType> onToggle;

  const HealthDataSelector({
    super.key,
    required this.selectedTypes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AiHealthDataType.values.map((type) {
        final selected = selectedTypes.contains(type);
        return FilterChip(
          label: Text(type.displayText),
          selected: selected,
          onSelected: (_) => onToggle(type),
          selectedColor: AppColors.primary.withValues(alpha: 0.14),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected
                ? AppColors.primary
                : (isDark
                      ? AppColors.darkForeground
                      : AppColors.lightForeground),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.35)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        );
      }).toList(growable: false),
    );
  }
}
