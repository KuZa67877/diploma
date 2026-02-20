import 'package:get_it/get_it.dart';
import '../data/datasources/onboarding_local_data_source.dart';
import '../data/repositories/onboarding_repository_impl.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../domain/usecases/get_onboarding_slides.dart';
import '../presentation/bloc/onboarding_cubit.dart';

void registerOnboarding(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      localDataSource: getIt<OnboardingLocalDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetOnboardingSlides>(
    () => GetOnboardingSlides(getIt<OnboardingRepository>()),
  );

  // Cubit
  getIt.registerFactory<OnboardingCubit>(
    () => OnboardingCubit(
      getOnboardingSlides: getIt<GetOnboardingSlides>(),
    ),
  );
}
