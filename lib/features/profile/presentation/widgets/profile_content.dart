import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/profile_ui_models.dart';

class ProfileContent extends StatelessWidget {
  final ProfileViewData viewData;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;

  const ProfileContent({
    super.key,
    required this.viewData,
    required this.onBack,
    required this.onLogout,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconButton(icon: LucideIcons.chevronLeft, onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('profile'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      localizations.get('accountOverview'),
                      style: TextStyle(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              _IconButton(icon: LucideIcons.settings, onTap: onOpenSettings),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryGlow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  viewData.userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  viewData.email,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    localizations.get('premium'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                title: localizations.get('score'),
                value: viewData.healthScore?.toString() ?? '—',
              ),
              const SizedBox(width: 10),
              _StatCard(
                title: localizations.get('streak'),
                value: viewData.streakDays > 0
                    ? '${viewData.streakDays}d'
                    : '—',
              ),
              const SizedBox(width: 10),
              _StatCard(
                title: localizations.get('records'),
                value: viewData.recordsCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            localizations.get('personalInfo'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _InfoCard(
            rows: [
              _InfoRow(
                label: localizations.get('age'),
                value: viewData.age?.toString() ?? '—',
              ),
              _InfoRow(
                label: localizations.get('sex'),
                value: _humanizeSex(localizations, viewData.sex),
              ),
              _InfoRow(
                label: localizations.get('heightWeight'),
                value: _heightWeightText(
                  heightCm: viewData.heightCm,
                  weightKg: viewData.weightKg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            localizations.get('connectedServices'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: viewData.services.map((service) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.id == 'google'
                              ? localizations.get('googleHealth')
                              : localizations.get('appleHealth'),
                          style: TextStyle(fontSize: 12, color: titleColor),
                        ),
                      ),
                      Text(
                        service.connected
                            ? localizations.get('connected')
                            : localizations.get('notConnected'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: service.connected
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              localizations.get('signOut'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _humanizeSex(AppLocalizations localizations, String? sex) {
    final value = (sex ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return '—';
    }
    if (value == 'male') {
      return localizations.get('male');
    }
    if (value == 'female') {
      return localizations.get('female');
    }
    return sex!;
  }

  String _heightWeightText({
    required double? heightCm,
    required double? weightKg,
  }) {
    final height = heightCm == null
        ? null
        : '${heightCm.toStringAsFixed(0)} cm';
    final weight = weightKg == null
        ? null
        : '${weightKg.toStringAsFixed(1)} kg';
    if (height == null && weight == null) {
      return '—';
    }
    if (height == null) {
      return weight!;
    }
    if (weight == null) {
      return height;
    }
    return '$height / $weight';
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconButton({required this.icon, this.onTap});

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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkForeground
                    : AppColors.lightForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ),
                Text(
                  row.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});
}
