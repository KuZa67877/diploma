import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../models/dashboard_ui_models.dart';
import 'dashboard_header.dart';
import 'health_score_card.dart';

class DashboardContent extends StatelessWidget {
  final DashboardViewData viewData;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenHealthSources;

  const DashboardContent({
    super.key,
    required this.viewData,
    required this.onOpenProfile,
    required this.onOpenHealthSources,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeader(viewData: viewData, onOpenProfile: onOpenProfile),
          HealthScoreCard(
            healthScore: viewData.healthScore,
            state: viewData.scoreState,
            stateLabel: viewData.scoreStateLabel,
            overallState: viewData.overallState,
            summary: viewData.overallSummary,
            explanation: viewData.overallExplanation,
            healthScoreIsTemporary: viewData.healthScoreIsTemporary,
          ),
          if (viewData.showInsufficientDataBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: _buildInsufficientBanner(context, localizations),
            ),
          if (viewData.showNoDataState)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: _buildNoDataState(context, localizations),
            ),
          _sectionTitle(context, localizations.get('recommendedToday')),
          const SizedBox(height: 8),
          ...viewData.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _buildRecommendationTile(
                context: context,
                text: localizations.get(item),
              ),
            ),
          ),
          if (viewData.modelCards.isNotEmpty) ...[
            _sectionTitle(context, localizations.get('modelResults')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Column(
                  children: List.generate(viewData.modelCards.length, (index) {
                    final model = viewData.modelCards[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == viewData.modelCards.length - 1 ? 0 : 8,
                      ),
                      child: _buildModelCard(context, model),
                    );
                  }),
                ),
              ),
            ),
          ],
          if (viewData.aiRecommendations.isNotEmpty) ...[
            _sectionTitle(context, localizations.get('aiRecommendationsToday')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildAiRecommendationsCard(
                context,
                viewData.aiRecommendations,
              ),
            ),
          ],
          if (viewData.keyMetrics.isNotEmpty) ...[
            _sectionTitle(context, localizations.get('todayMetrics')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildTodayMetricsCard(context, viewData.keyMetrics),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              localizations.get('dashboardDisclaimer'),
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
        ),
      ),
    );
  }

  Widget _buildInsufficientBanner(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33F59E0B) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x55F59E0B) : const Color(0xFFF59E0B),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizations.get('insufficientDataBanner'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFFFE7C2)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.getWithParams(
              viewData.noDataMessage.key,
              viewData.noDataMessage.params,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkForeground
                  : AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            localizations.getWithParams(
              viewData.noDataHint.key,
              viewData.noDataHint.params,
            ),
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onOpenHealthSources,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(localizations.get('openHealthSourcesCta')),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationTile({
    required BuildContext context,
    required String text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
        ),
      ),
    );
  }

  Widget _buildModelCard(BuildContext context, DashboardModelCardUiModel card) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final tone = _toneForState(card.state);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B22) : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.get(card.titleKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.lightForeground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  localizations.getWithParams(
                    card.badge.key,
                    card.badge.params,
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tone.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            localizations.getWithParams(card.summary.key, card.summary.params),
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
            localizations.getWithParams(
              card.explanation.key,
              card.explanation.params,
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${localizations.get('dashboardRecommendationPrefix')}'
            '${localizations.getWithParams(card.recommendation.key, card.recommendation.params)}',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground,
            ),
          ),
          if (card.progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: card.progress!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(tone.foreground),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiRecommendationsCard(
    BuildContext context,
    List<DashboardAiRecommendationUiModel> recommendations,
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        children: List.generate(recommendations.length, (index) {
          final item = recommendations[index];
          final tone = _toneForState(item.importance);
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == recommendations.length - 1 ? 0 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.sparkles,
                    size: 12,
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.getWithParams(
                          item.text.key,
                          item.text.params,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkForeground
                              : AppColors.lightForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localizations.getWithParams(
                          item.reason.key,
                          item.reason.params,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkMutedForeground
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTodayMetricsCard(
    BuildContext context,
    List<DashboardKeyMetricUiModel> metrics,
  ) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics
                .map((metric) {
                  final valueText = metric.hasData
                      ? (metric.unit.isEmpty
                            ? metric.value
                            : '${metric.value} ${metric.unit}')
                      : '—';
                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF151B22)
                            : const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.get(metric.labelKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkMutedForeground
                                  : AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            valueText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: metric.hasData
                                  ? (isDark
                                        ? AppColors.darkForeground
                                        : AppColors.lightForeground)
                                  : (isDark
                                        ? AppColors.darkMutedForeground
                                        : AppColors.mutedForeground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }

  _VisualTone _toneForState(DashboardVisualState state) {
    return switch (state) {
      DashboardVisualState.good => const _VisualTone(
        foreground: Color(0xFF0F766E),
        background: Color(0xFFE8F5F3),
      ),
      DashboardVisualState.attention => const _VisualTone(
        foreground: Color(0xFFB45309),
        background: Color(0xFFFFF4E5),
      ),
      DashboardVisualState.warning => const _VisualTone(
        foreground: Color(0xFFB91C1C),
        background: Color(0xFFFEF2F2),
      ),
      DashboardVisualState.insufficient => const _VisualTone(
        foreground: Color(0xFF475569),
        background: Color(0xFFF1F5F9),
      ),
    };
  }
}

class _VisualTone {
  final Color foreground;
  final Color background;

  const _VisualTone({required this.foreground, required this.background});
}
