import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/permissions/domain/entities/health_permission_option.dart';
import 'package:medi_ai/features/permissions/domain/entities/health_source_option.dart';
import 'package:medi_ai/features/permissions/domain/entities/permissions_config.dart';
import 'package:medi_ai/features/permissions/domain/entities/permissions_selection.dart';
import 'package:medi_ai/features/permissions/domain/repositories/permissions_repository.dart';
import 'package:medi_ai/features/permissions/domain/usecases/get_permissions_config.dart';
import 'package:medi_ai/features/permissions/domain/usecases/save_permissions_selection.dart';
import 'package:medi_ai/features/permissions/presentation/bloc/permissions_cubit.dart';

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
  group('PermissionsCubit', () {
    test('loads config and emits loaded state', () async {
      final cubit = PermissionsCubit(
        getConfig: GetPermissionsConfig(_FakeSuccessRepository()),
        saveSelection: SavePermissionsSelection(_FakeSuccessRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(
          loaded: (
            sources,
            permissions,
            selectedSourceId,
            selectedPermissions,
          ) => sources.isNotEmpty && permissions.isNotEmpty && selectedSourceId == null,
          orElse: () => false,
        ),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = PermissionsCubit(
        getConfig: GetPermissionsConfig(_FakeFailureRepository()),
        saveSelection: SavePermissionsSelection(_FakeFailureRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(error: (message) => message.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('toggles permission after load', () async {
      final cubit = PermissionsCubit(
        getConfig: GetPermissionsConfig(_FakeSuccessRepository()),
        saveSelection: SavePermissionsSelection(_FakeSuccessRepository()),
      );

      await cubit.load();
      await cubit.togglePermission('steps');

      final isDisabled = cubit.state.maybeWhen(
        loaded: (_, __, ___, selectedPermissions) =>
            selectedPermissions['steps'] == false,
        orElse: () => false,
      );

      expect(isDisabled, isTrue);

      await cubit.close();
    });
  });
}
