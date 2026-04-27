import 'package:get_it/get_it.dart';
import '../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../core/supabase/supabase_subject_resolver.dart';
import '../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../wellbeing/domain/services/healthscore_base_component_service.dart';
import '../../wellbeing/domain/usecases/calculate_healthscore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/dashboard_local_data_source.dart';
import '../data/datasources/health_model_output_remote_data_source.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/services/baseline_forecast_inference_model.dart';
import '../data/services/harvard_activity_recommendation_model.dart';
import '../data/services/physiology_anomaly_inference_model.dart';
import '../data/services/sleep_quality_inference_model.dart';
import '../data/services/stress_inference_model.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/get_dashboard_summary.dart';
import '../presentation/bloc/dashboard_cubit.dart';

void registerDashboard(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<DashboardLocalDataSource>(
    () => DashboardLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<HealthModelOutputRemoteDataSource>(
    () => HealthModelOutputRemoteDataSourceImpl(
      clientProvider: getIt<SupabaseClient Function()>(),
      subjectResolver: getIt<SupabaseSubjectResolver>(),
    ),
  );
  getIt.registerLazySingleton<HarvardActivityRecommendationModel>(
    () => HarvardActivityRecommendationModel(),
  );
  getIt.registerLazySingleton<SleepQualityInferenceModel>(
    () => SleepQualityInferenceModel(),
  );
  getIt.registerLazySingleton<StressInferenceModel>(
    () => StressInferenceModel(),
  );
  getIt.registerLazySingleton<PhysiologyAnomalyInferenceModel>(
    () => PhysiologyAnomalyInferenceModel(),
  );
  getIt.registerLazySingleton<BaselineForecastInferenceModel>(
    () => BaselineForecastInferenceModel(),
  );

  // Repository
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(
      localDataSource: getIt<DashboardLocalDataSource>(),
      snapshotDataSource: getIt<AnonymousUserSnapshotDataSource>(),
      healthRemoteDataSource: getIt<HealthDataRemoteDataSource>(),
      modelOutputRemoteDataSource: getIt<HealthModelOutputRemoteDataSource>(),
      recommendationModel: getIt<HarvardActivityRecommendationModel>(),
      sleepQualityModel: getIt<SleepQualityInferenceModel>(),
      stressModel: getIt<StressInferenceModel>(),
      physiologyAnomalyModel: getIt<PhysiologyAnomalyInferenceModel>(),
      baselineForecastModel: getIt<BaselineForecastInferenceModel>(),
      healthScoreBaseComponentService: getIt<HealthScoreBaseComponentService>(),
      calculateHealthScore: getIt<CalculateHealthScore>(),
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
