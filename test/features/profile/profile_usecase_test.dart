import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/profile/domain/entities/connected_service.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_data.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_user.dart';
import 'package:medi_ai/features/profile/domain/repositories/profile_repository.dart';
import 'package:medi_ai/features/profile/domain/usecases/get_profile_data.dart';
import 'package:medi_ai/core/usecases/usecase.dart';

class _FakeSuccessRepository implements ProfileRepository {
  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    return Right(
      ProfileData(
        user: const ProfileUser(name: 'Alex', email: 'alex@email.com'),
        services: const [
          ConnectedService(
            id: 'apple',
            nameKey: 'appleHealth',
            iconKey: 'heart',
            colorKey: 'danger',
            connected: true,
          ),
        ],
      ),
    );
  }
}

class _FakeFailureRepository implements ProfileRepository {
  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('GetProfileData', () {
    test('returns data on success', () async {
      final useCase = GetProfileData(_FakeSuccessRepository());

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (data) => data.services.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetProfileData(_FakeFailureRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
