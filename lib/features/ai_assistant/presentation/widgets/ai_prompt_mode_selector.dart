import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/ai_prompt_mode.dart';

class AiPromptModeSelector extends StatelessWidget {
  final AiPromptMode selectedMode;
  final ValueChanged<AiPromptMode> onChanged;

  const AiPromptModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AiPromptMode.values.map((mode) {
        final selected = mode == selectedMode;
        return ChoiceChip(
          label: Text(mode.goalText),
          selected: selected,
          onSelected: (_) => onChanged(mode),
          selectedColor: AppColors.accent.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: selected
                ? AppColors.accent
                : (isDark
                      ? AppColors.darkForeground
                      : AppColors.lightForeground),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        );
      }).toList(growable: false),
    );
  }
}
