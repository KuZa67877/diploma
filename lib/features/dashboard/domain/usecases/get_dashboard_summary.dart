import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummary implements UseCase<DashboardSummary, NoParams> {
  final DashboardRepository repository;

  const GetDashboardSummary(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call(NoParams params) {
    return repository.getSummary();
  }
}
