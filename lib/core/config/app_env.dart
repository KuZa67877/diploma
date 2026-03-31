import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация окружения приложения.
class AppEnv {
  static const String _flavorFromDartDefine = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: '',
  );
  static const String _fallbackFlavorFromDartDefine = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: '',
  );

  static String get appFlavor {
    final compileTimeFlavor = _flavorFromDartDefine.isNotEmpty
        ? _flavorFromDartDefine
        : _fallbackFlavorFromDartDefine;
    if (compileTimeFlavor.isNotEmpty) {
      return compileTimeFlavor.toLowerCase();
    }

    final envFlavor = (dotenv.env['APP_FLAVOR'] ?? '').trim().toLowerCase();
    if (envFlavor.isNotEmpty) {
      return envFlavor;
    }

    return kReleaseMode ? 'prod' : 'dev';
  }

  static bool get isDevFlavor => appFlavor == 'dev';

  static bool get isProdFlavor => appFlavor == 'prod';

  /// URL проекта Supabase.
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://YOUR_PROJECT.supabase.co';

  /// Анонимный ключ Supabase.
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY';

  /// Redirect URL для OAuth-провайдеров Supabase.
  static String get supabaseRedirectUrl =>
      dotenv.env['SUPABASE_REDIRECT_URL'] ??
      'io.supabase.medi_ai://login-callback';

  /// Флаг отображения соц. авторизации в UI.
  static bool get enableSocialAuth =>
      (dotenv.env['ENABLE_SOCIAL_AUTH'] ?? 'false').toLowerCase() == 'true';

  /// Dev-флаг для пропуска реальной авторизации.
  static bool get enableAuthBypass =>
      (dotenv.env['ENABLE_AUTH_BYPASS'] ?? 'false').toLowerCase() == 'true';

  /// Признак того, что Supabase настроен.
  static bool get isSupabaseConfigured {
    final urlOk = !supabaseUrl.contains('YOUR_PROJECT');
    final keyOk = !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
    return urlOk && keyOk;
  }
}
