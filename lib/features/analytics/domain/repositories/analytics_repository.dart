import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/analytics_data.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(String filterId);
}
