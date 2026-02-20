import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/splash/domain/entities/splash_data.dart';
import 'package:medi_ai/features/splash/domain/repositories/splash_repository.dart';
import 'package:medi_ai/features/splash/domain/usecases/get_splash_data.dart';
import 'package:medi_ai/core/usecases/usecase.dart';

class _FakeSuccessRepository implements SplashRepository {
  @override
  Future<Either<Failure, SplashData>> getSplashData() async {
    return const Right(
      SplashData(
        appName: 'MediAI',
        tagline: 'AI-powered health diagnostics',
        durationMs: 2500,
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
  group('GetSplashData', () {
    test('returns data on success', () async {
      final useCase = GetSplashData(_FakeSuccessRepository());

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (data) => data.appName), 'MediAI');
    });

    test('returns failure on error', () async {
      final useCase = GetSplashData(_FakeFailureRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
