import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/data_input_config.dart';
import '../repositories/data_input_repository.dart';

class GetDataInputConfig implements UseCase<DataInputConfig, NoParams> {
  final DataInputRepository repository;

  const GetDataInputConfig(this.repository);

  @override
  Future<Either<Failure, DataInputConfig>> call(NoParams params) {
    return repository.getConfig();
  }
}
