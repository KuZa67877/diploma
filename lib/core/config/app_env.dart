import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация окружения приложения.
class AppEnv {
  /// URL проекта Supabase.
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://YOUR_PROJECT.supabase.co';

  /// Анонимный ключ Supabase.
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY';

  /// Redirect URL для OAuth-провайдеров Supabase.
  static String get supabaseRedirectUrl =>
      dotenv.env['SUPABASE_REDIRECT_URL'] ?? 'io.supabase.medi_ai://login-callback';

  /// Флаг отображения соц. авторизации в UI.
  static bool get enableSocialAuth =>
      (dotenv.env['ENABLE_SOCIAL_AUTH'] ?? 'false').toLowerCase() == 'true';

  /// Признак того, что Supabase настроен.
  static bool get isSupabaseConfigured {
    final urlOk = !supabaseUrl.contains('YOUR_PROJECT');
    final keyOk = !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
    return urlOk && keyOk;
  }
}
