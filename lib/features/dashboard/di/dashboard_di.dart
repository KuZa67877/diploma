import 'package:get_it/get_it.dart';
import '../data/datasources/dashboard_local_data_source.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/get_dashboard_summary.dart';
import '../presentation/bloc/dashboard_cubit.dart';

void registerDashboard(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<DashboardLocalDataSource>(
    () => DashboardLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDataSource: getIt<DashboardLocalDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetDashboardSummary>(
    () => GetDashboardSummary(getIt<DashboardRepository>()),
  );

  // Cubit
  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getDashboardSummary: getIt<GetDashboardSummary>()),
  );
}
