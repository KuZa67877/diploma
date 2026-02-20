import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/activity_sample.dart';
import '../../domain/entities/analytics_data.dart';
import '../../domain/entities/analytics_filter_option.dart';
import '../../domain/entities/analytics_insight.dart';
import '../../domain/entities/heart_rate_sample.dart';
import '../../domain/usecases/get_analytics_data.dart';
import '../models/analytics_ui_models.dart';

part 'analytics_cubit.freezed.dart';
part 'analytics_state.dart';

class AnalyticsCubit extends Cubit<AnalyticsState> {
  final GetAnalyticsData getAnalyticsData;

  AnalyticsCubit({
    required this.getAnalyticsData,
  }) : super(const AnalyticsState.initial());

  Future<void> load({String? filterId}) async {
    emit(const AnalyticsState.loading());
    final result = await getAnalyticsData(
      AnalyticsParams(filterId: filterId ?? 'week'),
    );

    result.fold(
      (failure) => emit(AnalyticsState.error(message: _mapFailureMessage(failure))),
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
      insights: _mapInsights(data.insights),
    );
  }

  List<AnalyticsFilterUiModel> _mapFilters(
    List<AnalyticsFilterOption> filters,
  ) {
    return filters
        .map(
          (filter) => AnalyticsFilterUiModel(
            id: filter.id,
            labelKey: filter.labelKey,
          ),
        )
        .toList(growable: false);
  }

  List<AnalyticsChartPoint> _mapHeartRate(List<HeartRateSample> data) {
    return data
        .map(
          (sample) => AnalyticsChartPoint(
            x: sample.hour.toDouble(),
            y: sample.bpm.toDouble(),
          ),
        )
        .toList(growable: false);
  }

  List<AnalyticsBarData> _mapActivity(List<ActivitySample> data) {
    return data
        .map(
          (sample) => AnalyticsBarData(
            label: sample.label,
            steps: sample.steps,
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
