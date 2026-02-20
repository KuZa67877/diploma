import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Обновляет состояние подключения источника.
  Future<void> setSourceConnection(String sourceId, bool isConnected);
}

/// Реализация локального источника через JSON-ресурсы.
class HealthDataLocalDataSourceImpl implements HealthDataLocalDataSource {
  static const String _connectedSourcesKey = 'health_connected_sources';
  static const String _assetPath = 'assets/data/health_data.json';
  final SharedPreferences sharedPreferences;
  Set<String>? _connectedSourceIds;
  List<HealthDataSourceModel>? _cachedSources;
  List<HealthMetricSampleModel>? _cachedSamples;

  HealthDataLocalDataSourceImpl({
    required this.sharedPreferences,
  });

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
    _connectedSourceIds ??= _loadConnectedSourceIds();
    return Set.unmodifiable(_connectedSourceIds ?? const {});
  }

  @override
  Future<void> setSourceConnection(String sourceId, bool isConnected) async {
    _connectedSourceIds ??= _loadConnectedSourceIds();
    final next = Set<String>.from(_connectedSourceIds ?? const {});
    if (isConnected) {
      next.add(sourceId);
    } else {
      next.remove(sourceId);
    }
    _connectedSourceIds = next;
    await sharedPreferences.setStringList(
      _connectedSourcesKey,
      next.toList(growable: false),
    );
  }

  Set<String> _loadConnectedSourceIds() {
    final stored =
        sharedPreferences.getStringList(_connectedSourcesKey) ?? const [];
    return stored.toSet();
  }

  Future<List<HealthDataSourceModel>> _loadSources() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final sources = decoded['sources'] as List<dynamic>? ?? const [];
    return sources
        .map(
          (item) => HealthDataSourceModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<HealthMetricSampleModel>> _loadSamples() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final samples = decoded['samples'] as List<dynamic>? ?? const [];
    return samples
        .map(
          (item) => HealthMetricSampleModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
