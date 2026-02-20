import 'package:get_it/get_it.dart';
import '../data/datasources/auth_local_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/auth_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/sign_in_with_apple.dart';
import '../domain/usecases/sign_in_with_google.dart';
import '../domain/usecases/submit_auth.dart';
import '../presentation/bloc/auth_cubit.dart';

void registerAuth(GetIt getIt) {
  // Data sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      clientProvider: () => Supabase.instance.client,
    ),
  );

  // Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: getIt<AuthLocalDataSource>(),
      remoteDataSource: getIt<AuthRemoteDataSource>(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton<SubmitAuth>(
    () => SubmitAuth(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SignInWithGoogle>(
    () => SignInWithGoogle(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SignInWithApple>(
    () => SignInWithApple(getIt<AuthRepository>()),
  );

  // Cubit
  getIt.registerFactory<AuthCubit>(
    () => AuthCubit(
      submitAuth: getIt<SubmitAuth>(),
      signInWithGoogle: getIt<SignInWithGoogle>(),
      signInWithApple: getIt<SignInWithApple>(),
    ),
  );
}
