import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/health_source_ui_model.dart';

/// Карточка источника данных здоровья.
class HealthSourceCard extends StatelessWidget {
  /// UI-модель источника.
  final HealthSourceUiModel source;

  /// Признак обновления источника.
  final bool isUpdating;

  /// Коллбек переключения подключения.
  final ValueChanged<String> onToggle;

  /// Создает карточку источника.
  const HealthSourceCard({
    super.key,
    required this.source,
    required this.isUpdating,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusText = _statusText(localizations);
    final isDisabled = !source.isAvailable || isUpdating;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: source.isAvailable ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: BorderSide(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceIcon(
                    icon: source.icon,
                    iconColor: source.iconColor,
                    backgroundColor: source.iconBackground,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkForeground
                                : AppColors.lightForeground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          source.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  _TrailingToggle(
                    isUpdating: isUpdating,
                    isConnected: source.isConnected,
                    isDisabled: isDisabled,
                    onToggle: () => onToggle(source.id),
                  ),
                ],
              ),
              if (source.metricKeys.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  localizations.get('supportedMetrics'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: source.metricKeys
                      .map(
                        (key) => Chip(
                          label: Text(
                            localizations.get(key),
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(AppLocalizations localizations) {
    if (!source.isAvailable) {
      return localizations.get('notAvailable');
    }
    return source.isConnected
        ? localizations.get('connected')
        : localizations.get('notConnected');
  }

  Color _statusColor(bool isDark) {
    if (!source.isAvailable) {
      return isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
    }
    return source.isConnected ? AppColors.success : AppColors.warning;
  }
}

class _SourceIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _SourceIcon({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Icon(
        icon,
        size: 22,
        color: iconColor,
      ),
    );
  }
}

class _TrailingToggle extends StatelessWidget {
  final bool isUpdating;
  final bool isConnected;
  final bool isDisabled;
  final VoidCallback onToggle;

  const _TrailingToggle({
    required this.isUpdating,
    required this.isConnected,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isUpdating) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Switch(
      value: isConnected,
      onChanged: isDisabled ? null : (_) => onToggle(),
      activeThumbColor: AppColors.primary,
    );
  }
}
