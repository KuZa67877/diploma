import 'package:dartz/dartz.dart';
import '../../../../core/firebase/firebase_initializer.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/data_input_config.dart';
import '../../domain/entities/data_input_entry.dart';
import '../../domain/repositories/data_input_repository.dart';
import '../datasources/data_input_local_data_source.dart';
import '../datasources/data_input_remote_data_source.dart';

class DataInputRepositoryImpl implements DataInputRepository {
  final DataInputLocalDataSource localDataSource;
  final DataInputRemoteDataSource remoteDataSource;

  DataInputRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
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
      final payload = {
        'recordedAt': entry.recordedAt.toIso8601String(),
        'firstName': entry.firstName,
        'lastName': entry.lastName,
        'height': entry.height,
        'age': entry.age,
        'sex': entry.sex,
        'systolic': entry.systolic,
        'diastolic': entry.diastolic,
        'glucose': entry.glucose,
        'weight': entry.weight,
        'temperature': entry.temperature,
        'symptoms': entry.symptoms,
      };

      await localDataSource.saveEntry(payload);

      if (isFirebaseReady) {
        await remoteDataSource.saveEntry(entry);
      }

      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
