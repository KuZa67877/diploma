part of 'data_input_cubit.dart';

@freezed
class DataInputState with _$DataInputState {
  const factory DataInputState.initial() = _Initial;
  const factory DataInputState.loading() = _Loading;
  const factory DataInputState.ready({
    required DataInputViewData data,
  }) = _Ready;
  const factory DataInputState.submitting({
    required DataInputViewData data,
  }) = _Submitting;
  const factory DataInputState.success({
    required DataInputViewData data,
  }) = _Success;
  const factory DataInputState.error({
    required String message,
  }) = _Error;
}

@freezed
class DataInputViewData with _$DataInputViewData {
  const factory DataInputViewData({
    required DateTime selectedDate,
    required TimeOfDay selectedTime,
    required List<SymptomUiModel> symptoms,
    required Set<String> selectedSymptoms,
    required Map<String, String> errors,
  }) = _DataInputViewData;
}
