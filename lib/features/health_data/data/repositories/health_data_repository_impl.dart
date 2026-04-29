import 'package:dartz/dartz.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/health_data_source.dart';
import '../../domain/entities/health_date_range.dart';
import '../../domain/entities/health_data_source_type.dart';
import '../../domain/entities/health_metric_sample.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_metrics_query.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../datasources/google_fit_data_source.dart';
import '../datasources/health_data_local_data_source.dart';
import '../datasources/health_data_remote_data_source.dart';
import '../datasources/health_kit_data_source.dart';
import '../datasources/health_platform_mapper.dart';
import '../models/health_metric_sample_model.dart';

/// Реализация репозитория данных здоровья.
class HealthDataRepositoryImpl implements HealthDataRepository {
  static const String _appleSourceId = 'apple_health';
  static const String _googleSourceId = 'google_fit';
  static const Duration _externalImportWindow = Duration(days: 30);
  static const Duration _incrementalSyncLookback = Duration(days: 3);

  /// Локальный источник данных.
  final HealthDataLocalDataSource localDataSource;

  /// Удаленный источник синхронизации данных здоровья.
  final HealthDataRemoteDataSource remoteDataSource;

  /// Источник данных HealthKit.
  final HealthKitDataSource healthKitDataSource;

  /// Источник данных Google Fit.
  final GoogleFitDataSource googleFitDataSource;
  final DateTime Function() _nowProvider;

  /// Создает репозиторий данных здоровья.
  HealthDataRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.healthKitDataSource,
    required this.googleFitDataSource,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  @override
  Future<Either<Failure, List<HealthDataSource>>> getAvailableSources() async {
    try {
      await _syncRemoteStateToLocal();
      final sources = await localDataSource.getSources();
      final connectedIds = await localDataSource.getConnectedSourceIds();
      final mapped = sources
          .map(
            (source) => source.copyWith(
              supportedMetrics: _supportedMetricsForSource(source),
              isConnected: connectedIds.contains(source.id),
              isAvailable: _isSourceAvailable(source.type),
            ),
          )
          .toList();
      return Right(mapped);
    } catch (error) {
      return Left(CacheFailure('Не удалось загрузить источники данных.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> connectSource(String sourceId) async {
    try {
      await _syncRemoteStateToLocal();
      final source = await _getSourceById(sourceId);
      final isAvailable = _isSourceAvailable(source.type);
      if (!isAvailable) {
        return Left(
          PermissionFailure('Источник недоступен в текущем окружении.'),
        );
      }

      await _connectByType(source.type);
      await localDataSource.setSourceConnection(sourceId, true);
      await _prefetchConnectedSourceSamples(source);
      await _syncLocalStateToRemote();
      return const Right(unit);
    } catch (error) {
      return Left(ValidationFailure('Не удалось подключить источник.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnectSource(String sourceId) async {
    try {
      await _syncRemoteStateToLocal();
      final source = await _getSourceById(sourceId);
      await _disconnectByType(source.type);
      await localDataSource.setSourceConnection(sourceId, false);
      await _syncLocalStateToRemote();
      return const Right(unit);
    } catch (error) {
      return Left(ValidationFailure('Не удалось отключить источник.'));
    }
  }

  @override
  Future<Either<Failure, List<HealthMetricSample>>> getMetrics(
    HealthMetricsQuery query,
  ) async {
    try {
      await _syncRemoteStateToLocal();
      final sources = await localDataSource.getSources();
      final connectedIds = await localDataSource.getConnectedSourceIds();
      final allowedSourceIds = query.sourceId != null
          ? {_normalizeSourceId(query.sourceId!)}
          : query.onlyConnectedSources
          ? connectedIds
          : sources.map((item) => item.id).toSet();

      final allowedSources = sources
          .where((source) => allowedSourceIds.contains(source.id))
          .toList(growable: false);

      final localSourceIds = allowedSources
          .where((source) => source.type == HealthDataSourceType.local)
          .map((source) => source.id)
          .toSet();

      final localSamples = await localDataSource.getSamples();
      final filteredLocal = localSamples.where((sample) {
        final matchesSource = localSourceIds.contains(sample.sourceId);
        final matchesType =
            query.types.isEmpty || query.types.contains(sample.type);
        final matchesDate = _sampleMatchesRange(sample, query.range);
        return matchesSource && matchesType && matchesDate;
      }).toList();

      final cachedExternalAll = await localDataSource
          .getCachedExternalSamples();
      final filteredCachedExternal = cachedExternalAll
          .where((sample) {
            final normalizedSourceId = _normalizeSourceId(sample.sourceId);
            final matchesSource = allowedSourceIds.contains(normalizedSourceId);
            final matchesType =
                query.types.isEmpty || query.types.contains(sample.type);
            final matchesDate = _sampleMatchesRange(sample, query.range);
            return matchesSource && matchesType && matchesDate;
          })
          .toList(growable: false);

      final externalSamples = <HealthMetricSample>[];
      final externalRange = _capExternalRange(query.range);
      if (allowedSources.any(
        (source) => source.type == HealthDataSourceType.appleHealth,
      )) {
        externalSamples.addAll(
          await healthKitDataSource.getSamples(
            range: externalRange,
            types: query.types,
          ),
        );
      }
      if (allowedSources.any(
        (source) => source.type == HealthDataSourceType.googleFit,
      )) {
        externalSamples.addAll(
          await googleFitDataSource.getSamples(
            range: externalRange,
            types: query.types,
          ),
        );
      }

      if (externalSamples.isNotEmpty) {
        final mergedCache = _pruneExternalSamples(
          _mergeSamples(
            existing: cachedExternalAll,
            incoming: externalSamples.map(_toModel).toList(growable: false),
          ),
        );
        await localDataSource.saveCachedExternalSamples(mergedCache);
        await _syncLocalStateToRemote();
      }

      final mergedExternalForResult = _pruneExternalSamples(
        _mergeSamples(
          existing: filteredCachedExternal,
          incoming: externalSamples.map(_toModel).toList(growable: false),
        ),
      );

      return Right([...filteredLocal, ...mergedExternalForResult]);
    } catch (error) {
      return Left(CacheFailure('Не удалось получить метрики.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncConnectedSources() async {
    try {
      await _syncRemoteStateToLocal();
      final sources = await localDataSource.getSources();
      final connectedIds = await localDataSource.getConnectedSourceIds();
      final cached = await localDataSource.getCachedExternalSamples();
      final now = _now();

      var merged = cached;
      var updated = false;

      final connectedExternalSources = sources
          .where((source) {
            if (!connectedIds.contains(source.id)) {
              return false;
            }
            return source.type == HealthDataSourceType.appleHealth ||
                source.type == HealthDataSourceType.googleFit;
          })
          .toList(growable: false);

      for (final source in connectedExternalSources) {
        final fetched = await _fetchIncrementalSourceSamples(
          source: source,
          cached: merged,
          now: now,
        );
        if (fetched.isEmpty) {
          continue;
        }
        final nextMerged = _pruneExternalSamples(
          _mergeSamples(existing: merged, incoming: fetched),
        );
        if (!_sameSamples(merged, nextMerged)) {
          merged = nextMerged;
          updated = true;
        }
      }

      if (updated) {
        await localDataSource.saveCachedExternalSamples(merged);
        await _syncLocalStateToRemote();
      }

      return const Right(unit);
    } catch (error) {
      return Left(CacheFailure('Не удалось синхронизировать внешние данные.'));
    }
  }

  Future<void> _syncRemoteStateToLocal() async {
    if (!AppEnv.isSupabaseConfigured) {
      return;
    }

    try {
      final remoteSnapshot = await remoteDataSource.getSnapshot();
      final localCached = await localDataSource.getCachedExternalSamples();

      if (remoteSnapshot.isEmpty) {
        if (localCached.isNotEmpty) {
          await localDataSource.clearUserScopedCache();
        }
        return;
      }

      await _overwriteConnectedSources(remoteSnapshot.connectedSourceIds);

      final mergedCached = _mergeSamples(
        existing: localCached,
        incoming: remoteSnapshot.cachedSamples,
      );
      await localDataSource.saveCachedExternalSamples(
        _pruneExternalSamples(mergedCached),
      );
    } on AuthFailure {
      // Ignore when there's no active user session.
    } catch (_) {
      // Ignore remote sync issues and continue with local data.
    }
  }

  Future<void> _syncLocalStateToRemote() async {
    if (!AppEnv.isSupabaseConfigured) {
      return;
    }

    try {
      final connected = await localDataSource.getConnectedSourceIds();
      final cachedSamples = await localDataSource.getCachedExternalSamples();
      await remoteDataSource.saveSnapshot(
        HealthRemoteSnapshot(
          connectedSourceIds: connected,
          cachedSamples: _pruneExternalSamples(
            _mergeSamples(existing: const [], incoming: cachedSamples),
          ),
        ),
      );
    } on AuthFailure {
      // Ignore when there's no active user session.
    } catch (_) {
      // Ignore remote sync issues and continue with local data.
    }
  }

  Future<void> _overwriteConnectedSources(Set<String> remoteSourceIds) async {
    final localSources = await localDataSource.getSources();
    final localConnected = await localDataSource.getConnectedSourceIds();
    final normalizedRemoteSourceIds = remoteSourceIds
        .map(_normalizeSourceId)
        .toSet();
    final sourceIds = localSources.map((source) => source.id).toSet();

    for (final sourceId in sourceIds) {
      final shouldBeConnected = normalizedRemoteSourceIds.contains(sourceId);
      final isConnected = localConnected.contains(sourceId);
      if (shouldBeConnected != isConnected) {
        await localDataSource.setSourceConnection(sourceId, shouldBeConnected);
      }
    }
  }

  List<HealthMetricSampleModel> _mergeSamples({
    required List<HealthMetricSample> existing,
    required List<HealthMetricSample> incoming,
  }) {
    final byId = <String, HealthMetricSampleModel>{};

    void addSample(HealthMetricSample sample) {
      final model = _toModel(sample);
      final dedupeKey = model.id.isNotEmpty
          ? model.id
          : '${model.type.key}_${model.startAt.toIso8601String()}_${model.endAt.toIso8601String()}_${model.sourceId}';
      byId[dedupeKey] = model;
    }

    for (final sample in existing) {
      addSample(sample);
    }
    for (final sample in incoming) {
      addSample(sample);
    }

    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return merged;
  }

  HealthMetricSampleModel _toModel(HealthMetricSample sample) {
    if (sample is HealthMetricSampleModel) {
      return HealthMetricSampleModel(
        id: sample.id,
        type: sample.type,
        value: sample.value,
        unit: sample.unit,
        timestamp: sample.timestamp,
        intervalStart: sample.intervalStart,
        intervalEnd: sample.intervalEnd,
        sourceId: _normalizeSourceId(sample.sourceId),
      );
    }
    return HealthMetricSampleModel(
      id: sample.id,
      type: sample.type,
      value: sample.value,
      unit: sample.unit,
      timestamp: sample.timestamp,
      intervalStart: sample.intervalStart,
      intervalEnd: sample.intervalEnd,
      sourceId: _normalizeSourceId(sample.sourceId),
    );
  }

  bool _sampleMatchesRange(HealthMetricSample sample, HealthDateRange range) {
    final start = sample.startAt;
    final end = sample.endAt;
    return !end.isBefore(range.start) && !start.isAfter(range.end);
  }

  String _normalizeSourceId(String sourceId) {
    final value = sourceId.trim().toLowerCase();
    if (value.isEmpty) {
      return sourceId;
    }

    if (value == _appleSourceId ||
        value.contains('apple') ||
        value.contains('healthkit')) {
      return _appleSourceId;
    }
    if (value == _googleSourceId ||
        value.contains('google') ||
        value.contains('healthconnect')) {
      return _googleSourceId;
    }
    if (value == 'local_manual') {
      return value;
    }

    return value;
  }

  Future<HealthDataSource> _getSourceById(String sourceId) async {
    final sources = await localDataSource.getSources();
    return sources.firstWhere(
      (source) => source.id == sourceId,
      orElse: () => throw ArgumentError('Source not found'),
    );
  }

  bool _isSourceAvailable(HealthDataSourceType type) {
    switch (type) {
      case HealthDataSourceType.local:
        return true;
      case HealthDataSourceType.appleHealth:
        return healthKitDataSource.isAvailable;
      case HealthDataSourceType.googleFit:
        return googleFitDataSource.isAvailable;
      case HealthDataSourceType.unknown:
        return false;
    }
  }

  Future<void> _connectByType(HealthDataSourceType type) async {
    switch (type) {
      case HealthDataSourceType.local:
        return;
      case HealthDataSourceType.appleHealth:
        await healthKitDataSource.connect();
        return;
      case HealthDataSourceType.googleFit:
        await googleFitDataSource.connect();
        return;
      case HealthDataSourceType.unknown:
        throw StateError('Unknown source type');
    }
  }

  Future<void> _disconnectByType(HealthDataSourceType type) async {
    switch (type) {
      case HealthDataSourceType.local:
        return;
      case HealthDataSourceType.appleHealth:
        await healthKitDataSource.disconnect();
        return;
      case HealthDataSourceType.googleFit:
        await googleFitDataSource.disconnect();
        return;
      case HealthDataSourceType.unknown:
        throw StateError('Unknown source type');
    }
  }

  Future<void> _prefetchConnectedSourceSamples(HealthDataSource source) async {
    if (source.type == HealthDataSourceType.local ||
        source.type == HealthDataSourceType.unknown) {
      return;
    }

    final now = _now();
    final range = HealthDateRange(start: _externalImportStart(now), end: now);

    List<HealthMetricSampleModel> fetched;
    switch (source.type) {
      case HealthDataSourceType.appleHealth:
        fetched = await healthKitDataSource.getSamples(
          range: range,
          types: const [],
        );
        break;
      case HealthDataSourceType.googleFit:
        fetched = await googleFitDataSource.getSamples(
          range: range,
          types: const [],
        );
        break;
      case HealthDataSourceType.local:
      case HealthDataSourceType.unknown:
        return;
    }

    if (fetched.isEmpty) {
      return;
    }

    final cached = await localDataSource.getCachedExternalSamples();
    final merged = _pruneExternalSamples(
      _mergeSamples(existing: cached, incoming: fetched),
    );
    await localDataSource.saveCachedExternalSamples(merged);
  }

  Future<List<HealthMetricSampleModel>> _fetchIncrementalSourceSamples({
    required HealthDataSource source,
    required List<HealthMetricSampleModel> cached,
    required DateTime now,
  }) async {
    final sourceId = _normalizeSourceId(source.id);
    final latestSourceSample = _latestSampleForSource(cached, sourceId);
    final range = HealthDateRange(
      start: latestSourceSample == null
          ? _externalImportStart(now)
          : _incrementalImportStart(latestSourceSample.endAt, now),
      end: now,
    );

    switch (source.type) {
      case HealthDataSourceType.appleHealth:
        return healthKitDataSource.getSamples(range: range, types: const []);
      case HealthDataSourceType.googleFit:
        return googleFitDataSource.getSamples(range: range, types: const []);
      case HealthDataSourceType.local:
      case HealthDataSourceType.unknown:
        return const [];
    }
  }

  HealthDateRange _capExternalRange(HealthDateRange range) {
    final now = _now();
    final cutoff = _externalImportStart(now);
    final start = range.start.isBefore(cutoff) ? cutoff : range.start;
    final end = range.end.isAfter(now) ? now : range.end;
    return HealthDateRange(start: start, end: end);
  }

  DateTime _externalImportStart(DateTime end) {
    return end.subtract(_externalImportWindow);
  }

  DateTime _incrementalImportStart(DateTime latestEnd, DateTime now) {
    final cutoff = _externalImportStart(now);
    final lookbackStart = latestEnd.subtract(_incrementalSyncLookback);
    return lookbackStart.isBefore(cutoff) ? cutoff : lookbackStart;
  }

  List<HealthMetricSampleModel> _pruneExternalSamples(
    List<HealthMetricSampleModel> samples,
  ) {
    final now = _now();
    final cutoff = _externalImportStart(now);
    return samples
        .where((sample) => !sample.endAt.isBefore(cutoff))
        .where((sample) => !sample.startAt.isAfter(now))
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  HealthMetricSampleModel? _latestSampleForSource(
    List<HealthMetricSampleModel> samples,
    String sourceId,
  ) {
    HealthMetricSampleModel? latest;
    for (final sample in samples) {
      if (_normalizeSourceId(sample.sourceId) != sourceId) {
        continue;
      }
      if (latest == null || sample.endAt.isAfter(latest.endAt)) {
        latest = sample;
      }
    }
    return latest;
  }

  bool _sameSamples(
    List<HealthMetricSampleModel> previous,
    List<HealthMetricSampleModel> next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (var i = 0; i < previous.length; i++) {
      if (previous[i] != next[i]) {
        return false;
      }
    }
    return true;
  }

  DateTime _now() => _nowProvider().toUtc();

  List<HealthMetricType> _supportedMetricsForSource(HealthDataSource source) {
    switch (source.type) {
      case HealthDataSourceType.local:
        return source.supportedMetrics;
      case HealthDataSourceType.appleHealth:
        return HealthPlatformMapper.supportedMetricsForIOS;
      case HealthDataSourceType.googleFit:
        return HealthPlatformMapper.supportedMetricsForAndroid;
      case HealthDataSourceType.unknown:
        return const [];
    }
  }
}
