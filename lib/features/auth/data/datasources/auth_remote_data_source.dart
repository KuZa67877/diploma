import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_result_model.dart';

/// Контракт удаленного источника авторизации.
abstract class AuthRemoteDataSource {
  Future<AuthResultModel> submit(AuthCredentialsModel credentials);
  Future<AuthResultModel> signInWithGoogle();
  Future<AuthResultModel> signInWithApple();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient Function() _clientProvider;
  final _logger = AppLogger.instance;

  AuthRemoteDataSourceImpl({required SupabaseClient Function() clientProvider})
    : _clientProvider = clientProvider;

  @override
  Future<AuthResultModel> submit(AuthCredentialsModel credentials) async {
    _ensureConfigured();
    final client = _clientProvider();
    final action = credentials.isLogin ? 'signInWithPassword' : 'signUp';
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'auth.request',
      '$action started',
      payload: {'email': credentials.email},
    );

    if (credentials.isLogin) {
      try {
        final response = await client.auth.signInWithPassword(
          email: credentials.email,
          password: credentials.password,
        );
        if (response.session == null) {
          throw const AuthFailure(
            'Не удалось создать сессию. Попробуйте войти снова.',
          );
        }
        _logger.info(
          'auth.response',
          '$action success',
          payload: {
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'userId': response.user?.id,
            'hasSession': response.session != null,
          },
        );
      } catch (error, stackTrace) {
        _logger.error(
          'auth.response',
          '$action failed',
          payload: {
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'email': credentials.email,
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
        rethrow;
      }
    } else {
      try {
        final response = await client.auth.signUp(
          email: credentials.email,
          password: credentials.password,
        );
        if (response.session == null) {
          throw const AuthFailure(
            'Аккаунт создан. Подтвердите email и войдите в приложение.',
          );
        }
        _logger.info(
          'auth.response',
          '$action success',
          payload: {
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'userId': response.user?.id,
            'hasSession': response.session != null,
          },
        );
      } catch (error, stackTrace) {
        _logger.error(
          'auth.response',
          '$action failed',
          payload: {
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'email': credentials.email,
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
        rethrow;
      }
    }

    return const AuthResultModel(isAuthenticated: true);
  }

  @override
  Future<AuthResultModel> signInWithGoogle() async {
    _ensureConfigured();
    final client = _clientProvider();
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'auth.request',
      'signInWithOAuth started',
      payload: {'provider': 'google'},
    );

    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppEnv.supabaseRedirectUrl,
      );
      _logger.info(
        'auth.response',
        'signInWithOAuth completed',
        payload: {
          'provider': 'google',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'auth.response',
        'signInWithOAuth failed',
        payload: {
          'provider': 'google',
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }

    return const AuthResultModel(isAuthenticated: true);
  }

  @override
  Future<AuthResultModel> signInWithApple() async {
    _ensureConfigured();
    final client = _clientProvider();
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'auth.request',
      'signInWithOAuth started',
      payload: {'provider': 'apple'},
    );

    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: AppEnv.supabaseRedirectUrl,
      );
      _logger.info(
        'auth.response',
        'signInWithOAuth completed',
        payload: {
          'provider': 'apple',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'auth.response',
        'signInWithOAuth failed',
        payload: {
          'provider': 'apple',
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }

    return const AuthResultModel(isAuthenticated: true);
  }

  void _ensureConfigured() {
    if (!AppEnv.isSupabaseConfigured) {
      _logger.error(
        'auth.request',
        'Supabase is not configured for remote auth request',
      );
      throw const AuthFailure('Supabase не настроен');
    }
  }
}
