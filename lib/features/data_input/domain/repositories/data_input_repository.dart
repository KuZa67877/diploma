import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/data_input_config.dart';
import '../entities/data_input_entry.dart';

abstract class DataInputRepository {
  Future<Either<Failure, DataInputConfig>> getConfig();
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry);
}
