import 'package:get_it/get_it.dart';
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
