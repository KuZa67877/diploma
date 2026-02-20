import 'package:get_it/get_it.dart';
import '../data/datasources/permissions_local_data_source.dart';
import '../data/repositories/permissions_repository_impl.dart';
import '../domain/repositories/permissions_repository.dart';
import '../domain/usecases/get_permissions_config.dart';
import '../domain/usecases/save_permissions_selection.dart';
import '../presentation/bloc/permissions_cubit.dart';

void registerPermissions(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<PermissionsLocalDataSource>(
    () => PermissionsLocalDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<PermissionsRepository>(
    () => PermissionsRepositoryImpl(
      localDataSource: getIt<PermissionsLocalDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetPermissionsConfig>(
    () => GetPermissionsConfig(getIt<PermissionsRepository>()),
  );
  getIt.registerLazySingleton<SavePermissionsSelection>(
    () => SavePermissionsSelection(getIt<PermissionsRepository>()),
  );

  // Cubit
  getIt.registerFactory<PermissionsCubit>(
    () => PermissionsCubit(
      getConfig: getIt<GetPermissionsConfig>(),
      saveSelection: getIt<SavePermissionsSelection>(),
    ),
  );
}
