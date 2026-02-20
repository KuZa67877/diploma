import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_cubit.freezed.dart';
part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  static const String _themeKey = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeCubit(this._prefs)
      : super(const ThemeState(mode: ThemeMode.light)) {
    _loadTheme();
  }

  void _loadTheme() {
    final themeIndex = _prefs.getInt(_themeKey) ?? 0;
    emit(ThemeState(mode: ThemeMode.values[themeIndex]));
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    await _prefs.setInt(_themeKey, themeMode.index);
    emit(ThemeState(mode: themeMode));
  }

  Future<void> toggleTheme() async {
    final newTheme = state.mode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setTheme(newTheme);
  }
}
