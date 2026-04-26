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
import '../datasources/health_model_output_remote_data_source.dart';
import '../models/dashboard_summary_model.dart';
import '../services/harvard_activity_recommendation_model.dart';
import '../services/physiology_anomaly_inference_model.dart';
import '../services/sleep_quality_inference_model.dart';
import '../services/stress_inference_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardLocalDataSource localDataSource;
  final AnonymousUserSnapshotDataSource snapshotDataSource;
  final HealthDataRemoteDataSource healthRemoteDataSource;
  final HealthModelOutputRemoteDataSource modelOutputRemoteDataSource;
  final HarvardActivityRecommendationModel recommendationModel;
  final SleepQualityInferenceModel sleepQualityModel;
  final StressInferenceModel stressModel;
  final PhysiologyAnomalyInferenceModel physiologyAnomalyModel;
  final _logger = AppLogger.instance;

  DashboardRepositoryImpl({
    required this.localDataSource,
    required this.snapshotDataSource,
    required this.healthRemoteDataSource,
    required this.modelOutputRemoteDataSource,
    required this.recommendationModel,
    required this.sleepQualityModel,
    required this.stressModel,
    required this.physiologyAnomalyModel,
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
      final modelContext = await _resolveModelContext(
        profile: profile,
        fallbackHealthScore: baseScore,
      );
      final normalizedSleepScore = _normalizeSleepScore(
        modelContext.sleep.score,
      );
      final normalizedStressScore = _normalizeStressScore(
        modelContext.stress.stressScore,
      );
      final score = _composeHealthScore(
        baseScore: baseScore,
        sleepScore: normalizedSleepScore,
      );
      final metrics = _mergeMetricsWithModelOutputs(
        baseMetrics: localSummary.metrics,
        sleep: modelContext.sleep,
        normalizedSleepScore: normalizedSleepScore,
        normalizedStressScore: normalizedStressScore,
        physiologyAnomaly: modelContext.physiologyAnomaly,
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
              modelContext.sleep.insufficientData ||
              modelContext.stress.insufficientData ||
              modelContext.physiologyAnomaly.insufficientData,
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
    required int? fallbackHealthScore,
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
      final stressInference = await stressModel.infer(
        samples: snapshot.cachedSamples,
        now: inferenceNow,
        recentSleepScore: sleepInference.score,
        fallbackHealthScore: fallbackHealthScore,
      );
      final physiologyAnomalyInference = physiologyAnomalyModel.inferSync(
        samples: snapshot.cachedSamples,
        now: inferenceNow,
      );
      await _persistModelOutputs(
        sleep: sleepInference,
        stress: stressInference,
        physiologyAnomaly: physiologyAnomalyInference,
        now: inferenceNow ?? DateTime.now().toUtc(),
      );

      return _ResolvedModelContext(
        recommendations: _ResolvedRecommendations(
          keys: recommendationInference.recommendationKeys,
          insufficient:
              recommendationInference.activityClass ==
              HarvardActivityClass.insufficientData,
        ),
        sleep: sleepInference,
        stress: stressInference,
        physiologyAnomaly: physiologyAnomalyInference,
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

  Future<void> _persistModelOutputs({
    required SleepQualityInferenceResult sleep,
    required StressInferenceResult stress,
    required PhysiologyAnomalyInferenceResult physiologyAnomaly,
    required DateTime now,
  }) async {
    if (!AppEnv.isSupabaseConfigured) {
      return;
    }

    try {
      await modelOutputRemoteDataSource.saveOutputs([
        _sleepOutputPayload(sleep, now),
        _stressOutputPayload(stress),
        _physiologyOutputPayload(physiologyAnomaly),
      ]);
    } on AuthFailure {
      // Auth can expire between dashboard load and persistence. Model inference
      // should still be shown from local runtime output.
    } catch (error, stackTrace) {
      _logger.warning(
        'dashboard.repository',
        'Failed to persist model outputs',
        payload: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
    }
  }

  HealthModelOutputPayload _sleepOutputPayload(
    SleepQualityInferenceResult sleep,
    DateTime now,
  ) {
    final latestNight = sleep.latestNight;
    return HealthModelOutputPayload(
      modelId: 'sleep_quality',
      modelVersion: sleep.modelVersion,
      windowStart:
          latestNight?.startUtc.toUtc() ??
          now.subtract(const Duration(days: 1)),
      windowEnd: latestNight?.endUtc.toUtc() ?? now,
      score: sleep.score,
      confidence: sleep.confidence,
      status: sleep.insufficientData ? 'insufficient' : 'ready',
      source: sleep.selectedModel,
      reason: sleep.reason,
      reasonCodes: const [],
      dataQuality: _safeJsonMap({
        'nights_used': sleep.nightsUsed,
        'has_latest_night': latestNight != null,
      }),
      features: _safeJsonMap({
        'sleep_minutes': latestNight?.sleepMinutes,
        'in_bed_minutes': latestNight?.inBedMinutes,
        'sleep_efficiency_pct': latestNight?.sleepEfficiencyPct,
        'hr_mean': latestNight?.hrMean,
        'hr_std': latestNight?.hrStd,
        'rmssd_mean': latestNight?.rmssdMean,
        'sdnn_mean': latestNight?.sdnnMean,
      }),
    );
  }

  HealthModelOutputPayload _stressOutputPayload(StressInferenceResult stress) {
    return HealthModelOutputPayload(
      modelId: 'stress_score_v1',
      modelVersion: stress.modelVersion,
      windowStart: stress.windowStart,
      windowEnd: stress.windowEnd,
      score: stress.stressScore,
      confidence: stress.confidence,
      status: stress.status,
      source: stress.source,
      reason: stress.reason,
      reasonCodes: stress.reasonCodes
          .map(
            (reason) => _safeJsonMap({
              'code': reason.code,
              'severity': reason.severity,
              'impact': reason.contribution,
              'message': reason.message,
            }),
          )
          .toList(growable: false),
      dataQuality: _safeJsonMap({
        'overall': stress.quality.overall,
        'heart_rate': stress.quality.heartRate,
        'baseline': stress.quality.baseline,
        'sleep': stress.quality.sleep,
        'activity_context': stress.quality.activityContext,
        'hrv': stress.quality.hrv,
        'respiratory_temperature_oxygen':
            stress.quality.respiratoryTemperatureOxygen,
      }),
      features: _safeJsonMap(stress.features),
    );
  }

  HealthModelOutputPayload _physiologyOutputPayload(
    PhysiologyAnomalyInferenceResult result,
  ) {
    return HealthModelOutputPayload(
      modelId: result.modelId,
      modelVersion: result.modelVersion,
      windowStart: result.windowStart,
      windowEnd: result.windowEnd,
      score: result.anomalyScore,
      confidence: result.confidence,
      status: result.status,
      source: result.source,
      reason: result.reason,
      reasonCodes: result.reasonCodes
          .map(
            (reason) => _safeJsonMap({
              'code': reason.code,
              'message': reason.message,
              'impact': reason.impact,
            }),
          )
          .toList(growable: false),
      dataQuality: _safeJsonMap(result.dataQuality.toJson()),
      features: _safeJsonMap(result.features),
    );
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
      stress: StressInferenceResult.insufficient(
        now: DateTime.now().toUtc(),
        reason: 'snapshot_unavailable',
      ),
      physiologyAnomaly: PhysiologyAnomalyInferenceResult.insufficient(
        now: DateTime.now().toUtc(),
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

  List<DashboardMetric> _mergeMetricsWithModelOutputs({
    required List<DashboardMetric> baseMetrics,
    required SleepQualityInferenceResult sleep,
    required double? normalizedSleepScore,
    required double? normalizedStressScore,
    required PhysiologyAnomalyInferenceResult physiologyAnomaly,
  }) {
    final sanitized = baseMetrics
        .where((metric) => metric.id != 'sleep_ai')
        .where((metric) => metric.id != 'stress_ai')
        .where((metric) => metric.id != 'physiology_anomaly')
        .toList(growable: true);

    if (normalizedSleepScore != null) {
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
    }

    if (normalizedStressScore != null) {
      sanitized.insert(
        0,
        DashboardMetric(
          id: 'stress_ai',
          labelKey: 'stressAiScore',
          value: normalizedStressScore.toStringAsFixed(0),
          unit: '/100',
          trend: 'stable',
          data: _resolveStressSeries(normalizedStressScore),
        ),
      );
    }

    final anomalyScore = _normalizeAnomalyScore(physiologyAnomaly.anomalyScore);
    if (anomalyScore != null) {
      sanitized.insert(
        0,
        DashboardMetric(
          id: 'physiology_anomaly',
          labelKey: 'physiologyAnomalyScore',
          value: anomalyScore.toStringAsFixed(0),
          unit: '/100',
          trend: 'stable',
          data: _resolveAnomalySeries(anomalyScore),
        ),
      );
    }

    return List.unmodifiable(sanitized);
  }

  List<double> _resolveAnomalySeries(double latestScore) {
    final value = latestScore.clamp(0.0, 100.0);
    return [
      (value - 2.0).clamp(0.0, 100.0),
      (value - 1.5).clamp(0.0, 100.0),
      (value - 1.0).clamp(0.0, 100.0),
      (value - 0.5).clamp(0.0, 100.0),
      value,
    ];
  }

  List<double> _resolveStressSeries(double latestScore) {
    final value = latestScore.clamp(0.0, 100.0);
    return [value, value, value, value, value];
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

  double? _normalizeStressScore(double? value) {
    if (value == null || !value.isFinite) {
      if (value != null && !value.isFinite) {
        _logger.warning(
          'dashboard.repository',
          'Stress score is non-finite, dropping value',
          payload: {'stressScore': value},
        );
      }
      return null;
    }
    final normalized = value.clamp(0.0, 100.0);
    if (normalized != value) {
      _logger.warning(
        'dashboard.repository',
        'Stress score was out of range and clamped',
        payload: {'stressScore': value, 'normalizedStressScore': normalized},
      );
    }
    return normalized;
  }

  double? _normalizeAnomalyScore(double? value) {
    if (value == null || !value.isFinite) {
      if (value != null && !value.isFinite) {
        _logger.warning(
          'dashboard.repository',
          'Physiology anomaly score is non-finite, dropping value',
          payload: {'anomalyScore': value},
        );
      }
      return null;
    }
    final normalized = value.clamp(0.0, 100.0);
    if (normalized != value) {
      _logger.warning(
        'dashboard.repository',
        'Physiology anomaly score was out of range and clamped',
        payload: {'anomalyScore': value, 'normalizedAnomalyScore': normalized},
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

  Map<String, dynamic> _safeJsonMap(Map<String, Object?> input) {
    return input.map((key, value) => MapEntry(key, _safeJsonValue(value)));
  }

  dynamic _safeJsonValue(dynamic value) {
    if (value == null || value is String || value is bool) {
      return value;
    }
    if (value is num) {
      return value.isFinite ? value : null;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is List) {
      return value.map(_safeJsonValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _safeJsonValue(item)),
      );
    }
    return value.toString();
  }
}

class _ResolvedModelContext {
  final _ResolvedRecommendations recommendations;
  final SleepQualityInferenceResult sleep;
  final StressInferenceResult stress;
  final PhysiologyAnomalyInferenceResult physiologyAnomaly;

  const _ResolvedModelContext({
    required this.recommendations,
    required this.sleep,
    required this.stress,
    required this.physiologyAnomaly,
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
