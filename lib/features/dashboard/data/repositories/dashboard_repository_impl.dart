import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/health/health_score_calculator.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/dashboard_metric.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_data_source.dart';
import '../models/dashboard_summary_model.dart';
import '../services/harvard_activity_recommendation_model.dart';
import '../services/sleep_quality_inference_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDataSource localDataSource;
  final AnonymousUserSnapshotDataSource snapshotDataSource;
  final HealthDataRemoteDataSource healthRemoteDataSource;
  final HarvardActivityRecommendationModel recommendationModel;
  final SleepQualityInferenceModel sleepQualityModel;
  final _logger = AppLogger.instance;

  DashboardRepositoryImpl({
    required this.localDataSource,
    required this.snapshotDataSource,
    required this.healthRemoteDataSource,
    required this.recommendationModel,
    required this.sleepQualityModel,
  });

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    DashboardSummary? localSummary;
    try {
      localSummary = await localDataSource.getSummary();
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
      final baseScore = hasHealthProfile
          ? HealthScoreCalculator.calculate(
              profile,
              fallback: localSummary.healthScore,
            )
          : null;
      final modelContext = await _resolveModelContext(profile: profile);
      final normalizedSleepScore = _normalizeSleepScore(
        modelContext.sleep.score,
      );
      final score = _composeHealthScore(
        baseScore: baseScore,
        sleepScore: normalizedSleepScore,
      );
      final metrics = _mergeMetricsWithSleepModel(
        baseMetrics: localSummary.metrics,
        sleep: modelContext.sleep,
        normalizedSleepScore: normalizedSleepScore,
      );
      final hasAnyScoringData =
          baseScore != null || normalizedSleepScore != null;
      final status = hasAnyScoringData
          ? HealthScoreCalculator.statusForScore(score)
          : 'no_access';

      return Right(
        DashboardSummaryModel(
          greetingKey: localSummary.greetingKey,
          userName: userName,
          healthScore: score,
          status: status,
          recommendationKeys: modelContext.recommendations.keys,
          hasInsufficientModelData:
              modelContext.recommendations.insufficient ||
              modelContext.sleep.insufficientData,
          insight: localSummary.insight,
          metrics: metrics,
        ),
      );
    } catch (error, stackTrace) {
      _logger.error(
        'dashboard.repository',
        'Failed to build dashboard summary',
        payload: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
      if (localSummary != null) {
        return Right(localSummary);
      }
      return const Left(CacheFailure());
    }
  }

  Future<_ResolvedModelContext> _resolveModelContext({
    required OnboardingProfileSnapshot profile,
  }) async {
    try {
      final snapshot = await healthRemoteDataSource.getSnapshot();
      final recommendationInference = await recommendationModel.infer(
        profile: profile,
        samples: snapshot.cachedSamples,
      );
      final inferenceNow = _latestWearableTimestamp(snapshot.cachedSamples);
      final sleepInference = await sleepQualityModel.infer(
        samples: snapshot.cachedSamples,
        now: inferenceNow,
      );

      return _ResolvedModelContext(
        recommendations: _ResolvedRecommendations(
          keys: recommendationInference.recommendationKeys,
          insufficient:
              recommendationInference.activityClass ==
              HarvardActivityClass.insufficientData,
        ),
        sleep: sleepInference,
      );
    } on AuthFailure {
      return _insufficientModelContext();
    } catch (error, stackTrace) {
      _logger.warning(
        'dashboard.repository',
        'Model context fallback to insufficient',
        payload: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
      return _insufficientModelContext();
    }
  }

  int _composeHealthScore({
    required int? baseScore,
    required double? sleepScore,
  }) {
    if (baseScore != null && sleepScore != null) {
      final blended = (baseScore * 0.70) + (sleepScore * 0.30);
      return blended.round().clamp(0, 100);
    }
    if (baseScore != null) {
      return baseScore.clamp(0, 100);
    }
    if (sleepScore != null) {
      return sleepScore.round().clamp(0, 100);
    }
    return 0;
  }

  _ResolvedModelContext _insufficientModelContext() {
    return _ResolvedModelContext(
      recommendations: _insufficientRecommendations(),
      sleep: SleepQualityInferenceResult.insufficient(
        reason: 'snapshot_unavailable',
      ),
    );
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

  List<DashboardMetric> _mergeMetricsWithSleepModel({
    required List<DashboardMetric> baseMetrics,
    required SleepQualityInferenceResult sleep,
    required double? normalizedSleepScore,
  }) {
    final sanitized = baseMetrics
        .where((metric) => metric.id != 'sleep_ai')
        .toList(growable: true);
    if (normalizedSleepScore == null) {
      return List.unmodifiable(sanitized);
    }

    final value = normalizedSleepScore.toStringAsFixed(1);
    final baselineSeries = _resolveSleepBaselineSeries(
      sanitized,
      normalizedSleepScore,
    );
    final trend = _deriveTrend(baselineSeries);
    sanitized.insert(
      0,
      DashboardMetric(
        id: 'sleep_ai',
        labelKey: 'sleepAiScore',
        value: value,
        unit: '/100',
        trend: trend,
        data: baselineSeries,
      ),
    );
    return List.unmodifiable(sanitized);
  }

  List<double> _resolveSleepBaselineSeries(
    List<DashboardMetric> metrics,
    double latestScore,
  ) {
    for (final metric in metrics) {
      if (metric.id == 'sleep' && metric.data.isNotEmpty) {
        final normalized = metric.data
            .map((item) => (item * 12.0).clamp(0.0, 100.0))
            .toList(growable: false);
        final withLatest = normalized.toList(growable: true);
        withLatest[withLatest.length - 1] = latestScore;
        return withLatest;
      }
    }

    final low = (latestScore - 2.0).clamp(0.0, 100.0);
    return [
      low,
      (latestScore - 1.5).clamp(0.0, 100.0),
      (latestScore - 1.0).clamp(0.0, 100.0),
      (latestScore - 0.5).clamp(0.0, 100.0),
      latestScore,
    ];
  }

  String _deriveTrend(List<double> values) {
    if (values.length < 2) return 'stable';
    final delta = values.last - values[values.length - 2];
    if (delta > 0.5) return 'up';
    if (delta < -0.5) return 'down';
    return 'stable';
  }

  double? _normalizeSleepScore(double? value) {
    if (value == null || !value.isFinite) {
      if (value != null && !value.isFinite) {
        _logger.warning(
          'dashboard.repository',
          'Sleep score is non-finite, dropping value',
          payload: {'sleepScore': value},
        );
      }
      return null;
    }
    final normalized = value.clamp(0.0, 100.0);
    if (normalized != value) {
      _logger.warning(
        'dashboard.repository',
        'Sleep score was out of range and clamped',
        payload: {'sleepScore': value, 'normalizedSleepScore': normalized},
      );
    }
    return normalized;
  }

  DateTime? _latestWearableTimestamp(List<HealthMetricSample> samples) {
    final wearable = samples
        .where(
          (sample) => sample.sourceId.trim().toLowerCase() != 'local_manual',
        )
        .toList(growable: false);
    if (wearable.isEmpty) {
      return null;
    }
    DateTime latest = wearable.first.timestamp.toUtc();
    for (final sample in wearable) {
      final ts = sample.timestamp.toUtc();
      if (ts.isAfter(latest)) {
        latest = ts;
      }
    }
    return latest;
  }
}

class _ResolvedModelContext {
  final _ResolvedRecommendations recommendations;
  final SleepQualityInferenceResult sleep;

  const _ResolvedModelContext({
    required this.recommendations,
    required this.sleep,
  });
}

class _ResolvedRecommendations {
  final List<String> keys;
  final bool insufficient;

  const _ResolvedRecommendations({
    required this.keys,
    required this.insufficient,
  });
}
