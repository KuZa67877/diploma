import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileLocalDataSource localDataSource;

  const ProfileRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    try {
      final data = await localDataSource.getProfileData();
      return Right(data);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }
}
