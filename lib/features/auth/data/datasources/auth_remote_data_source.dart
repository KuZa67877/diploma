import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/firebase/firebase_initializer.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_result_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResultModel> submit(AuthCredentialsModel credentials);
  Future<AuthResultModel> signInWithGoogle();
  Future<AuthResultModel> signInWithApple();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth Function() _authProvider;
  final _logger = AppLogger.instance;

  AuthRemoteDataSourceImpl({required FirebaseAuth Function() authProvider})
    : _authProvider = authProvider;

  @override
  Future<AuthResultModel> submit(AuthCredentialsModel credentials) async {
    _ensureConfigured();
    final auth = _authProvider();
    final action = credentials.isLogin
        ? 'signInWithEmailAndPassword'
        : 'createUserWithEmailAndPassword';
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'auth.request',
      '$action started',
      payload: {'email': credentials.email},
    );

    try {
      final userCredential = credentials.isLogin
          ? await auth.signInWithEmailAndPassword(
              email: credentials.email,
              password: credentials.password,
            )
          : await auth.createUserWithEmailAndPassword(
              email: credentials.email,
              password: credentials.password,
            );
      if (userCredential.user == null) {
        throw const AuthFailure(
          'Не удалось создать сессию. Попробуйте войти снова.',
        );
      }
      _logger.info(
        'auth.response',
        '$action success',
        payload: {
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'userId': userCredential.user?.uid,
          'hasSession': userCredential.user != null,
        },
      );
      return const AuthResultModel(isAuthenticated: true);
    } on FirebaseAuthException catch (error, stackTrace) {
      _logger.error(
        'auth.response',
        '$action failed',
        payload: {
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'email': credentials.email,
          'error': error.code,
          'message': error.message,
          'stackTrace': stackTrace.toString(),
        },
      );
      throw AuthFailure(_mapAuthError(error));
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

  @override
  Future<AuthResultModel> signInWithGoogle() async {
    return _signInWithProvider(
      providerName: 'google',
      providerBuilder: () => GoogleAuthProvider(),
    );
  }

  @override
  Future<AuthResultModel> signInWithApple() async {
    return _signInWithProvider(
      providerName: 'apple',
      providerBuilder: () => AppleAuthProvider(),
    );
  }

  Future<AuthResultModel> _signInWithProvider({
    required String providerName,
    required AuthProvider Function() providerBuilder,
  }) async {
    _ensureConfigured();
    final auth = _authProvider();
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'auth.request',
      'signInWithProvider started',
      payload: {'provider': providerName},
    );

    try {
      if (kIsWeb) {
        await auth.signInWithPopup(providerBuilder());
      } else {
        await auth.signInWithProvider(providerBuilder());
      }
      _logger.info(
        'auth.response',
        'signInWithProvider completed',
        payload: {
          'provider': providerName,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return const AuthResultModel(isAuthenticated: true);
    } on FirebaseAuthException catch (error, stackTrace) {
      _logger.error(
        'auth.response',
        'signInWithProvider failed',
        payload: {
          'provider': providerName,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': error.code,
          'message': error.message,
          'stackTrace': stackTrace.toString(),
        },
      );
      throw AuthFailure(_mapAuthError(error));
    } catch (error, stackTrace) {
      _logger.error(
        'auth.response',
        'signInWithProvider failed',
        payload: {
          'provider': providerName,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }
  }

  void _ensureConfigured() {
    if (!isFirebaseReady) {
      _logger.error(
        'auth.request',
        'Firebase is not configured for remote auth request',
      );
      throw const AuthFailure('Firebase не настроен');
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Некорректный email';
      case 'email-already-in-use':
        return 'Аккаунт с таким email уже существует';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль';
      case 'weak-password':
        return 'Пароль должен быть не короче 6 символов';
      case 'network-request-failed':
        return 'Сетевая ошибка. Проверьте подключение и попробуйте снова.';
      case 'too-many-requests':
        return 'Слишком много попыток входа. Попробуйте позже.';
      default:
        return error.message ?? 'Ошибка авторизации';
    }
  }
}
