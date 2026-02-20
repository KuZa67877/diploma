import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/error/failures.dart';
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

  AuthRemoteDataSourceImpl({
    required SupabaseClient Function() clientProvider,
  }) : _clientProvider = clientProvider;

  @override
  Future<AuthResultModel> submit(AuthCredentialsModel credentials) async {
    _ensureConfigured();
    final client = _clientProvider();
    if (credentials.isLogin) {
      await client.auth.signInWithPassword(
        email: credentials.email,
        password: credentials.password,
      );
    } else {
      await client.auth.signUp(
        email: credentials.email,
        password: credentials.password,
      );
    }

    return const AuthResultModel(isAuthenticated: true);
  }

  @override
  Future<AuthResultModel> signInWithGoogle() async {
    _ensureConfigured();
    final client = _clientProvider();
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppEnv.supabaseRedirectUrl,
    );
    return const AuthResultModel(isAuthenticated: true);
  }

  @override
  Future<AuthResultModel> signInWithApple() async {
    _ensureConfigured();
    final client = _clientProvider();
    await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: AppEnv.supabaseRedirectUrl,
    );
    return const AuthResultModel(isAuthenticated: true);
  }

  void _ensureConfigured() {
    if (!AppEnv.isSupabaseConfigured) {
      throw const AuthFailure('Supabase не настроен');
    }
  }
}
