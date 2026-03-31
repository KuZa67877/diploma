import 'package:dartz/dartz.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/repositories/wellbeing_repository.dart';
import '../datasources/wellbeing_local_data_source.dart';
import '../datasources/wellbeing_remote_data_source.dart';

class WellbeingRepositoryImpl implements WellbeingRepository {
  final WellbeingLocalDataSource localDataSource;
  final WellbeingRemoteDataSource remoteDataSource;

  WellbeingRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<WellbeingEntry>>> getEntries() async {
    try {
      final localEntries = await localDataSource.getEntries();
      if (!AppEnv.isSupabaseConfigured) {
        return Right(localEntries);
      }

      try {
        final remoteEntries = await remoteDataSource.getEntries();
        if (remoteEntries.isEmpty) {
          if (localEntries.isNotEmpty) {
            // Remote is the source of truth for authenticated users.
            // Clear stale local cache to avoid leaking entries across accounts.
            await localDataSource.saveEntries(const []);
          }
          return const Right([]);
        }

        if (localEntries.isEmpty) {
          await localDataSource.saveEntries(remoteEntries);
          return Right(remoteEntries);
        }

        final mergedByDate = <String, WellbeingEntry>{
          for (final entry in remoteEntries) _dateKey(entry.date): entry,
          for (final entry in localEntries) _dateKey(entry.date): entry,
        };
        final merged = mergedByDate.values.toList(growable: false)
          ..sort((a, b) => b.date.compareTo(a.date));

        await localDataSource.saveEntries(merged);
        await remoteDataSource.saveEntries(merged);
        return Right(merged);
      } on AuthFailure {
        return Right(localEntries);
      }
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveEntry(WellbeingEntry entry) async {
    try {
      await localDataSource.saveEntry(entry);
      if (!AppEnv.isSupabaseConfigured) {
        return const Right(unit);
      }

      try {
        await remoteDataSource.saveEntry(entry);
      } on AuthFailure {
        return const Right(unit);
      }
      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}

String _dateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final year = normalized.year.toString().padLeft(4, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
