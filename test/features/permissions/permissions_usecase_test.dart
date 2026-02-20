import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/core/usecases/usecase.dart';
import 'package:medi_ai/features/permissions/domain/entities/health_permission_option.dart';
import 'package:medi_ai/features/permissions/domain/entities/health_source_option.dart';
import 'package:medi_ai/features/permissions/domain/entities/permissions_config.dart';
import 'package:medi_ai/features/permissions/domain/entities/permissions_selection.dart';
import 'package:medi_ai/features/permissions/domain/repositories/permissions_repository.dart';
import 'package:medi_ai/features/permissions/domain/usecases/get_permissions_config.dart';
import 'package:medi_ai/features/permissions/domain/usecases/save_permissions_selection.dart';

class _FakeSuccessRepository implements PermissionsRepository {
  @override
  Future<Either<Failure, PermissionsConfig>> getConfig() async {
    return Right(
      PermissionsConfig(
        sources: const [
          HealthSourceOption(
            id: 'apple',
            nameKey: 'appleHealth',
            descKey: 'iosDevices',
            iconKey: 'heart',
            gradientKeys: ['appleRed', 'applePink'],
          ),
        ],
        permissions: const [
          HealthPermissionOption(
            id: 'steps',
            labelKey: 'steps',
            descKey: 'stepsDesc',
            iconKey: 'footprints',
          ),
        ],
        defaultSelection: const PermissionsSelection(
          sourceId: null,
          permissions: {'steps': true},
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, PermissionsSelection>> saveSelection(
    PermissionsSelection selection,
  ) async {
    return Right(selection);
  }
}

class _FakeFailureRepository implements PermissionsRepository {
  @override
  Future<Either<Failure, PermissionsConfig>> getConfig() async {
    return const Left(CacheFailure());
  }

  @override
  Future<Either<Failure, PermissionsSelection>> saveSelection(
    PermissionsSelection selection,
  ) async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('GetPermissionsConfig', () {
    test('returns config on success', () async {
      final useCase = GetPermissionsConfig(_FakeSuccessRepository());

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (value) => value.sources.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetPermissionsConfig(_FakeFailureRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });

  group('SavePermissionsSelection', () {
    test('returns selection on success', () async {
      final useCase = SavePermissionsSelection(_FakeSuccessRepository());
      final selection = const PermissionsSelection(
        sourceId: 'apple',
        permissions: {'steps': true},
      );

      final result = await useCase(
        SavePermissionsParams(selection: selection),
      );

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (value) => value.sourceId), 'apple');
    });

    test('returns failure on error', () async {
      final useCase = SavePermissionsSelection(_FakeFailureRepository());

      final result = await useCase(
        SavePermissionsParams(
          selection: const PermissionsSelection(
            sourceId: 'apple',
            permissions: {'steps': true},
          ),
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
