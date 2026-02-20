import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_source_connection_params.dart';
import '../repositories/health_data_repository.dart';

/// Отключает источник данных здоровья.
class DisconnectHealthSource
    implements UseCase<Unit, HealthSourceConnectionParams> {
  /// Репозиторий данных здоровья.
  final HealthDataRepository repository;

  /// Создает use case отключения источника.
  const DisconnectHealthSource(this.repository);

  @override
  Future<Either<Failure, Unit>> call(HealthSourceConnectionParams params) {
    return repository.disconnectSource(params.sourceId);
  }
}
