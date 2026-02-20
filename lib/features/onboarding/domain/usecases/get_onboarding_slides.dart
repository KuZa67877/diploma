import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/onboarding_slide.dart';
import '../repositories/onboarding_repository.dart';

class GetOnboardingSlides implements UseCase<List<OnboardingSlide>, NoParams> {
  final OnboardingRepository repository;

  const GetOnboardingSlides(this.repository);

  @override
  Future<Either<Failure, List<OnboardingSlide>>> call(NoParams params) {
    return repository.getSlides();
  }
}
