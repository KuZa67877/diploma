import 'package:get_it/get_it.dart';
import '../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../wellbeing/domain/services/healthscore_base_component_service.dart';
import '../../wellbeing/domain/usecases/calculate_healthscore.dart';
import '../data/datasources/profile_local_data_source.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/get_profile_data.dart';
import '../presentation/bloc/profile_cubit.dart';

void registerProfile(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<ProfileLocalDataSource>(
    () => ProfileLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      localDataSource: getIt<ProfileLocalDataSource>(),
      snapshotDataSource: getIt<AnonymousUserSnapshotDataSource>(),
      modelOutputRemoteDataSource: getIt<HealthModelOutputRemoteDataSource>(),
      healthScoreBaseComponentService: getIt<HealthScoreBaseComponentService>(),
      calculateHealthScore: getIt<CalculateHealthScore>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetProfileData>(
    () => GetProfileData(getIt<ProfileRepository>()),
  );

  // Cubit
  getIt.registerFactory<ProfileCubit>(
    () => ProfileCubit(getProfileData: getIt<GetProfileData>()),
  );
}
