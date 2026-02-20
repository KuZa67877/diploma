import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_data_source.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource localDataSource;

  const OnboardingRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<OnboardingSlide>>> getSlides() async {
    try {
      final models = await localDataSource.getSlides();
      return Right(List<OnboardingSlide>.from(models));
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
