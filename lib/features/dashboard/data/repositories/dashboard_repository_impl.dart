import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/health/health_score_calculator.dart';
import '../../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_data_source.dart';
import '../models/dashboard_summary_model.dart';
import '../services/harvard_activity_recommendation_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDataSource localDataSource;
  final AnonymousUserSnapshotDataSource snapshotDataSource;
  final HealthDataRemoteDataSource healthRemoteDataSource;
  final HarvardActivityRecommendationModel recommendationModel;

  DashboardRepositoryImpl({
    required this.localDataSource,
    required this.snapshotDataSource,
    required this.healthRemoteDataSource,
    required this.recommendationModel,
  });

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    try {
      final localSummary = await localDataSource.getSummary();
      if (!AppEnv.isSupabaseConfigured) {
        return Right(localSummary);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return Right(localSummary);
      }

      final profile =
          await snapshotDataSource.getSnapshot() ??
          OnboardingProfileSnapshot.fromUserMetadata(
            user.userMetadata,
            email: user.email,
          );
      final userName = profile.displayName ?? localSummary.userName;
      final hasHealthProfile = profile.hasAnyCoreHealthValue;
      final score = hasHealthProfile
          ? HealthScoreCalculator.calculate(
              profile,
              fallback: localSummary.healthScore,
            )
          : 0;
      final status = hasHealthProfile
          ? HealthScoreCalculator.statusForScore(score)
          : 'no_access';
      final recommendation = await _resolveRecommendations(profile: profile);

      return Right(
        DashboardSummaryModel(
          greetingKey: localSummary.greetingKey,
          userName: userName,
          healthScore: score,
          status: status,
          recommendationKeys: recommendation.keys,
          hasInsufficientModelData: recommendation.insufficient,
          insight: localSummary.insight,
          metrics: localSummary.metrics,
        ),
      );
    } catch (_) {
      return const Left(CacheFailure());
    }
  }

  Future<_ResolvedRecommendations> _resolveRecommendations({
    required OnboardingProfileSnapshot profile,
  }) async {
    try {
      final snapshot = await healthRemoteDataSource.getSnapshot();
      final inference = await recommendationModel.infer(
        profile: profile,
        samples: snapshot.cachedSamples,
      );
      return _ResolvedRecommendations(
        keys: inference.recommendationKeys,
        insufficient:
            inference.activityClass == HarvardActivityClass.insufficientData,
      );
    } on AuthFailure {
      return _insufficientRecommendations();
    } catch (_) {
      return _insufficientRecommendations();
    }
  }

  _ResolvedRecommendations _insufficientRecommendations() {
    return const _ResolvedRecommendations(
      keys: [
        'modelRecInsufficient1',
        'modelRecInsufficient2',
        'modelRecInsufficient3',
      ],
      insufficient: true,
    );
  }
}

class _ResolvedRecommendations {
  final List<String> keys;
  final bool insufficient;

  const _ResolvedRecommendations({
    required this.keys,
    required this.insufficient,
  });
}
