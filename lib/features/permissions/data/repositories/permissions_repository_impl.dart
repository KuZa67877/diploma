import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/permissions_config.dart';
import '../../domain/entities/permissions_selection.dart';
import '../../domain/repositories/permissions_repository.dart';
import '../datasources/permissions_local_data_source.dart';
import '../models/permissions_selection_model.dart';

class PermissionsRepositoryImpl implements PermissionsRepository {
  final PermissionsLocalDataSource localDataSource;

  const PermissionsRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, PermissionsConfig>> getConfig() async {
    try {
      final config = await localDataSource.getConfig();
      return Right(config);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, PermissionsSelection>> saveSelection(
    PermissionsSelection selection,
  ) async {
    try {
      final model = PermissionsSelectionModel(
        sourceId: selection.sourceId,
        permissions: selection.permissions,
      );
      final saved = await localDataSource.saveSelection(model);
      return Right(saved);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
