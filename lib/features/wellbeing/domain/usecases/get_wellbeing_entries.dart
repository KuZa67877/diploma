import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wellbeing_entry.dart';
import '../repositories/wellbeing_repository.dart';

class GetWellbeingEntries extends UseCase<List<WellbeingEntry>, NoParams> {
  final WellbeingRepository repository;

  GetWellbeingEntries(this.repository);

  @override
  Future<Either<Failure, List<WellbeingEntry>>> call(NoParams params) {
    return repository.getEntries();
  }
}
