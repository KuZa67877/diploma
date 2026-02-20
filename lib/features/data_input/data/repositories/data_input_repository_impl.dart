import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/data_input_config.dart';
import '../../domain/entities/data_input_entry.dart';
import '../../domain/repositories/data_input_repository.dart';
import '../datasources/data_input_local_data_source.dart';

class DataInputRepositoryImpl implements DataInputRepository {
  final DataInputLocalDataSource localDataSource;

  const DataInputRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, DataInputConfig>> getConfig() async {
    try {
      final config = await localDataSource.getConfig();
      return Right(config);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry) async {
    try {
      await localDataSource.saveEntry({
        'recordedAt': entry.recordedAt.toIso8601String(),
        'systolic': entry.systolic,
        'diastolic': entry.diastolic,
        'glucose': entry.glucose,
        'weight': entry.weight,
        'temperature': entry.temperature,
        'symptoms': entry.symptoms,
      });
      return const Right(unit);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
