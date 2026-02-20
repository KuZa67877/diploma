import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_result.dart';
import '../repositories/auth_repository.dart';

/// Вход через Apple.
class SignInWithApple extends UseCase<AuthResult, NoParams> {
  final AuthRepository repository;

  SignInWithApple(this.repository);

  @override
  Future<Either<Failure, AuthResult>> call(NoParams params) {
    return repository.signInWithApple();
  }
}
