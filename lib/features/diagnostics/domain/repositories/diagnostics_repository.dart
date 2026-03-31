import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/risk_assessment_request.dart';
import '../entities/risk_assessment_response.dart';

abstract class DiagnosticsRepository {
  Future<Either<Failure, RiskAssessmentResponse>> assessRisk(
    RiskAssessmentRequest request,
  );
}
