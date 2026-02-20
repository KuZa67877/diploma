import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/health_data_source.dart';
import '../entities/health_metric_sample.dart';
import '../entities/health_metrics_query.dart';

/// Контракт получения данных здоровья из разных источников.
abstract class HealthDataRepository {
  /// Возвращает список доступных источников данных.
  Future<Either<Failure, List<HealthDataSource>>> getAvailableSources();

  /// Подключает источник данных по идентификатору.
  Future<Either<Failure, Unit>> connectSource(String sourceId);

  /// Отключает источник данных по идентификатору.
  Future<Either<Failure, Unit>> disconnectSource(String sourceId);

  /// Возвращает измерения метрик здоровья по запросу.
  Future<Either<Failure, List<HealthMetricSample>>> getMetrics(
    HealthMetricsQuery query,
  );
}
