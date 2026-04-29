import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'health_score_ring.dart';

class HealthScoreCard extends StatelessWidget {
  final int healthScore;
  final DashboardScoreState state;
  final String stateLabel;
  final DashboardVisualState overallState;
  final DashboardLocalizedText summary;
  final DashboardLocalizedText explanation;
  final DashboardDiaryInfluenceUiModel? diaryInfluence;
  final bool healthScoreIsTemporary;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
    required this.state,
    required this.stateLabel,
    required this.overallState,
    required this.summary,
    required this.explanation,
    required this.diaryInfluence,
    required this.healthScoreIsTemporary,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final gradient = _gradientForState(state);
    final badgeColor = _badgeColorForState(state);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  HealthScoreRing(score: healthScore, state: state, size: 280),
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations.get('healthScore'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xDDFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$healthScore',
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            localizations.get(stateLabel),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (healthScoreIsTemporary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildTemporaryBadge(localizations),
                    ),
                  Text(
                    localizations.getWithParams(summary.key, summary.params),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor(overallState, isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localizations.getWithParams(
                      explanation.key,
                      explanation.params,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  if (diaryInfluence != null) ...[
                    const SizedBox(height: 12),
                    _DiaryInfluenceBlock(diaryInfluence: diaryInfluence!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemporaryBadge(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFF9C28F)),
      ),
      child: Text(
        localizations.get('dashboardTemporaryScoreBadge'),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }

  Color _textColor(DashboardVisualState state, bool isDark) {
    if (isDark) {
      return AppColors.darkForeground;
    }
    return switch (state) {
      DashboardVisualState.good => const Color(0xFF0F766E),
      DashboardVisualState.attention => const Color(0xFFB45309),
      DashboardVisualState.warning => const Color(0xFFB91C1C),
      DashboardVisualState.insufficient => AppColors.lightForeground,
    };
  }

  List<Color> _gradientForState(DashboardScoreState scoreState) {
    switch (scoreState) {
      case DashboardScoreState.risk:
        return const [Color(0xFFC2410C), Color(0xFFF97316)];
      case DashboardScoreState.attention:
        return const [Color(0xFFB45309), Color(0xFFF59E0B)];
      case DashboardScoreState.noAccess:
      case DashboardScoreState.calculating:
      case DashboardScoreState.stable:
        return const [AppColors.primary, AppColors.primaryGlow];
    }
  }

  Color _badgeColorForState(DashboardScoreState scoreState) {
    switch (scoreState) {
      case DashboardScoreState.risk:
        return const Color(0x40EF4444);
      case DashboardScoreState.attention:
        return const Color(0x40F59E0B);
      case DashboardScoreState.noAccess:
      case DashboardScoreState.calculating:
      case DashboardScoreState.stable:
        return const Color(0x40FFFFFF);
    }
  }
}

class _DiaryInfluenceBlock extends StatelessWidget {
  final DashboardDiaryInfluenceUiModel diaryInfluence;

  const _DiaryInfluenceBlock({required this.diaryInfluence});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = diaryInfluence.isApplied
        ? diaryInfluence.isPositive
              ? const Color(0xFF15803D)
              : const Color(0xFFB91C1C)
        : isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final background = diaryInfluence.isApplied
        ? diaryInfluence.isPositive
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFFEF2F2)
        : isDark
        ? const Color(0xFF151B22)
        : const Color(0xFFF8FAFB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.get('dashboardDiaryInfluenceTitle'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.lightForeground,
                  ),
                ),
              ),
              Text(
                diaryInfluence.deltaText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            diaryInfluence.summary,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkForeground
                  : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${localizations.get('dashboardDiaryInfluenceConfidence')}: ${diaryInfluence.confidenceText}',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
          if (diaryInfluence.details != null) ...[
            const SizedBox(height: 2),
            Text(
              diaryInfluence.details!,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
          if (diaryInfluence.reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              diaryInfluence.reasons.join(', '),
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
