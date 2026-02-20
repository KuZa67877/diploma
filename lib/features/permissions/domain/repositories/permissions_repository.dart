import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/permissions_config.dart';
import '../entities/permissions_selection.dart';

abstract class PermissionsRepository {
  Future<Either<Failure, PermissionsConfig>> getConfig();
  Future<Either<Failure, PermissionsSelection>> saveSelection(
    PermissionsSelection selection,
  );
}
