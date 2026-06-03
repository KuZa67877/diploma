import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../bloc/analytics_cubit.dart';
import '../models/analytics_ui_models.dart';
import '../widgets/analytics_error_state.dart';
import '../widgets/analytics_metric_support.dart';
import '../widgets/analytics_time_filters.dart';
import 'analytics_compare_metrics_page.dart';

class AnalyticsMetricDetailPage extends StatefulWidget {
  final String initialMetricId;
  final String initialFilterId;

  const AnalyticsMetricDetailPage({
    super.key,
    required this.initialMetricId,
    required this.initialFilterId,
  });

  @override
  State<AnalyticsMetricDetailPage> createState() =>
      _AnalyticsMetricDetailPageState();
}

class _AnalyticsMetricDetailPageState extends State<AnalyticsMetricDetailPage> {
  late final AnalyticsCubit _cubit;
  late String _selectedMetricId;
  late String _selectedFilterId;
  List<String> _selectedCompareMetricIds = const [];
  bool _normalizedComparison = true;

  @override
  void initState() {
    super.initState();
    _selectedMetricId = widget.initialMetricId;
    _selectedFilterId = widget.initialFilterId;
    _cubit = getIt<AnalyticsCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _cubit.load(filterId: _selectedFilterId);
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          final viewData = state.whenOrNull(loaded: (data) => data);
          final errorMessage = state.whenOrNull(error: (message) => message);

          if (errorMessage != null) {
            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: AnalyticsErrorState(
                    message: errorMessage,
                    onRetry: () =>
                        context.read<AnalyticsCubit>().load(filterId: _selectedFilterId),
                  ),
                ),
              ),
            );
          }

          if (viewData == null) {
            return const Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          }

          final metric =
              viewData.metricById(_selectedMetricId) ?? viewData.featuredMetrics.first;
          _selectedMetricId = metric.id;

          final relatedMetrics = metric.relatedMetricIds
              .map(viewData.metricById)
              .whereType<AnalyticsMetricUiModel>()
              .toList(growable: false);

          final compareMetrics = _selectedCompareMetricIds
              .map(viewData.metricById)
              .whereType<AnalyticsMetricUiModel>()
              .where((candidate) => candidate.id != metric.id)
              .toList(growable: false);

          final displayedCompareMetrics = compareMetrics.isNotEmpty
              ? compareMetrics
              : relatedMetrics.take(2).toList(growable: false);

          final localizations = AppLocalizations.of(context);
          final valueText = formatMetricValueWithUnit(
            metric.latestValue,
            metric.unit,
          );

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  localizations.get(metric.titleKey),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.lightForeground,
                                  ),
                                ),
                                Text(
                                  localizations.get('metricDetail'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCompare(context, viewData, metric),
                            icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              valueText,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightForeground,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _deltaText(localizations, metric),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2429),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF323A42)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _LegendPill(metric: metric, active: true),
                                      ...displayedCompareMetrics.map(
                                        (item) => _LegendPill(metric: item),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 240,
                                    child: AnalyticsSeriesChart(
                                      primaryMetric: metric,
                                      compareMetrics: displayedCompareMetrics,
                                      normalized: _normalizedComparison,
                                      includeBarPane: true,
                                      darkSurface: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AnalyticsAxisLabels(
                                    points: metric.points,
                                    color: const Color(0xFF94A3B8),
                                    maxLabels: 5,
                                  ),
                                  const SizedBox(height: 12),
                                  AnalyticsTimeFilters(
                                    filters: viewData.filters,
                                    selectedFilterId: viewData.selectedFilterId,
                                    onSelected: (filterId) {
                                      setState(() => _selectedFilterId = filterId);
                                      context.read<AnalyticsCubit>().selectFilter(filterId);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ValueChip(
                                          label: localizations.get('average'),
                                          value: formatMetricValue(
                                            metric.averageValue,
                                            metric.unit,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ValueChip(
                                          label: localizations.get('low'),
                                          value: formatMetricValue(
                                            metric.minValue,
                                            metric.unit,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ValueChip(
                                          label: localizations.get('peak'),
                                          value: formatMetricValue(
                                            metric.maxValue,
                                            metric.unit,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (relatedMetrics.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                localizations.get('relatedSignals'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightForeground,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: relatedMetrics
                                    .take(4)
                                    .map(
                                      (item) => ActionChip(
                                        onPressed: () {
                                          setState(() {
                                            _selectedMetricId = item.id;
                                            _selectedCompareMetricIds = item.relatedMetricIds
                                                .take(2)
                                                .toList(growable: false);
                                          });
                                        },
                                        backgroundColor: item.id ==
                                                _selectedMetricId
                                            ? AnalyticsMetricVisuals.colorFor(
                                                item.id,
                                              ).withValues(alpha: 0.18)
                                            : AppColors.muted,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                          side: BorderSide(
                                            color: item.id == _selectedMetricId
                                                ? AnalyticsMetricVisuals.colorFor(
                                                    item.id,
                                                  )
                                                : AppColors.border,
                                          ),
                                        ),
                                        avatar: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: AnalyticsMetricVisuals.colorFor(
                                              item.id,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        label: Text(
                                          localizations.get(item.titleKey),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: item.id == _selectedMetricId
                                                ? AnalyticsMetricVisuals.colorFor(
                                                    item.id,
                                                  )
                                                : AppColors.lightForeground,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: relatedMetrics.take(2).map((item) {
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: item == relatedMetrics.first
                                            ? 8
                                            : 0,
                                      ),
                                      child: _MiniMetricCard(metric: item),
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCompare(
    BuildContext context,
    AnalyticsViewData viewData,
    AnalyticsMetricUiModel metric,
  ) async {
    final selection = await Navigator.of(context).push<AnalyticsCompareSelection>(
      MaterialPageRoute(
        builder: (_) => AnalyticsCompareMetricsPage(
          initialPrimaryMetricId: metric.id,
          initialSelectedMetricIds: _selectedCompareMetricIds.isNotEmpty
              ? _selectedCompareMetricIds
              : metric.relatedMetricIds.take(2).toList(growable: false),
          initialFilterId: _selectedFilterId,
        ),
      ),
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCompareMetricIds = selection.metricIds
          .where((id) => id != _selectedMetricId)
          .toList(growable: false);
      _normalizedComparison = selection.normalized;
      _selectedFilterId = selection.filterId;
    });

    if (selection.filterId != viewData.selectedFilterId) {
      await _cubit.selectFilter(selection.filterId);
    }
  }

  String _deltaText(AppLocalizations localizations, AnalyticsMetricUiModel metric) {
    final delta = metric.latestValue - metric.averageValue;
    final sign = delta >= 0 ? '+' : '-';
    final formattedDelta = formatMetricValue(delta.abs(), metric.unit);
    return '$sign$formattedDelta ${metric.unit} ${localizations.get('vsAverage')}';
  }
}

class _LegendPill extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final bool active;

  const _LegendPill({
    required this.metric,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF253039)
            : const Color(0xFF2A3138),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AnalyticsMetricVisuals.colorFor(metric.id),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).get(metric.titleKey),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE5EEF5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final String value;

  const _ValueChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3138),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final AnalyticsMetricUiModel metric;

  const _MiniMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).get(metric.titleKey),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMetricValueWithUnit(metric.latestValue, metric.unit),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.lightForeground,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: AnalyticsSparklineChart(metric: metric, isDark: false),
          ),
        ],
      ),
    );
  }
}
