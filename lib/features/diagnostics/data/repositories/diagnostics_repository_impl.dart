import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/risk_assessment_request.dart';
import '../../domain/entities/risk_assessment_response.dart';
import '../../domain/repositories/diagnostics_repository.dart';
import '../datasources/diagnostics_local_data_source.dart';

class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  final DiagnosticsLocalDataSource localDataSource;

  const DiagnosticsRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, RiskAssessmentResponse>> assessRisk(
    RiskAssessmentRequest request,
  ) async {
    try {
      final response = await localDataSource.assessRisk(request);
      return Right(response);
    } catch (_) {
      return const Left(ServerFailure('Не удалось выполнить оценку риска.'));
    }
  }
}
