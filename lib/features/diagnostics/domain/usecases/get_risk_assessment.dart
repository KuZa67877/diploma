import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/risk_assessment_request.dart';
import '../entities/risk_assessment_response.dart';
import '../repositories/diagnostics_repository.dart';

class GetRiskAssessment
    implements UseCase<RiskAssessmentResponse, RiskAssessmentParams> {
  final DiagnosticsRepository repository;

  const GetRiskAssessment(this.repository);

  @override
  Future<Either<Failure, RiskAssessmentResponse>> call(
    RiskAssessmentParams params,
  ) {
    return repository.assessRisk(params.request);
  }
}

class RiskAssessmentParams extends Equatable {
  final RiskAssessmentRequest request;

  const RiskAssessmentParams({required this.request});

  @override
  List<Object> get props => [request];
}
