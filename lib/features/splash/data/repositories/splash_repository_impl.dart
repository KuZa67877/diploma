import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/splash_data.dart';
import '../../domain/repositories/splash_repository.dart';
import '../datasources/splash_local_data_source.dart';

class SplashRepositoryImpl implements SplashRepository {
  final SplashLocalDataSource localDataSource;

  const SplashRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, SplashData>> getSplashData() async {
    try {
      final data = await localDataSource.getSplashData();
      return Right(data);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
