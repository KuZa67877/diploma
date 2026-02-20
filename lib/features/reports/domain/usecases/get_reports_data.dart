import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/reports_data.dart';
import '../repositories/reports_repository.dart';

class GetReportsData implements UseCase<ReportsData, ReportsParams> {
  final ReportsRepository repository;

  const GetReportsData(this.repository);

  @override
  Future<Either<Failure, ReportsData>> call(ReportsParams params) {
    return repository.getReportsData(params.filterId);
  }
}

class ReportsParams extends Equatable {
  final String filterId;

  const ReportsParams({required this.filterId});

  @override
  List<Object> get props => [filterId];
}
