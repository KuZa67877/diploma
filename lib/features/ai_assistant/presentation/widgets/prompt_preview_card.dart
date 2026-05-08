import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/ai_built_prompt.dart';
import '../../domain/entities/ai_request_size.dart';

class PromptPreviewCard extends StatelessWidget {
  final AiBuiltPrompt? builtPrompt;
  final int estimatedTokens;
  final AiRequestSize requestSize;
  final String? infoMessage;

  const PromptPreviewCard({
    super.key,
    required this.builtPrompt,
    required this.estimatedTokens,
    required this.requestSize,
    required this.infoMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final mutedColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Preview промта',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              _SizeBadge(requestSize: requestSize),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Примерный размер: $estimatedTokens токенов',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const SizedBox(height: 12),
          Text(
            builtPrompt?.previewText ??
                'Сначала соберите health context и сформируйте промт.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI-анализ не является медицинским диагнозом и не заменяет консультацию врача.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
          if (infoMessage != null && infoMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              infoMessage!,
              style: TextStyle(fontSize: 12, color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeBadge extends StatelessWidget {
  final AiRequestSize requestSize;

  const _SizeBadge({required this.requestSize});

  @override
  Widget build(BuildContext context) {
    final color = switch (requestSize) {
      AiRequestSize.small => AppColors.success,
      AiRequestSize.medium => AppColors.warning,
      AiRequestSize.large => AppColors.danger,
    };
    final bg = color.withValues(alpha: 0.14);
    final label = switch (requestSize) {
      AiRequestSize.small => 'Маленький',
      AiRequestSize.medium => 'Средний',
      AiRequestSize.large => 'Большой',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
