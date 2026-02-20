import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_metric_sample.dart';
import '../entities/health_metrics_query.dart';
import '../repositories/health_data_repository.dart';

/// Возвращает метрики здоровья по заданным параметрам.
class GetHealthMetrics
    implements UseCase<List<HealthMetricSample>, HealthMetricsQuery> {
  /// Репозиторий данных здоровья.
  final HealthDataRepository repository;

  /// Создает use case получения метрик.
  const GetHealthMetrics(this.repository);

  @override
  Future<Either<Failure, List<HealthMetricSample>>> call(
    HealthMetricsQuery params,
  ) {
    return repository.getMetrics(params);
  }
}
