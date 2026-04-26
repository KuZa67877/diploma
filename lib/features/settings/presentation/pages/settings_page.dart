import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/gradient_background.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenHealthSources;
  final VoidCallback? onOpenSleepModelDebug;
  final VoidCallback? onOpenStressModelDebug;
  final VoidCallback? onOpenPhysiologyAnomalyDebug;

  const SettingsPage({
    super.key,
    required this.onBack,
    required this.onOpenHealthSources,
    this.onOpenSleepModelDebug,
    this.onOpenStressModelDebug,
    this.onOpenPhysiologyAnomalyDebug,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkModeEnabled = context.select(
      (ThemeCubit cubit) => cubit.state.mode == ThemeMode.dark,
    );
    final currentLanguage = context.select(
      (LanguageCubit cubit) => cubit.state.language,
    );
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final debugEnabled = AppLogger.instance.isEnabled;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _HeaderIconButton(
                      icon: LucideIcons.chevronLeft,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.get('settings'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.get('privacyDataSourcesAndPreferences'),
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: LucideIcons.heart,
                        iconBg: AppColors.primaryLight,
                        title: l10n.get('healthDataSources'),
                        subtitle: l10n.get('healthSourcesSummary'),
                        onTap: onOpenHealthSources,
                      ),
                      _DividerLine(color: borderColor),
                      _SettingsRow(
                        icon: LucideIcons.bell,
                        iconBg: AppColors.accentLight,
                        title: l10n.get('notifications'),
                        subtitle: l10n.get('healthAlertsReminders'),
                        trailing: _pill(
                          l10n.get('on'),
                          AppColors.success,
                          AppColors.successLight,
                        ),
                      ),
                      _DividerLine(color: borderColor),
                      _SettingsRow(
                        icon: LucideIcons.moon,
                        iconBg: AppColors.aiPurpleLight,
                        title: l10n.get('darkMode'),
                        subtitle: l10n.get('reduceEyeStrain'),
                        trailing: _pill(
                          isDarkModeEnabled ? l10n.get('on') : l10n.get('off'),
                          isDarkModeEnabled ? AppColors.success : subtitleColor,
                          isDarkModeEnabled
                              ? AppColors.successLight
                              : (isDark
                                    ? AppColors.darkMuted
                                    : AppColors.muted),
                        ),
                        onTap: () => context.read<ThemeCubit>().toggleTheme(),
                      ),
                      _DividerLine(color: borderColor),
                      _SettingsRow(
                        icon: LucideIcons.languages,
                        iconBg: isDark ? AppColors.darkMuted : AppColors.muted,
                        title: l10n.get('language'),
                        subtitle: currentLanguage == AppLanguage.russian
                            ? l10n.get('russian')
                            : l10n.get('english'),
                        trailing: _pill(
                          currentLanguage == AppLanguage.russian ? 'RU' : 'EN',
                          AppColors.primary,
                          AppColors.primaryLight,
                        ),
                        onTap: () =>
                            context.read<LanguageCubit>().toggleLanguage(),
                      ),
                      if (debugEnabled) ...[
                        _DividerLine(color: borderColor),
                        _SettingsRow(
                          icon: LucideIcons.activity,
                          iconBg: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                          title: l10n.get('sleepModelDebug'),
                          subtitle: l10n.get('sleepModelDebugSubtitle'),
                          onTap: onOpenSleepModelDebug,
                        ),
                        _DividerLine(color: borderColor),
                        _SettingsRow(
                          icon: LucideIcons.zap,
                          iconBg: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                          title: l10n.get('stressModelDebug'),
                          subtitle: l10n.get('stressModelDebugSubtitle'),
                          onTap: onOpenStressModelDebug,
                        ),
                        _DividerLine(color: borderColor),
                        _SettingsRow(
                          icon: LucideIcons.activity,
                          iconBg: isDark
                              ? AppColors.darkMuted
                              : AppColors.muted,
                          title: l10n.get('physiologyAnomalyDebug'),
                          subtitle: l10n.get('physiologyAnomalyDebugSubtitle'),
                          onTap: onOpenPhysiologyAnomalyDebug,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.shield,
                          size: 16,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.get('dataEncryptionEnabled'),
                          style: TextStyle(fontSize: 13, color: titleColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(LucideIcons.chevronRight, size: 16, color: subtitleColor),
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  final Color color;

  const _DividerLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 1,
      color: color.withValues(alpha: 0.7),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark
              ? AppColors.darkMutedForeground
              : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
