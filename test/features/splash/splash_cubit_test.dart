import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/splash/domain/entities/splash_data.dart';
import 'package:medi_ai/features/splash/domain/repositories/splash_repository.dart';
import 'package:medi_ai/features/splash/domain/usecases/get_splash_data.dart';
import 'package:medi_ai/features/splash/presentation/bloc/splash_cubit.dart';

class _FakeSuccessRepository implements SplashRepository {
  @override
  Future<Either<Failure, SplashData>> getSplashData() async {
    return const Right(
      SplashData(
        appName: 'MediAI',
        tagline: 'AI-powered health diagnostics',
        durationMs: 10,
      ),
    );
  }
}

class _FakeFailureRepository implements SplashRepository {
  @override
  Future<Either<Failure, SplashData>> getSplashData() async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('SplashCubit', () {
    test('emits ready then completed', () async {
      final cubit = SplashCubit(
        getSplashData: GetSplashData(_FakeSuccessRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(ready: (_) => true, orElse: () => false),
        isTrue,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        cubit.state.maybeWhen(completed: () => true, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = SplashCubit(
        getSplashData: GetSplashData(_FakeFailureRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(error: (message) => message.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });
  });
}
