import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_credentials.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_result.dart';
import 'package:medi_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:medi_ai/features/auth/domain/usecases/sign_in_with_apple.dart';
import 'package:medi_ai/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:medi_ai/features/auth/domain/usecases/submit_auth.dart';
import 'package:medi_ai/features/auth/presentation/bloc/auth_cubit.dart';

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
    return const Left(ValidationFailure('Некорректный email'));
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithGoogle() async {
    return const Left(AuthFailure('Supabase не настроен'));
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithApple() async {
    return const Left(AuthFailure('Supabase не настроен'));
  }
}

void main() {
  group('AuthCubit', () {
    test('emits loading then success on submit', () async {
      final cubit = AuthCubit(
        submitAuth: SubmitAuth(_FakeSuccessRepository()),
        signInWithGoogle: SignInWithGoogle(_FakeSuccessRepository()),
        signInWithApple: SignInWithApple(_FakeSuccessRepository()),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          predicate<AuthState>(
            (state) => state.maybeWhen(loading: (_, __) => true, orElse: () => false),
          ),
          predicate<AuthState>(
            (state) => state.maybeWhen(success: (_, __) => true, orElse: () => false),
          ),
        ]),
      );

      await cubit.submit(email: 'test@example.com', password: 'password');
      await cubit.close();
    });

    test('emits loading then error on failure', () async {
      final cubit = AuthCubit(
        submitAuth: SubmitAuth(_FakeFailureRepository()),
        signInWithGoogle: SignInWithGoogle(_FakeFailureRepository()),
        signInWithApple: SignInWithApple(_FakeFailureRepository()),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          predicate<AuthState>(
            (state) => state.maybeWhen(loading: (_, __) => true, orElse: () => false),
          ),
          predicate<AuthState>(
            (state) => state.maybeWhen(
              error: (_, __, message) => message == 'Некорректный email',
              orElse: () => false,
            ),
          ),
        ]),
      );

      await cubit.submit(email: 'bad', password: '123');
      await cubit.close();
    });
  });
}
