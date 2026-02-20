part of 'language_cubit.dart';

@freezed
class LanguageState with _$LanguageState {
  const factory LanguageState({
    required AppLanguage language,
  }) = _LanguageState;
}
