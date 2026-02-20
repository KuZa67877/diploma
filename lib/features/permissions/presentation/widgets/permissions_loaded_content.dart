import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/permissions_ui_models.dart';
import 'health_source_selector.dart';
import 'permission_type_card.dart';
import 'permissions_actions.dart';
import 'permissions_animated_reveal.dart';
import 'permissions_header.dart';
import 'permissions_title.dart';

class PermissionsLoadedContent extends StatelessWidget {
  final List<HealthSourceUiModel> sources;
  final List<HealthPermissionUiModel> permissions;
  final String? selectedSourceId;
  final Map<String, bool> selectedPermissions;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final ValueChanged<String> onSelectSource;
  final ValueChanged<String> onTogglePermission;

  const PermissionsLoadedContent({
    super.key,
    required this.sources,
    required this.permissions,
    required this.selectedSourceId,
    required this.selectedPermissions,
    required this.onBack,
    required this.onComplete,
    required this.onSelectSource,
    required this.onTogglePermission,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        PermissionsHeader(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PermissionsAnimatedReveal(
                  delay: 0,
                  child: const PermissionsTitle(),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                PermissionsAnimatedReveal(
                  delay: 100,
                  child: HealthSourceSelector(
                    sources: sources,
                    selectedSourceId: selectedSourceId,
                    onSelectSource: onSelectSource,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                PermissionsAnimatedReveal(
                  delay: 200,
                  child: Text(
                    localizations.get('selectDataToSync'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkForeground
                          : AppColors.lightForeground,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                ...permissions.asMap().entries.map((entry) {
                  final enabled = selectedPermissions[entry.value.id] ?? false;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key < permissions.length - 1
                          ? AppConstants.spacingMd
                          : 0,
                    ),
                    child: PermissionsAnimatedReveal(
                      delay: 250 + (entry.key * 50),
                      child: PermissionTypeCard(
                        permission: entry.value,
                        enabled: enabled,
                        onToggle: onTogglePermission,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppConstants.spacingXl),
              ],
            ),
          ),
        ),
        PermissionsActions(
          isEnabled: selectedSourceId != null,
          onComplete: onComplete,
        ),
      ],
    );
  }
}
