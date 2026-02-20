import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/onboarding/domain/entities/onboarding_slide.dart';
import 'package:medi_ai/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:medi_ai/features/onboarding/domain/usecases/get_onboarding_slides.dart';
import 'package:medi_ai/features/onboarding/presentation/bloc/onboarding_cubit.dart';

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
      OnboardingSlide(
        iconKey: 'activity',
        titleKey: 'smartDataSync',
        descriptionKey: 'smartDataSyncDesc',
        gradientKeys: ['secondary', 'success'],
      ),
      OnboardingSlide(
        iconKey: 'shield',
        titleKey: 'secureReports',
        descriptionKey: 'secureReportsDesc',
        gradientKeys: ['aiPurple', 'accent'],
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
  group('OnboardingCubit', () {
    test('emits loading then loaded on success', () async {
      final cubit = OnboardingCubit(
        getOnboardingSlides: GetOnboardingSlides(_FakeSuccessRepository()),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          predicate<OnboardingState>(
            (state) => state.maybeWhen(loading: () => true, orElse: () => false),
          ),
          predicate<OnboardingState>(
            (state) => state.maybeWhen(
              loaded: (slides) => slides.length == 3,
              orElse: () => false,
            ),
          ),
        ]),
      );

      await cubit.loadSlides();
      await cubit.close();
    });

    test('emits loading then error on failure', () async {
      final cubit = OnboardingCubit(
        getOnboardingSlides: GetOnboardingSlides(_FakeFailureRepository()),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          predicate<OnboardingState>(
            (state) => state.maybeWhen(loading: () => true, orElse: () => false),
          ),
          predicate<OnboardingState>(
            (state) => state.maybeWhen(
              error: (message) => message == 'Cache error occurred',
              orElse: () => false,
            ),
          ),
        ]),
      );

      await cubit.loadSlides();
      await cubit.close();
    });
  });
}
