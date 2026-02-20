import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/splash_data.dart';

abstract class SplashRepository {
  Future<Either<Failure, SplashData>> getSplashData();
}
