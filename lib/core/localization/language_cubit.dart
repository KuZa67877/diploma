import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

part 'language_cubit.freezed.dart';
part 'language_state.dart';

class LanguageCubit extends Cubit<LanguageState> {
  static const String _languageKey = 'app_language';
  final SharedPreferences _prefs;

  LanguageCubit(this._prefs)
      : super(const LanguageState(language: AppLanguage.english)) {
    _loadLanguage();
  }

  void _loadLanguage() {
    final languageCode = _prefs.getString(_languageKey) ?? 'en';
    emit(LanguageState(language: AppLanguage.fromCode(languageCode)));
  }

  Future<void> setLanguage(AppLanguage language) async {
    await _prefs.setString(_languageKey, language.code);
    emit(LanguageState(language: language));
  }

  Future<void> toggleLanguage() async {
    final newLanguage = state.language == AppLanguage.english
        ? AppLanguage.russian
        : AppLanguage.english;
    await setLanguage(newLanguage);
  }
}
