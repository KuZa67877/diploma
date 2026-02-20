part of 'onboarding_cubit.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState.initial() = _Initial;
  const factory OnboardingState.loading() = _Loading;
  const factory OnboardingState.loaded({
    required List<OnboardingSlideUiModel> slides,
  }) = _Loaded;
  const factory OnboardingState.error({
    required String message,
  }) = _Error;
}
