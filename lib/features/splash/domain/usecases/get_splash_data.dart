import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/splash_data.dart';
import '../repositories/splash_repository.dart';

class GetSplashData implements UseCase<SplashData, NoParams> {
  final SplashRepository repository;

  const GetSplashData(this.repository);

  @override
  Future<Either<Failure, SplashData>> call(NoParams params) {
    return repository.getSplashData();
  }
}
