import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_source_connection_params.dart';
import '../repositories/health_data_repository.dart';

/// Подключает источник данных здоровья.
class ConnectHealthSource implements UseCase<Unit, HealthSourceConnectionParams> {
  /// Репозиторий данных здоровья.
  final HealthDataRepository repository;

  /// Создает use case подключения источника.
  const ConnectHealthSource(this.repository);

  @override
  Future<Either<Failure, Unit>> call(HealthSourceConnectionParams params) {
    return repository.connectSource(params.sourceId);
  }
}
