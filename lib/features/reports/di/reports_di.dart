import 'package:get_it/get_it.dart';
import '../../health_data/domain/usecases/get_health_metrics.dart';
import '../data/datasources/reports_local_data_source.dart';
import '../data/repositories/reports_repository_impl.dart';
import '../domain/repositories/reports_repository.dart';
import '../domain/usecases/get_reports_data.dart';
import '../presentation/bloc/reports_cubit.dart';

void registerReports(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<ReportsLocalDataSource>(
    () => ReportsLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(
      localDataSource: getIt<ReportsLocalDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetReportsData>(
    () => GetReportsData(getIt<ReportsRepository>()),
  );

  // Cubit
  getIt.registerFactory<ReportsCubit>(
    () => ReportsCubit(
      getReportsData: getIt<GetReportsData>(),
      getHealthMetrics: getIt<GetHealthMetrics>(),
    ),
  );
}
