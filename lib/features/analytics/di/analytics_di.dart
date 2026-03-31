import 'package:get_it/get_it.dart';
import '../../health_data/domain/repositories/health_data_repository.dart';
import '../data/repositories/analytics_repository_impl.dart';
import '../domain/repositories/analytics_repository.dart';
import '../domain/usecases/get_analytics_data.dart';
import '../presentation/bloc/analytics_cubit.dart';

void registerAnalytics(GetIt getIt) {
  // Repository
  getIt.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(
      healthDataRepository: getIt<HealthDataRepository>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetAnalyticsData>(
    () => GetAnalyticsData(getIt<AnalyticsRepository>()),
  );

  // Cubit
  getIt.registerFactory<AnalyticsCubit>(
    () => AnalyticsCubit(getAnalyticsData: getIt<GetAnalyticsData>()),
  );
}
