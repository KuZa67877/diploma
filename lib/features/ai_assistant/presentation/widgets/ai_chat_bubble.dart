import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/ai_chat_message.dart';

class AiChatBubble extends StatelessWidget {
  final AiChatMessage message;

  const AiChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == AiChatRole.assistant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = isAssistant
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final bgColor = isAssistant
        ? (isDark ? AppColors.darkCard : Colors.white)
        : AppColors.primary.withValues(alpha: 0.14);
    final borderColor = isAssistant
        ? (isDark ? AppColors.darkBorder : AppColors.border)
        : AppColors.primary.withValues(alpha: 0.18);
    final textColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAssistant ? 'Ассистент' : 'Вы',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isAssistant ? AppColors.primary : AppColors.primary,
                ),
              ),
              if (message.attachment != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  child: Image.memory(
                    message.attachment!.bytes,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 72,
                      alignment: Alignment.center,
                      color: isDark
                          ? AppColors.darkMuted
                          : AppColors.lightBackground,
                      child: Text(
                        message.attachment!.fileName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.attachment!.fileName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
              if (message.content.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  message.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
