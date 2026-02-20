import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    IconData icon;
    String textKey;
    Color bgColor;

    switch (status) {
      case 'stable':
        icon = LucideIcons.trendingUp;
        textKey = 'stable';
        bgColor = AppColors.success;
        break;
      case 'attention':
        icon = LucideIcons.alertTriangle;
        textKey = 'attentionNeeded';
        bgColor = AppColors.warning;
        break;
      case 'risk':
        icon = LucideIcons.trendingDown;
        textKey = 'riskDetected';
        bgColor = AppColors.danger;
        break;
      default:
        icon = LucideIcons.trendingUp;
        textKey = 'stable';
        bgColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            localizations.get(textKey),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
