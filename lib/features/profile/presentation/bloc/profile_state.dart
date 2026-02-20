part of 'profile_cubit.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading;
  const factory ProfileState.loaded({
    required ProfileViewData data,
  }) = _Loaded;
  const factory ProfileState.error({
    required String message,
  }) = _Error;
}
