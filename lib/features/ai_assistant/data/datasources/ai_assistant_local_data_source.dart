import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_env.dart';
import '../../domain/entities/ai_assistant_settings.dart';
import '../../domain/entities/ai_cached_response.dart';

abstract class AiAssistantLocalDataSource {
  Future<AiAssistantSettings> getSettings();

  Future<void> saveSettings(AiAssistantSettings settings);

  Future<AiCachedResponse?> getCachedResponse(String promptHash);

  Future<void> saveCachedResponse(AiCachedResponse response);
}

class AiAssistantLocalDataSourceImpl implements AiAssistantLocalDataSource {
  static const String _settingsKey = 'ai_assistant_settings_v1';
  static const String _cacheKey = 'ai_assistant_cache_v1';

  final SharedPreferences _sharedPreferences;

  AiAssistantLocalDataSourceImpl({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  @override
  Future<AiAssistantSettings> getSettings() async {
    final raw = _sharedPreferences.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return _applyEnvOverrides(
        AiAssistantSettings.defaults(
          apiKey: AppEnv.groqApiKey,
          baseUrl: AppEnv.groqBaseUrl,
          model: AppEnv.groqTextModel,
          visionModel: AppEnv.groqVisionModel,
        ),
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _applyEnvOverrides(const AiAssistantSettings.defaults());
      }
      final settings = AiAssistantSettings.fromJson(decoded);
      final migratedSettings = settings.copyWith(
        baseUrl: settings.baseUrl == 'https://api.deepseek.com'
            ? AppEnv.groqBaseUrl
            : settings.baseUrl,
        model: settings.model == 'deepseek-chat'
            ? AppEnv.groqTextModel
            : settings.model,
        visionModel: settings.visionModel.trim().isEmpty
            ? AppEnv.groqVisionModel
            : settings.visionModel,
      );
      return _applyEnvOverrides(migratedSettings);
    } catch (_) {
      return _applyEnvOverrides(
        AiAssistantSettings.defaults(
          apiKey: AppEnv.groqApiKey,
          baseUrl: AppEnv.groqBaseUrl,
          model: AppEnv.groqTextModel,
          visionModel: AppEnv.groqVisionModel,
        ),
      );
    }
  }

  AiAssistantSettings _applyEnvOverrides(AiAssistantSettings settings) {
    final envApiKey = AppEnv.groqApiKey.trim();
    final envBaseUrl = AppEnv.groqBaseUrl.trim();
    final envTextModel = AppEnv.groqTextModel.trim();
    final envVisionModel = AppEnv.groqVisionModel.trim();

    return settings.copyWith(
      apiKey: envApiKey.isNotEmpty ? envApiKey : settings.apiKey,
      baseUrl: envBaseUrl.isNotEmpty ? envBaseUrl : settings.baseUrl,
      model: envTextModel.isNotEmpty ? envTextModel : settings.model,
      visionModel: envVisionModel.isNotEmpty
          ? envVisionModel
          : settings.visionModel,
    );
  }

  @override
  Future<void> saveSettings(AiAssistantSettings settings) async {
    // TODO: In production the API key must not live in client storage.
    // Use a backend proxy plus server-side usage limiting instead.
    await _sharedPreferences.setString(
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  @override
  Future<AiCachedResponse?> getCachedResponse(String promptHash) async {
    final cache = _readCacheMap();
    final entry = cache[promptHash];
    if (entry == null || entry.isExpired()) {
      if (entry != null) {
        cache.remove(promptHash);
        await _writeCacheMap(cache);
      }
      return null;
    }
    return entry;
  }

  @override
  Future<void> saveCachedResponse(AiCachedResponse response) async {
    final cache = _readCacheMap()
      ..removeWhere((_, value) => value.isExpired())
      ..[response.promptHash] = response;
    await _writeCacheMap(cache);
  }

  Map<String, AiCachedResponse> _readCacheMap() {
    final raw = _sharedPreferences.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, AiCachedResponse>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, AiCachedResponse>{};
      }
      return decoded.map<String, AiCachedResponse>((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key, AiCachedResponse.fromJson(value));
        }
        return MapEntry(
          key,
          AiCachedResponse.fromJson(Map<String, dynamic>.from(value as Map)),
        );
      });
    } catch (_) {
      return <String, AiCachedResponse>{};
    }
  }

  Future<void> _writeCacheMap(Map<String, AiCachedResponse> cache) async {
    final encoded = cache.map<String, dynamic>(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await _sharedPreferences.setString(_cacheKey, jsonEncode(encoded));
  }
}
