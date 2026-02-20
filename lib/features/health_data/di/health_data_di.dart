import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/google_fit_data_source.dart';
import '../data/datasources/health_data_local_data_source.dart';
import '../data/datasources/health_kit_data_source.dart';
import '../data/repositories/health_data_repository_impl.dart';
import '../domain/repositories/health_data_repository.dart';
import '../domain/usecases/connect_health_source.dart';
import '../domain/usecases/disconnect_health_source.dart';
import '../domain/usecases/get_available_health_sources.dart';
import '../domain/usecases/get_health_metrics.dart';
import '../presentation/bloc/health_sources_cubit.dart';

/// Регистрирует зависимости для источников данных здоровья.
void registerHealthData(GetIt getIt) {
  getIt.registerLazySingleton<HealthDataLocalDataSource>(
    () => HealthDataLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );
  getIt.registerLazySingleton<HealthKitDataSource>(
    () => HealthKitDataSourceImpl(),
  );
  getIt.registerLazySingleton<GoogleFitDataSource>(
    () => GoogleFitDataSourceImpl(),
  );
  getIt.registerLazySingleton<HealthDataRepository>(
    () => HealthDataRepositoryImpl(
      localDataSource: getIt<HealthDataLocalDataSource>(),
      healthKitDataSource: getIt<HealthKitDataSource>(),
      googleFitDataSource: getIt<GoogleFitDataSource>(),
    ),
  );

  getIt.registerLazySingleton(
    () => GetAvailableHealthSources(getIt<HealthDataRepository>()),
  );
  getIt.registerLazySingleton(
    () => ConnectHealthSource(getIt<HealthDataRepository>()),
  );
  getIt.registerLazySingleton(
    () => DisconnectHealthSource(getIt<HealthDataRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetHealthMetrics(getIt<HealthDataRepository>()),
  );

  getIt.registerFactory<HealthSourcesCubit>(
    () => HealthSourcesCubit(
      getSources: getIt<GetAvailableHealthSources>(),
      connectSource: getIt<ConnectHealthSource>(),
      disconnectSource: getIt<DisconnectHealthSource>(),
    ),
  );
}
