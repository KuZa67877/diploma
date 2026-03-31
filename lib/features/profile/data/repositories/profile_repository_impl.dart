import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/health/health_score_calculator.dart';
import '../../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_data_model.dart';
import '../models/profile_user_model.dart';
import '../datasources/profile_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileLocalDataSource localDataSource;
  final AnonymousUserSnapshotDataSource snapshotDataSource;

  ProfileRepositoryImpl({
    required this.localDataSource,
    required this.snapshotDataSource,
  });

  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    try {
      final localData = await localDataSource.getProfileData();
      if (!AppEnv.isSupabaseConfigured) {
        return Right(localData);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return Right(localData);
      }

      final profile =
          await snapshotDataSource.getSnapshot() ??
          OnboardingProfileSnapshot.fromUserMetadata(
            user.userMetadata,
            email: user.email,
          );
      final healthScore = profile.hasAnyCoreHealthValue
          ? HealthScoreCalculator.calculate(profile)
          : null;
      final connectedSources = profile.connectedHealthSourceIds.toSet();
      final services = localData.services
          .map((service) {
            final isConnected = _mapConnected(
              serviceId: service.id,
              current: service.connected,
              connectedSourceIds: connectedSources,
            );
            return service.copyWith(connected: isConnected);
          })
          .toList(growable: false);

      final merged = ProfileDataModel(
        user: ProfileUserModel(
          name: profile.displayName ?? localData.user.name,
          email: profile.email ?? localData.user.email,
          age: profile.age,
          sex: profile.sex,
          heightCm: profile.heightCm,
          weightKg: profile.weightKg,
          healthScore: healthScore,
          recordsCount: profile.recordsCount,
          streakDays: profile.streakDays,
          wellbeingEntriesCount: profile.wellbeingEntriesCount,
          healthSamplesCount: profile.healthSamplesCount,
          connectedHealthSourceIds: profile.connectedHealthSourceIds,
        ),
        services: services,
      );
      return Right(merged);
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  bool _mapConnected({
    required String serviceId,
    required bool current,
    required Set<String> connectedSourceIds,
  }) {
    switch (serviceId) {
      case 'apple':
        return connectedSourceIds.contains('apple_health');
      case 'google':
        return connectedSourceIds.contains('google_fit');
      default:
        return current;
    }
  }
}
