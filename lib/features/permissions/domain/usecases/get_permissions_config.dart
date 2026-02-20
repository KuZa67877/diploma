import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/permissions_config.dart';
import '../repositories/permissions_repository.dart';

class GetPermissionsConfig implements UseCase<PermissionsConfig, NoParams> {
  final PermissionsRepository repository;

  const GetPermissionsConfig(this.repository);

  @override
  Future<Either<Failure, PermissionsConfig>> call(NoParams params) {
    return repository.getConfig();
  }
}
