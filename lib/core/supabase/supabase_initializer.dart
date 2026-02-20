import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_env.dart';

/// Инициализация Supabase.
Future<bool> initSupabase() async {
  if (!AppEnv.isSupabaseConfigured) {
    return false;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  return true;
}
