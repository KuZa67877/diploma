import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/wellbeing_entry.dart';

abstract class WellbeingRepository {
  Future<Either<Failure, List<WellbeingEntry>>> getEntries();

  Future<Either<Failure, Unit>> saveEntry(WellbeingEntry entry);
}
