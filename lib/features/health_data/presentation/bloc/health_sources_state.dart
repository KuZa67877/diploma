part of 'health_sources_cubit.dart';

/// Состояния экрана источников данных здоровья.
@freezed
class HealthSourcesState with _$HealthSourcesState {
  /// Начальное состояние.
  const factory HealthSourcesState.initial() = _Initial;

  /// Состояние загрузки.
  const factory HealthSourcesState.loading() = _Loading;

  /// Состояние ошибки.
  const factory HealthSourcesState.error({required String message}) = _Error;

  /// Состояние данных.
  const factory HealthSourcesState.loaded({
    required List<HealthSourceUiModel> sources,
    required String? updatingSourceId,
  }) = _Loaded;
}
