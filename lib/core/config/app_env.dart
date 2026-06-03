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
  static const String _firebaseSyncFromDartDefine = String.fromEnvironment(
    'ENABLE_FIREBASE_SYNC',
    defaultValue: '',
  );
  static const String _socialAuthFromDartDefine = String.fromEnvironment(
    'ENABLE_SOCIAL_AUTH',
    defaultValue: '',
  );
  static const String _authBypassFromDartDefine = String.fromEnvironment(
    'ENABLE_AUTH_BYPASS',
    defaultValue: '',
  );
  static const String _firebasePerformanceFromDartDefine =
      String.fromEnvironment('ENABLE_FIREBASE_PERFORMANCE', defaultValue: '');

  static String get appFlavor {
    final compileTimeFlavor = _flavorFromDartDefine.isNotEmpty
        ? _flavorFromDartDefine
        : _fallbackFlavorFromDartDefine;
    if (compileTimeFlavor.isNotEmpty) {
      return compileTimeFlavor.toLowerCase();
    }

    final envFlavor = (_readEnv('APP_FLAVOR') ?? '').trim().toLowerCase();
    if (envFlavor.isNotEmpty) {
      return envFlavor;
    }

    return kReleaseMode ? 'prod' : 'dev';
  }

  static bool get isDevFlavor => appFlavor == 'dev';

  static bool get isProdFlavor => appFlavor == 'prod';

  /// Feature flag for remote Firebase sync/auth.
  static bool get enableFirebaseSync => _readBool(
    dartDefineValue: _firebaseSyncFromDartDefine,
    envKey: 'ENABLE_FIREBASE_SYNC',
    defaultValue: true,
  );

  /// Флаг отображения соц. авторизации в UI.
  static bool get enableSocialAuth => _readBool(
    dartDefineValue: _socialAuthFromDartDefine,
    envKey: 'ENABLE_SOCIAL_AUTH',
    defaultValue: false,
  );

  /// Dev-флаг для пропуска реальной авторизации.
  static bool get enableAuthBypass => _readBool(
    dartDefineValue: _authBypassFromDartDefine,
    envKey: 'ENABLE_AUTH_BYPASS',
    defaultValue: false,
  );

  /// Флаг отправки custom traces в Firebase Performance Monitoring.
  static bool get enableFirebasePerformance => _readBool(
    dartDefineValue: _firebasePerformanceFromDartDefine,
    envKey: 'ENABLE_FIREBASE_PERFORMANCE',
    defaultValue: true,
  );

  /// Optional full URL of the AI proxy endpoint, e.g. https://foo.workers.dev/ai/chat
  static String get aiProxyUrl => (_readEnv('AI_PROXY_URL') ?? '').trim();

  /// Groq API key. Legacy DeepSeek keys are also respected for backwards compatibility.
  static String get groqApiKey =>
      _readEnv('GROQ_API_KEY') ?? _readEnv('DEEPSEEK_API_KEY') ?? '';

  /// Groq OpenAI-compatible base URL.
  static String get groqBaseUrl =>
      _readEnv('GROQ_BASE_URL') ??
      _readEnv('DEEPSEEK_BASE_URL') ??
      'https://api.groq.com/openai/v1';

  /// Default text-only model for Groq.
  static String get groqTextModel =>
      _readEnv('GROQ_TEXT_MODEL') ??
      _readEnv('GROQ_MODEL') ??
      _readEnv('DEEPSEEK_MODEL') ??
      'llama-3.1-8b-instant';

  /// Default vision-capable model for Groq.
  static String get groqVisionModel =>
      _readEnv('GROQ_VISION_MODEL') ??
      'meta-llama/llama-4-scout-17b-16e-instruct';

  /// Legacy getter kept to avoid broad refactors in older code.
  static String get deepSeekApiKey => groqApiKey;

  /// Legacy getter kept to avoid broad refactors in older code.
  static String get deepSeekBaseUrl => groqBaseUrl;

  /// Legacy getter kept to avoid broad refactors in older code.
  static String get deepSeekModel => groqTextModel;

  static String? _readEnv(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  static bool _readBool({
    required String dartDefineValue,
    required String envKey,
    required bool defaultValue,
  }) {
    final normalizedDartDefine = dartDefineValue.trim().toLowerCase();
    if (normalizedDartDefine == 'true') {
      return true;
    }
    if (normalizedDartDefine == 'false') {
      return false;
    }

    final envValue = (_readEnv(envKey) ?? '').trim().toLowerCase();
    if (envValue == 'true') {
      return true;
    }
    if (envValue == 'false') {
      return false;
    }

    return defaultValue;
  }
}
