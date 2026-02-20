import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/onboarding_slide.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, List<OnboardingSlide>>> getSlides();
}
