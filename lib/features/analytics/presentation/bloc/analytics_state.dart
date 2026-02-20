part of 'analytics_cubit.dart';

@freezed
class AnalyticsState with _$AnalyticsState {
  const factory AnalyticsState.initial() = _Initial;
  const factory AnalyticsState.loading() = _Loading;
  const factory AnalyticsState.loaded({
    required AnalyticsViewData data,
  }) = _Loaded;
  const factory AnalyticsState.error({
    required String message,
  }) = _Error;
}
