import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_subject_resolver.dart';
import '../data/datasources/data_input_local_data_source.dart';
import '../data/datasources/data_input_remote_data_source.dart';
import '../data/repositories/data_input_repository_impl.dart';
import '../domain/repositories/data_input_repository.dart';
import '../domain/usecases/get_data_input_config.dart';
import '../domain/usecases/submit_data_input.dart';
import '../presentation/bloc/data_input_cubit.dart';

void registerDataInput(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<DataInputLocalDataSource>(
    () => DataInputLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<DataInputRemoteDataSource>(
    () => DataInputRemoteDataSourceImpl(
      clientProvider: getIt<SupabaseClient Function()>(),
      subjectResolver: getIt<SupabaseSubjectResolver>(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<DataInputRepository>(
    () => DataInputRepositoryImpl(
      localDataSource: getIt<DataInputLocalDataSource>(),
      remoteDataSource: getIt<DataInputRemoteDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<GetDataInputConfig>(
    () => GetDataInputConfig(getIt<DataInputRepository>()),
  );
  getIt.registerLazySingleton<SubmitDataInput>(
    () => SubmitDataInput(getIt<DataInputRepository>()),
  );

  // Cubit
  getIt.registerFactory<DataInputCubit>(
    () => DataInputCubit(
      getConfig: getIt<GetDataInputConfig>(),
      submitDataInput: getIt<SubmitDataInput>(),
    ),
  );
}
