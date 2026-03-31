import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_env.dart';
import '../logging/app_logger.dart';

StreamSubscription<AuthState>? _authSubscription;

/// Инициализация Supabase.
Future<bool> initSupabase() async {
  final logger = AppLogger.instance;

  if (!AppEnv.isSupabaseConfigured) {
    logger.warning(
      'supabase.init',
      'Supabase is not configured. Running in local/mock auth mode.',
    );
    return false;
  }

  logger.info('supabase.init', 'Initializing Supabase client');
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    logger.info('supabase.init', 'Supabase initialized successfully');
  } catch (error, stackTrace) {
    logger.error(
      'supabase.init',
      'Supabase initialization failed',
      payload: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
    );
    rethrow;
  }

  _authSubscription?.cancel();
  _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
    authState,
  ) {
    logger.info(
      'supabase.auth',
      'Auth state changed: ${authState.event.name}',
      payload: {
        'userId': authState.session?.user.id,
        'email': authState.session?.user.email,
        'hasSession': authState.session != null,
      },
    );
  });

  return true;
}
