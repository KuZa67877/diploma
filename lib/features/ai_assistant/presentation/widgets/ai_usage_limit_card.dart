import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/ai_usage_limits.dart';

class AiUsageLimitCard extends StatelessWidget {
  final AiUsageStats usageStats;
  final int dailyRequestLimit;
  final VoidCallback? onResetDebugLimits;

  const AiUsageLimitCard({
    super.key,
    required this.usageStats,
    required this.dailyRequestLimit,
    this.onResetDebugLimits,
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
              const Icon(LucideIcons.shield, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'Локальные лимиты AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              if (kDebugMode && onResetDebugLimits != null)
                TextButton(
                  onPressed: onResetDebugLimits,
                  child: const Text('Reset debug'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Запросов сегодня',
            value: '${usageStats.requestsToday} / $dailyRequestLimit',
            titleColor: titleColor,
            subtitleColor: mutedColor,
          ),
          _MetricRow(
            label: 'Больших запросов',
            value:
                '${usageStats.largeRequestsToday} / ${const AiUsageLimits.defaults().maxLargeRequestsPerDay}',
            titleColor: titleColor,
            subtitleColor: mutedColor,
          ),
          _MetricRow(
            label: 'Input tokens',
            value:
                '${usageStats.estimatedInputTokensToday} / ${const AiUsageLimits.defaults().maxEstimatedInputTokensPerDay}',
            titleColor: titleColor,
            subtitleColor: mutedColor,
          ),
          _MetricRow(
            label: 'Output tokens',
            value: usageStats.estimatedOutputTokensToday.toString(),
            titleColor: titleColor,
            subtitleColor: mutedColor,
          ),
          if (usageStats.lastRequestAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Последний запрос: ${usageStats.lastRequestAt!.toLocal()}',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color titleColor;
  final Color subtitleColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }
}
