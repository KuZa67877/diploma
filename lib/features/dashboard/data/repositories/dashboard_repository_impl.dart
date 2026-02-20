import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDataSource localDataSource;

  const DashboardRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    try {
      final summary = await localDataSource.getSummary();
      return Right(summary);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
