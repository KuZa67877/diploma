import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/health_data_source.dart';
import '../../domain/entities/health_data_source_type.dart';
import '../../domain/entities/health_metric_sample.dart';
import '../../domain/entities/health_metrics_query.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../datasources/google_fit_data_source.dart';
import '../datasources/health_data_local_data_source.dart';
import '../datasources/health_kit_data_source.dart';

/// Реализация репозитория данных здоровья.
class HealthDataRepositoryImpl implements HealthDataRepository {
  /// Локальный источник данных.
  final HealthDataLocalDataSource localDataSource;

  /// Источник данных HealthKit.
  final HealthKitDataSource healthKitDataSource;

  /// Источник данных Google Fit.
  final GoogleFitDataSource googleFitDataSource;

  /// Создает репозиторий данных здоровья.
  const HealthDataRepositoryImpl({
    required this.localDataSource,
    required this.healthKitDataSource,
    required this.googleFitDataSource,
  });

  @override
  Future<Either<Failure, List<HealthDataSource>>> getAvailableSources() async {
    try {
      final sources = await localDataSource.getSources();
      final connectedIds = await localDataSource.getConnectedSourceIds();
      final mapped = sources
          .map(
            (source) => source.copyWith(
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
      final source = await _getSourceById(sourceId);
      final isAvailable = _isSourceAvailable(source.type);
      if (!isAvailable) {
        return Left(PermissionFailure('Источник недоступен в текущем окружении.'));
      }

      await _connectByType(source.type);
      await localDataSource.setSourceConnection(sourceId, true);
      return const Right(unit);
    } catch (error) {
      return Left(ValidationFailure('Не удалось подключить источник.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnectSource(String sourceId) async {
    try {
      final source = await _getSourceById(sourceId);
      await _disconnectByType(source.type);
      await localDataSource.setSourceConnection(sourceId, false);
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
      final sources = await localDataSource.getSources();
      final connectedIds = await localDataSource.getConnectedSourceIds();
      final allowedSourceIds = query.sourceId != null
          ? {query.sourceId!}
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
        final matchesDate = query.range.contains(sample.timestamp);
        return matchesSource && matchesType && matchesDate;
      }).toList();

      final externalSamples = <HealthMetricSample>[];
      if (allowedSources.any(
        (source) => source.type == HealthDataSourceType.appleHealth,
      )) {
        externalSamples.addAll(
          await healthKitDataSource.getSamples(
            range: query.range,
            types: query.types,
          ),
        );
      }
      if (allowedSources.any(
        (source) => source.type == HealthDataSourceType.googleFit,
      )) {
        externalSamples.addAll(
          await googleFitDataSource.getSamples(
            range: query.range,
            types: query.types,
          ),
        );
      }

      return Right([...filteredLocal, ...externalSamples]);
    } catch (error) {
      return Left(CacheFailure('Не удалось получить метрики.'));
    }
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
}
