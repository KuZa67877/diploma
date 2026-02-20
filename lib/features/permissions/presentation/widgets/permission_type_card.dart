import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/permissions_ui_models.dart';

class PermissionTypeCard extends StatelessWidget {
  final HealthPermissionUiModel permission;
  final bool enabled;
  final ValueChanged<String> onToggle;

  const PermissionTypeCard({
    super.key,
    required this.permission,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: Icon(
                permission.icon,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.get(permission.labelKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkForeground
                          : AppColors.lightForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.get(permission.descKey),
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
            Switch(
              value: enabled,
              onChanged: (_) => onToggle(permission.id),
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
