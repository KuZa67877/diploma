import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_credentials.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_result.dart';
import 'package:medi_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:medi_ai/features/auth/domain/usecases/submit_auth.dart';

class _FakeSuccessRepository implements AuthRepository {
  @override
  Future<Either<Failure, AuthResult>> submit(AuthCredentials credentials) async {
    return const Right(AuthResult(isAuthenticated: true));
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithGoogle() async {
    return const Right(AuthResult(isAuthenticated: true));
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithApple() async {
    return const Right(AuthResult(isAuthenticated: true));
  }
}

class _FakeFailureRepository implements AuthRepository {
  @override
  Future<Either<Failure, AuthResult>> submit(AuthCredentials credentials) async {
    return const Left(AuthFailure());
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithGoogle() async {
    return const Left(AuthFailure());
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithApple() async {
    return const Left(AuthFailure());
  }
}

void main() {
  group('SubmitAuth', () {
    test('returns result on success', () async {
      final useCase = SubmitAuth(_FakeSuccessRepository());

      final result = await useCase(
        AuthParams(
          credentials: const AuthCredentials(
            email: 'test@example.com',
            password: 'password',
            isLogin: true,
          ),
        ),
      );

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (value) => value.isAuthenticated), true);
    });

    test('returns failure on error', () async {
      final useCase = SubmitAuth(_FakeFailureRepository());

      final result = await useCase(
        AuthParams(
          credentials: const AuthCredentials(
            email: 'test@example.com',
            password: 'password',
            isLogin: true,
          ),
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<AuthFailure>());
    });
  });
}
