import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/reports_data.dart';

abstract class ReportsRepository {
  Future<Either<Failure, ReportsData>> getReportsData(String filterId);
}
