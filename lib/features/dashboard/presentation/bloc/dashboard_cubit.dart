import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/dashboard_insight.dart';
import '../../domain/entities/dashboard_metric.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../models/dashboard_ui_models.dart';
import '../widgets/mini_chart.dart';

part 'dashboard_cubit.freezed.dart';
part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetDashboardSummary getDashboardSummary;

  DashboardCubit({
    required this.getDashboardSummary,
  }) : super(const DashboardState.initial());

  Future<void> load() async {
    emit(const DashboardState.loading());

    final result = await getDashboardSummary(const NoParams());
    result.fold(
      (failure) => emit(DashboardState.error(message: _mapFailureMessage(failure))),
      (summary) => emit(DashboardState.loaded(data: _mapToViewData(summary))),
    );
  }

  DashboardViewData _mapToViewData(DashboardSummary summary) {
    return DashboardViewData(
      greetingKey: summary.greetingKey,
      userName: summary.userName,
      healthScore: summary.healthScore,
      status: summary.status,
      insight: _mapInsight(summary.insight),
      metrics: _mapMetrics(summary.metrics),
    );
  }

  DashboardInsightUiModel _mapInsight(DashboardInsight insight) {
    return DashboardInsightUiModel(
      titleKey: insight.titleKey,
      descKey: insight.descKey,
    );
  }

  List<DashboardMetricUiModel> _mapMetrics(List<DashboardMetric> metrics) {
    return metrics
        .map(
          (metric) => DashboardMetricUiModel(
            id: metric.id,
            icon: _mapIcon(metric.id),
            labelKey: metric.labelKey,
            value: metric.value,
            unit: metric.unit,
            trend: _mapTrend(metric.trend),
            data: metric.data,
          ),
        )
        .toList(growable: false);
  }

  ChartTrend _mapTrend(String trend) {
    switch (trend) {
      case 'up':
        return ChartTrend.up;
      case 'down':
        return ChartTrend.down;
      default:
        return ChartTrend.stable;
    }
  }

  IconData _mapIcon(String id) {
    switch (id) {
      case 'heart':
        return LucideIcons.heart;
      case 'sleep':
        return LucideIcons.moon;
      case 'steps':
        return LucideIcons.footprints;
      default:
        return LucideIcons.activity;
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
