import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shimmer.dart';
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
                    isDark: isDark,
                    onToggle: () => onToggle(source.id),
                  ),
                ],
              ),
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
      child: Icon(icon, size: 22, color: iconColor),
    );
  }
}

class _TrailingToggle extends StatelessWidget {
  final bool isUpdating;
  final bool isConnected;
  final bool isDisabled;
  final bool isDark;
  final VoidCallback onToggle;

  const _TrailingToggle({
    required this.isUpdating,
    required this.isConnected,
    required this.isDisabled,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isUpdating) {
      return const SizedBox(
        width: 42,
        height: 22,
        child: AppShimmer(
          child: AppShimmerBox(
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      );
    }

    final trackColor = isConnected
        ? (isDark ? AppColors.darkPrimary : AppColors.primary)
        : (isDark ? AppColors.darkMuted : AppColors.muted);
    final thumbColor = isConnected
        ? Colors.white
        : (isDark ? AppColors.darkMutedForeground : const Color(0xFF94A3B8));

    return Opacity(
      opacity: isDisabled ? 0.6 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isConnected
                  ? trackColor
                  : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: isConnected
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: thumbColor,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
