import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_data_source_model.dart';
import '../models/health_metric_sample_model.dart';

/// Контракт локального источника данных здоровья.
abstract class HealthDataLocalDataSource {
  /// Возвращает список источников данных.
  Future<List<HealthDataSourceModel>> getSources();

  /// Возвращает локальные измерения метрик.
  Future<List<HealthMetricSampleModel>> getSamples();

  /// Возвращает идентификаторы подключенных источников.
  Future<Set<String>> getConnectedSourceIds();

  /// Возвращает кеш импортированных внешних метрик.
  Future<List<HealthMetricSampleModel>> getCachedExternalSamples();

  /// Обновляет состояние подключения источника.
  Future<void> setSourceConnection(String sourceId, bool isConnected);

  /// Сохраняет кеш импортированных внешних метрик.
  Future<void> saveCachedExternalSamples(List<HealthMetricSampleModel> samples);

  /// Очищает пользовательский кеш подключений и внешних сэмплов.
  Future<void> clearUserScopedCache();
}

/// Реализация локального источника через JSON-ресурсы.
class HealthDataLocalDataSourceImpl implements HealthDataLocalDataSource {
  static const String _connectedSourcesKeyBase = 'health_connected_sources';
  static const String _cachedExternalSamplesKeyBase =
      'health_cached_external_samples_v1';
  static const String _assetPath = 'assets/data/health_data.json';
  final SharedPreferences sharedPreferences;
  String? _activeScopeId;
  Set<String>? _connectedSourceIds;
  List<HealthDataSourceModel>? _cachedSources;
  List<HealthMetricSampleModel>? _cachedSamples;
  List<HealthMetricSampleModel>? _cachedExternalSamples;

  HealthDataLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<HealthDataSourceModel>> getSources() async {
    _cachedSources ??= await _loadSources();
    return _cachedSources ?? const [];
  }

  @override
  Future<List<HealthMetricSampleModel>> getSamples() async {
    _cachedSamples ??= await _loadSamples();
    return _cachedSamples ?? const [];
  }

  @override
  Future<Set<String>> getConnectedSourceIds() async {
    _ensureScope();
    _connectedSourceIds ??= _loadConnectedSourceIds();
    return Set.unmodifiable(_connectedSourceIds ?? const {});
  }

  @override
  Future<List<HealthMetricSampleModel>> getCachedExternalSamples() async {
    _ensureScope();
    _cachedExternalSamples ??= _loadCachedExternalSamples();
    return List.unmodifiable(_cachedExternalSamples ?? const []);
  }

  @override
  Future<void> setSourceConnection(String sourceId, bool isConnected) async {
    _ensureScope();
    _connectedSourceIds ??= _loadConnectedSourceIds();
    final next = Set<String>.from(_connectedSourceIds ?? const {});
    if (isConnected) {
      next.add(sourceId);
    } else {
      next.remove(sourceId);
    }
    _connectedSourceIds = next;
    await sharedPreferences.setStringList(
      _scopedKey(_connectedSourcesKeyBase),
      next.toList(growable: false),
    );
  }

  @override
  Future<void> saveCachedExternalSamples(
    List<HealthMetricSampleModel> samples,
  ) async {
    _ensureScope();
    _cachedExternalSamples = samples.toList(growable: false);
    final encoded = jsonEncode(
      _cachedExternalSamples!
          .map((sample) => sample.toJson())
          .toList(growable: false),
    );
    await sharedPreferences.setString(
      _scopedKey(_cachedExternalSamplesKeyBase),
      encoded,
    );
  }

  @override
  Future<void> clearUserScopedCache() async {
    _ensureScope();
    _connectedSourceIds = const {};
    _cachedExternalSamples = const [];
    await sharedPreferences.remove(_scopedKey(_connectedSourcesKeyBase));
    await sharedPreferences.remove(_scopedKey(_cachedExternalSamplesKeyBase));
  }

  Set<String> _loadConnectedSourceIds() {
    _ensureScope();
    final stored =
        sharedPreferences.getStringList(_scopedKey(_connectedSourcesKeyBase)) ??
        const [];
    return stored.toSet();
  }

  List<HealthMetricSampleModel> _loadCachedExternalSamples() {
    _ensureScope();
    final raw = sharedPreferences.getString(
      _scopedKey(_cachedExternalSamplesKeyBase),
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => HealthMetricSampleModel.fromJson(
              Map<String, dynamic>.from(item.cast<dynamic, dynamic>()),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _ensureScope() {
    final scopeId = _currentScopeId();
    if (_activeScopeId == scopeId) {
      return;
    }
    _activeScopeId = scopeId;
    _connectedSourceIds = null;
    _cachedExternalSamples = null;
  }

  String _currentScopeId() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return 'anonymous';
  }

  String _scopedKey(String base) => '${base}_${_activeScopeId ?? _currentScopeId()}';

  Future<List<HealthDataSourceModel>> _loadSources() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final sources = decoded['sources'] as List<dynamic>? ?? const [];
    return sources
        .map(
          (item) =>
              HealthDataSourceModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<HealthMetricSampleModel>> _loadSamples() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final samples = decoded['samples'] as List<dynamic>? ?? const [];
    return samples
        .map(
          (item) =>
              HealthMetricSampleModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
