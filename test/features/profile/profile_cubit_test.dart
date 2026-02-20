import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/profile/domain/entities/connected_service.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_data.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_user.dart';
import 'package:medi_ai/features/profile/domain/repositories/profile_repository.dart';
import 'package:medi_ai/features/profile/domain/usecases/get_profile_data.dart';
import 'package:medi_ai/features/profile/presentation/bloc/profile_cubit.dart';

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
  group('ProfileCubit', () {
    test('loads data and emits loaded state', () async {
      final cubit = ProfileCubit(
        getProfileData: GetProfileData(_FakeSuccessRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(loaded: (data) => data.services.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = ProfileCubit(
        getProfileData: GetProfileData(_FakeFailureRepository()),
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
