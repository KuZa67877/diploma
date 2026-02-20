import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/theme_cubit.dart';
import 'profile_setting_item.dart';

class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => context.pushNamed(AppRouter.healthSourcesRoute),
            child: ProfileSettingItem(
              icon: LucideIcons.heart,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primaryLight,
              title: localizations.get('healthDataSources'),
              subtitle: localizations.get('healthSourcesSubtitle'),
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
          const Divider(height: 1),
          ProfileSettingItem(
            icon: LucideIcons.bell,
            iconColor: AppColors.accent,
            iconBgColor: AppColors.accentLight,
            title: localizations.get('notifications'),
            subtitle: localizations.get('healthAlertsReminders'),
            trailing: Switch(
              value: true,
              onChanged: (value) {},
              activeThumbColor: AppColors.primary,
            ),
          ),
          const Divider(height: 1),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return ProfileSettingItem(
                icon: LucideIcons.moon,
                iconColor: AppColors.aiPurple,
                iconBgColor: AppColors.aiPurpleLight,
                title: localizations.get('darkMode'),
                subtitle: localizations.get('reduceEyeStrain'),
                trailing: Switch(
                  value: themeState.mode == ThemeMode.dark,
                  onChanged: (value) {
                    context.read<ThemeCubit>().toggleTheme();
                  },
                  activeThumbColor: AppColors.primary,
                ),
              );
            },
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () {},
            child: ProfileSettingItem(
              icon: LucideIcons.refreshCw,
              iconColor: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
              iconBgColor: isDark ? AppColors.darkMuted : AppColors.muted,
              title: localizations.get('dataSyncFrequency'),
              subtitle: localizations.get('every30Min'),
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
          const Divider(height: 1),
          BlocBuilder<LanguageCubit, LanguageState>(
            builder: (context, languageState) {
              final language = languageState.language;
              return ProfileSettingItem(
                icon: LucideIcons.globe,
                iconColor: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
                iconBgColor: isDark ? AppColors.darkMuted : AppColors.muted,
                title: localizations.get('language'),
                subtitle: language == AppLanguage.english
                    ? localizations.get('english')
                    : localizations.get('russian'),
                trailing: InkWell(
                  onTap: () {
                    context.read<LanguageCubit>().toggleLanguage();
                  },
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Text(
                      language == AppLanguage.english ? 'RU' : 'EN',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
