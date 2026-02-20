import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/core/usecases/usecase.dart';
import 'package:medi_ai/features/onboarding/domain/entities/onboarding_slide.dart';
import 'package:medi_ai/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:medi_ai/features/onboarding/domain/usecases/get_onboarding_slides.dart';

class _FakeSuccessRepository implements OnboardingRepository {
  @override
  Future<Either<Failure, List<OnboardingSlide>>> getSlides() async {
    return const Right([
      OnboardingSlide(
        iconKey: 'brain',
        titleKey: 'aiHealthAnalysis',
        descriptionKey: 'aiHealthAnalysisDesc',
        gradientKeys: ['primary', 'primaryGlow'],
      ),
    ]);
  }
}

class _FakeFailureRepository implements OnboardingRepository {
  @override
  Future<Either<Failure, List<OnboardingSlide>>> getSlides() async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('GetOnboardingSlides', () {
    test('returns slides on success', () async {
      final useCase = GetOnboardingSlides(_FakeSuccessRepository());

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (slides) => slides.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetOnboardingSlides(_FakeFailureRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
