import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/permissions_selection.dart';
import '../repositories/permissions_repository.dart';

class SavePermissionsSelection
    implements UseCase<PermissionsSelection, SavePermissionsParams> {
  final PermissionsRepository repository;

  const SavePermissionsSelection(this.repository);

  @override
  Future<Either<Failure, PermissionsSelection>> call(
    SavePermissionsParams params,
  ) {
    return repository.saveSelection(params.selection);
  }
}

class SavePermissionsParams extends Equatable {
  final PermissionsSelection selection;

  const SavePermissionsParams({required this.selection});

  @override
  List<Object> get props => [selection];
}
