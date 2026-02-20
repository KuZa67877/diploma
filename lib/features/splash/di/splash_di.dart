import 'package:get_it/get_it.dart';
import '../data/datasources/splash_local_data_source.dart';
import '../data/repositories/splash_repository_impl.dart';
import '../domain/repositories/splash_repository.dart';
import '../domain/usecases/get_splash_data.dart';
import '../presentation/bloc/splash_cubit.dart';

void registerSplash(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<SplashLocalDataSource>(
    () => SplashLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<SplashRepository>(
    () => SplashRepositoryImpl(
      localDataSource: getIt<SplashLocalDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetSplashData>(
    () => GetSplashData(getIt<SplashRepository>()),
  );

  // Cubit
  getIt.registerFactory<SplashCubit>(
    () => SplashCubit(getSplashData: getIt<GetSplashData>()),
  );
}
