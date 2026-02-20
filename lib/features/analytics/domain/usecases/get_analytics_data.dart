import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/analytics_data.dart';
import '../repositories/analytics_repository.dart';

class GetAnalyticsData implements UseCase<AnalyticsData, AnalyticsParams> {
  final AnalyticsRepository repository;

  const GetAnalyticsData(this.repository);

  @override
  Future<Either<Failure, AnalyticsData>> call(AnalyticsParams params) {
    return repository.getAnalyticsData(params.filterId);
  }
}

class AnalyticsParams extends Equatable {
  final String filterId;

  const AnalyticsParams({required this.filterId});

  @override
  List<Object> get props => [filterId];
}
