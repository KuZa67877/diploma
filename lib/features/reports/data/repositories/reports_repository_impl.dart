import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/reports_data.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_local_data_source.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsLocalDataSource localDataSource;

  const ReportsRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, ReportsData>> getReportsData(String filterId) async {
    try {
      final data = await localDataSource.getReportsData(filterId);
      return Right(data);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
