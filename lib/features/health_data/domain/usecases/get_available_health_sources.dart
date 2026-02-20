import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_data_source.dart';
import '../repositories/health_data_repository.dart';

/// Возвращает список доступных источников данных здоровья.
class GetAvailableHealthSources
    implements UseCase<List<HealthDataSource>, NoParams> {
  /// Репозиторий данных здоровья.
  final HealthDataRepository repository;

  /// Создает use case для получения источников.
  const GetAvailableHealthSources(this.repository);

  @override
  Future<Either<Failure, List<HealthDataSource>>> call(NoParams params) {
    return repository.getAvailableSources();
  }
}
