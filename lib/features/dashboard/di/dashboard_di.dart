import 'package:get_it/get_it.dart';
import '../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../data/datasources/dashboard_local_data_source.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/services/harvard_activity_recommendation_model.dart';
import '../data/services/sleep_quality_inference_model.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/get_dashboard_summary.dart';
import '../presentation/bloc/dashboard_cubit.dart';

void registerDashboard(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<DashboardLocalDataSource>(
    () => DashboardLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<HarvardActivityRecommendationModel>(
    () => HarvardActivityRecommendationModel(),
  );
  getIt.registerLazySingleton<SleepQualityInferenceModel>(
    () => SleepQualityInferenceModel(),
  );

  // Repository
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDataSource: getIt<DashboardLocalDataSource>(),
      snapshotDataSource: getIt<AnonymousUserSnapshotDataSource>(),
      healthRemoteDataSource: getIt<HealthDataRemoteDataSource>(),
      recommendationModel: getIt<HarvardActivityRecommendationModel>(),
      sleepQualityModel: getIt<SleepQualityInferenceModel>(),
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
