import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_credentials.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/config/app_env.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_credentials_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource localDataSource;
  final AuthRemoteDataSource remoteDataSource;

  const AuthRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, AuthResult>> submit(AuthCredentials credentials) async {
    try {
      final model = AuthCredentialsModel(
        email: credentials.email,
        password: credentials.password,
        isLogin: credentials.isLogin,
      );
      final result = AppEnv.isSupabaseConfigured
          ? await remoteDataSource.submit(model)
          : await localDataSource.submit(model);
      return Right(result);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure());
    }
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithGoogle() async {
    if (!AppEnv.isSupabaseConfigured) {
      return const Left(AuthFailure('Supabase не настроен'));
    }

    try {
      final result = await remoteDataSource.signInWithGoogle();
      return Right(result);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure());
    }
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithApple() async {
    if (!AppEnv.isSupabaseConfigured) {
      return const Left(AuthFailure('Supabase не настроен'));
    }

    try {
      final result = await remoteDataSource.signInWithApple();
      return Right(result);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure());
    }
  }
}
