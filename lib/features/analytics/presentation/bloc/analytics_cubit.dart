import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/activity_sample.dart';
import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/analytics_filter_option.dart';
import '../../domain/entities/analytics_insight.dart';
import '../../domain/entities/analytics_metric_series.dart';
import '../../domain/entities/heart_rate_sample.dart';
import '../../domain/usecases/get_analytics_data.dart';
import '../models/analytics_ui_models.dart';

part 'analytics_cubit.freezed.dart';
part 'analytics_state.dart';

class AnalyticsCubit extends Cubit<AnalyticsState> {
  final GetAnalyticsData getAnalyticsData;

  AnalyticsCubit({required this.getAnalyticsData})
    : super(const AnalyticsState.initial());

  Future<void> load({String? filterId}) async {
    emit(const AnalyticsState.loading());
    final result = await getAnalyticsData(
      AnalyticsParams(filterId: filterId ?? 'week'),
    );

    result.fold(
      (failure) =>
          emit(AnalyticsState.error(message: _mapFailureMessage(failure))),
      (data) => emit(AnalyticsState.loaded(data: _mapToViewData(data))),
    );
  }

  Future<void> selectFilter(String filterId) async {
    await load(filterId: filterId);
  }

  AnalyticsViewData _mapToViewData(AnalyticsData data) {
    return AnalyticsViewData(
      filters: _mapFilters(data.filters),
      selectedFilterId: data.selectedFilterId,
      heartRate: _mapHeartRate(data.heartRate),
      activity: _mapActivity(data.activity),
      metricSeries: _mapMetricSeries(data.metricSeries),
      featuredMetricIds: data.featuredMetricIds,
      insights: _mapInsights(data.insights),
      recordsCount: data.recordsCount,
      sourceCount: data.sourceCount,
      metricTypeCount: data.metricTypeCount,
      averageHeartRate: data.averageHeartRate,
      averageSteps: data.averageSteps,
      sleepAiScore: data.sleepAiScore,
      sleepAiConfidence: data.sleepAiConfidence,
      sleepAiStatus: data.sleepAiStatus,
      sleepAiReason: data.sleepAiReason,
    );
  }

  List<AnalyticsFilterUiModel> _mapFilters(
    List<AnalyticsFilterOption> filters,
  ) {
    return filters
        .map(
          (filter) =>
              AnalyticsFilterUiModel(id: filter.id, labelKey: filter.labelKey),
        )
        .toList(growable: false);
  }

  List<AnalyticsChartPoint> _mapHeartRate(List<HeartRateSample> data) {
    return data
        .map(
          (sample) => AnalyticsChartPoint(
            x: sample.hour.toDouble(),
            y: sample.bpm.toDouble(),
            label: sample.hour.toString().padLeft(2, '0'),
          ),
        )
        .toList(growable: false);
  }

  List<AnalyticsBarData> _mapActivity(List<ActivitySample> data) {
    return data
        .map(
          (sample) =>
              AnalyticsBarData(
                label: sample.label,
                value: sample.steps.toDouble(),
              ),
        )
        .toList(growable: false);
  }

  List<AnalyticsMetricUiModel> _mapMetricSeries(
    List<AnalyticsMetricSeries> data,
  ) {
    return data
        .map(
          (series) => AnalyticsMetricUiModel(
            id: series.id,
            titleKey: series.titleKey,
            unit: series.unit,
            chartStyle: switch (series.chartStyle) {
              AnalyticsMetricChartStyle.bar => AnalyticsMetricChartStyleUi.bar,
              AnalyticsMetricChartStyle.line =>
                AnalyticsMetricChartStyleUi.line,
            },
            points: series.points
                .map(
                  (point) => AnalyticsChartPoint(
                    x: point.x,
                    y: point.value,
                    label: point.label,
                  ),
                )
                .toList(growable: false),
            relatedMetricIds: series.relatedMetricIds,
            visibleByDefault: series.visibleByDefault,
            latestValue: series.latestValue,
            averageValue: series.averageValue,
            minValue: series.minValue,
            maxValue: series.maxValue,
          ),
        )
        .toList(growable: false);
  }

  List<AnalyticsInsightUiModel> _mapInsights(List<AnalyticsInsight> data) {
    return data
        .map(
          (insight) => AnalyticsInsightUiModel(
            titleKey: insight.titleKey,
            descKey: insight.descKey,
            severity: insight.severity,
          ),
        )
        .toList(growable: false);
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
