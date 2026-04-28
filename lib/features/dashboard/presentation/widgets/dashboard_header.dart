import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';

class DashboardHeader extends StatelessWidget {
  final DashboardViewData viewData;
  final VoidCallback onOpenProfile;

  const DashboardHeader({
    super.key,
    required this.viewData,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusTone = _statusTone(viewData.dataStatus);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get(viewData.greetingKey),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      viewData.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkForeground
                            : AppColors.lightForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      viewData.dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder.withValues(alpha: 0.5)
                          : AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.user,
                    size: 20,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusTone.background,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: statusTone.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusTone.icon, size: 14, color: statusTone.foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    localizations.get(viewData.dataStatusLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusTone.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusTone _statusTone(DashboardDataStatusState state) {
    return switch (state) {
      DashboardDataStatusState.upToDate => const _StatusTone(
        icon: LucideIcons.checkCircle,
        background: Color(0xFFEAF7F2),
        border: Color(0xFFB8E2CD),
        foreground: Color(0xFF0F766E),
      ),
      DashboardDataStatusState.insufficient => const _StatusTone(
        icon: LucideIcons.info,
        background: Color(0xFFFFF7ED),
        border: Color(0xFFFACEA7),
        foreground: Color(0xFFB45309),
      ),
      DashboardDataStatusState.syncRequired => const _StatusTone(
        icon: LucideIcons.refreshCw,
        background: Color(0xFFFEF2F2),
        border: Color(0xFFF4C9C9),
        foreground: Color(0xFFB91C1C),
      ),
    };
  }
}

class _StatusTone {
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;

  const _StatusTone({
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
  });
}
