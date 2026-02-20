part of 'reports_cubit.dart';

@freezed
class ReportsState with _$ReportsState {
  const factory ReportsState.initial() = _Initial;
  const factory ReportsState.loading() = _Loading;
  const factory ReportsState.loaded({
    required ReportsViewData data,
  }) = _Loaded;
  const factory ReportsState.exportReady({
    required ReportsViewData data,
    required int itemsCount,
    required int sourcesCount,
  }) = _ExportReady;
  const factory ReportsState.exportFailed({
    required ReportsViewData data,
    required String message,
  }) = _ExportFailed;
  const factory ReportsState.error({
    required String message,
  }) = _Error;
}
