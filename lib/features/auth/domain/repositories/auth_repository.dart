import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/auth_credentials.dart';
import '../entities/auth_result.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthResult>> submit(AuthCredentials credentials);
  Future<Either<Failure, AuthResult>> signInWithGoogle();
  Future<Either<Failure, AuthResult>> signInWithApple();
}
