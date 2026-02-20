part of 'splash_cubit.dart';

@freezed
class SplashState with _$SplashState {
  const factory SplashState.initial() = _Initial;
  const factory SplashState.loading() = _Loading;
  const factory SplashState.ready({
    required SplashViewData data,
  }) = _Ready;
  const factory SplashState.completed() = _Completed;
  const factory SplashState.error({
    required String message,
  }) = _Error;
}
