import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wellbeing_entry.dart';
import '../repositories/wellbeing_repository.dart';

class SaveWellbeingEntry extends UseCase<Unit, SaveWellbeingEntryParams> {
  final WellbeingRepository repository;

  SaveWellbeingEntry(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SaveWellbeingEntryParams params) {
    return repository.saveEntry(params.entry);
  }
}

class SaveWellbeingEntryParams {
  final WellbeingEntry entry;

  const SaveWellbeingEntryParams({required this.entry});
}
