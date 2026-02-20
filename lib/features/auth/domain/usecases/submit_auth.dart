import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_credentials.dart';
import '../entities/auth_result.dart';
import '../repositories/auth_repository.dart';

class SubmitAuth implements UseCase<AuthResult, AuthParams> {
  final AuthRepository repository;

  const SubmitAuth(this.repository);

  @override
  Future<Either<Failure, AuthResult>> call(AuthParams params) {
    return repository.submit(params.credentials);
  }
}

class AuthParams extends Equatable {
  final AuthCredentials credentials;

  const AuthParams({required this.credentials});

  @override
  List<Object> get props => [credentials];
}
