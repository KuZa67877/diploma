import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../bloc/analytics_cubit.dart';
import '../models/analytics_ui_models.dart';
import '../widgets/analytics_metric_support.dart';
import '../widgets/analytics_time_filters.dart';
import '../widgets/analytics_error_state.dart';

class AnalyticsCompareSelection {
  final List<String> metricIds;
  final bool normalized;
  final String filterId;

  const AnalyticsCompareSelection({
    required this.metricIds,
    required this.normalized,
    required this.filterId,
  });
}

class AnalyticsCompareMetricsPage extends StatefulWidget {
  final String initialPrimaryMetricId;
  final List<String> initialSelectedMetricIds;
  final String initialFilterId;

  const AnalyticsCompareMetricsPage({
    super.key,
    required this.initialPrimaryMetricId,
    required this.initialSelectedMetricIds,
    required this.initialFilterId,
  });

  @override
  State<AnalyticsCompareMetricsPage> createState() =>
      _AnalyticsCompareMetricsPageState();
}

class _AnalyticsCompareMetricsPageState
    extends State<AnalyticsCompareMetricsPage> {
  late final AnalyticsCubit _cubit;
  late String _selectedFilterId;
  late String _primaryMetricId;
  late Set<String> _selectedMetricIds;
  bool _normalized = true;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<AnalyticsCubit>();
    _primaryMetricId = widget.initialPrimaryMetricId;
    _selectedFilterId = widget.initialFilterId;
    _selectedMetricIds = {
      _primaryMetricId,
      ...widget.initialSelectedMetricIds,
    };
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

          final localizations = AppLocalizations.of(context);
          final primaryMetric =
              viewData.metricById(_primaryMetricId) ?? viewData.metricSeries.first;
          _primaryMetricId = primaryMetric.id;
          _selectedMetricIds.add(_primaryMetricId);

          final selectedMetrics = viewData.metricSeries
              .where((metric) => _selectedMetricIds.contains(metric.id))
              .toList(growable: false);

          final compareMetrics = selectedMetrics
              .where((metric) => metric.id != _primaryMetricId)
              .toList(growable: false);

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _Header(
                      title: localizations.get('compareMetrics'),
                      subtitle: localizations.get('chooseAdjacentCharts'),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DarkCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.get('combinedTrends'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: selectedMetrics
                                        .map(
                                          (metric) => _LegendPill(metric: metric),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 172,
                                    child: AnalyticsSeriesChart(
                                      primaryMetric: primaryMetric,
                                      compareMetrics: compareMetrics,
                                      normalized: _normalized,
                                      darkSurface: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AnalyticsAxisLabels(
                                    points: primaryMetric.points,
                                    color: const Color(0xFF94A3B8),
                                    maxLabels: 4,
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LightCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.get('displayedOnChart'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lightForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...viewData.metricSeries.map(
                                    (metric) => _MetricToggleRow(
                                      metric: metric,
                                      enabled: _selectedMetricIds.contains(metric.id),
                                      locked: metric.id == _primaryMetricId,
                                      onChanged: (enabled) {
                                        setState(() {
                                          if (enabled) {
                                            if (_selectedMetricIds.length < 4) {
                                              _selectedMetricIds.add(metric.id);
                                            }
                                          } else if (metric.id != _primaryMetricId) {
                                            _selectedMetricIds.remove(metric.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    localizations.get('scaleMode'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lightForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _ScaleSelector(
                                    normalized: _normalized,
                                    onChanged: (value) =>
                                        setState(() => _normalized = value),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.muted,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            localizations.get('normalizedScaleHint'),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.lightForeground,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(
                              AnalyticsCompareSelection(
                                metricIds: _selectedMetricIds.toList(growable: false),
                                normalized: _normalized,
                                filterId: _selectedFilterId,
                              ),
                            );
                          },
                          child: Text(localizations.get('applyComparison')),
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
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightForeground,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  final Widget child;

  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2429),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF323A42)),
      ),
      child: child,
    );
  }
}

class _LightCard extends StatelessWidget {
  final Widget child;

  const _LightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _LegendPill extends StatelessWidget {
  final AnalyticsMetricUiModel metric;

  const _LegendPill({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3138),
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

class _MetricToggleRow extends StatelessWidget {
  final AnalyticsMetricUiModel metric;
  final bool enabled;
  final bool locked;
  final ValueChanged<bool> onChanged;

  const _MetricToggleRow({
    required this.metric,
    required this.enabled,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return InkWell(
      onTap: locked ? null : () => onChanged(!enabled),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: enabled,
              onChanged: locked ? null : (value) => onChanged(value ?? false),
              activeColor: AnalyticsMetricVisuals.colorFor(metric.id),
            ),
            Expanded(
              child: Text(
                localizations.get(metric.titleKey),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightForeground,
                ),
              ),
            ),
            Text(
              enabled
                  ? localizations.get('visible')
                  : localizations.get('off'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.primary : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleSelector extends StatelessWidget {
  final bool normalized;
  final ValueChanged<bool> onChanged;

  const _ScaleSelector({
    required this.normalized,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: normalized ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: normalized ? Border.all(color: AppColors.border) : null,
                ),
                child: Text(
                  localizations.get('normalized'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: normalized ? FontWeight.w600 : FontWeight.w500,
                    color: normalized
                        ? AppColors.lightForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !normalized ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      !normalized ? Border.all(color: AppColors.border) : null,
                ),
                child: Text(
                  localizations.get('absolute'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: !normalized ? FontWeight.w600 : FontWeight.w500,
                    color: !normalized
                        ? AppColors.lightForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
