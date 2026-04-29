import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../wellbeing/domain/entities/health_score_band.dart';
import '../../../wellbeing/domain/entities/health_score_input.dart';
import '../../../wellbeing/domain/entities/health_score_result.dart';
import '../../../wellbeing/domain/services/healthscore_base_component_service.dart';
import '../../../wellbeing/domain/usecases/calculate_healthscore.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/dashboard_metric.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_data_source.dart';
import '../datasources/health_model_output_remote_data_source.dart';
import '../models/dashboard_summary_model.dart';
import '../services/baseline_forecast_inference_model.dart';
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
  final BaselineForecastInferenceModel baselineForecastModel;
  final HealthScoreBaseComponentService healthScoreBaseComponentService;
  final CalculateHealthScore calculateHealthScore;
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
    required this.baselineForecastModel,
    required this.healthScoreBaseComponentService,
    required this.calculateHealthScore,
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
      final baseScore = healthScoreBaseComponentService.estimateScore(
        systolic: profile.systolic,
        diastolic: profile.diastolic,
        glucose: profile.glucose,
        temperatureC: profile.temperatureC,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
      );
      final baseConfidence = healthScoreBaseComponentService.estimateConfidence(
        systolic: profile.systolic,
        diastolic: profile.diastolic,
        glucose: profile.glucose,
        temperatureC: profile.temperatureC,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
      );
      final modelContext = await _resolveModelContext(
        profile: profile,
        fallbackHealthScore: baseScore?.round(),
      );
      final normalizedSleepScore = _normalizeSleepScore(
        modelContext.sleep.score,
      );
      final normalizedStressScore = _normalizeStressScore(
        modelContext.stress.stressScore,
      );
      final normalizedAnomalyScore = _normalizeAnomalyScore(
        modelContext.physiologyAnomaly.anomalyScore,
      );
      final normalizedBaselineDeviationScore = _normalizeBaselineDeviationScore(
        modelContext.baselineForecast.overallDeviationScore,
      );
      final healthScoreInput = HealthScoreInput(
        baseScore: baseScore,
        sleepScore: normalizedSleepScore,
        stressScore: normalizedStressScore,
        anomalyScore: normalizedAnomalyScore,
        baselineDeviationScore: normalizedBaselineDeviationScore,
        baseConfidence: baseScore == null ? null : baseConfidence,
        sleepConfidence: modelContext.sleep.confidence,
        stressConfidence: modelContext.stress.confidence,
        anomalyConfidence: modelContext.physiologyAnomaly.confidence,
        baselineDeviationConfidence: modelContext.baselineForecast.confidence,
        computedAt: _resolveHealthScoreComputedAt(
          modelContext: modelContext,
          fallback: DateTime.now().toUtc(),
        ),
      );
      final healthScoreResult = calculateHealthScore(healthScoreInput);
      final metrics = _buildTodayMetrics(
        samples: modelContext.wearableSamples,
        sleep: modelContext.sleep,
        stress: modelContext.stress,
        recovery: modelContext.physiologyAnomaly,
      );
      final modelResults = _buildModelResults(
        activity: modelContext.activity,
        sleep: modelContext.sleep,
        stress: modelContext.stress,
        baseline: modelContext.baselineForecast,
        recovery: modelContext.physiologyAnomaly,
        healthScoreResult: healthScoreResult,
      );
      await _persistHealthScoreOutput(
        input: healthScoreInput,
        result: healthScoreResult,
      );
      final status = _legacyStatusFromBand(healthScoreResult.band);
      final healthScore = healthScoreResult.score ?? 0;
      final hasHealthScoreQualityAlerts = healthScoreResult.alerts.any(
        (alert) =>
            alert.code == 'low_data_completeness' ||
            alert.code == 'low_confidence',
      );

      return Right(
        DashboardSummaryModel(
          greetingKey: localSummary.greetingKey,
          userName: userName,
          healthScore: healthScore,
          status: status,
          recommendationKeys: modelContext.recommendations.keys,
          hasInsufficientModelData:
              modelContext.recommendations.insufficient ||
              !modelContext.hasAnyWearableData ||
              modelContext.sleep.insufficientData ||
              modelContext.stress.insufficientData ||
              modelContext.physiologyAnomaly.insufficientData ||
              modelContext.baselineForecast.insufficientData ||
              hasHealthScoreQualityAlerts,
          insight: localSummary.insight,
          metrics: metrics,
          dataSnapshot: DashboardDataSnapshot(
            connectedSources: modelContext.connectedSourceCount,
            wearableSampleCount: modelContext.wearableSamples.length,
            latestWearableSampleAt: modelContext.latestWearableSampleAt,
          ),
          modelResults: modelResults,
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
      final wearableSamples = snapshot.cachedSamples
          .where(
            (sample) => sample.sourceId.trim().toLowerCase() != 'local_manual',
          )
          .toList(growable: false);
      final recommendationInference = await recommendationModel.infer(
        profile: profile,
        samples: wearableSamples,
      );
      final inferenceNow = _latestWearableTimestamp(wearableSamples);
      final sleepInference = await sleepQualityModel.infer(
        samples: wearableSamples,
        now: inferenceNow,
      );
      final stressInference = await stressModel.infer(
        samples: wearableSamples,
        now: inferenceNow,
        recentSleepScore: sleepInference.score,
        fallbackHealthScore: fallbackHealthScore,
      );
      final physiologyAnomalyInference = physiologyAnomalyModel.inferSync(
        samples: wearableSamples,
        now: inferenceNow,
      );
      final baselineForecastInference = baselineForecastModel.inferSync(
        samples: wearableSamples,
        now: inferenceNow,
      );
      await _persistModelOutputs(
        activity: recommendationInference,
        sleep: sleepInference,
        stress: stressInference,
        physiologyAnomaly: physiologyAnomalyInference,
        baselineForecast: baselineForecastInference,
        now: inferenceNow ?? DateTime.now().toUtc(),
      );

      return _ResolvedModelContext(
        recommendations: _ResolvedRecommendations(
          keys: recommendationInference.recommendationKeys,
          insufficient:
              recommendationInference.activityClass ==
              HarvardActivityClass.insufficientData,
        ),
        activity: recommendationInference,
        sleep: sleepInference,
        stress: stressInference,
        physiologyAnomaly: physiologyAnomalyInference,
        baselineForecast: baselineForecastInference,
        connectedSourceCount: snapshot.connectedSourceIds.length,
        wearableSamples: wearableSamples,
        latestWearableSampleAt: inferenceNow,
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
    required HarvardActivityRecommendationResult activity,
    required SleepQualityInferenceResult sleep,
    required StressInferenceResult stress,
    required PhysiologyAnomalyInferenceResult physiologyAnomaly,
    required BaselineForecastInferenceResult baselineForecast,
    required DateTime now,
  }) async {
    if (!AppEnv.isSupabaseConfigured) {
      return;
    }

    try {
      await modelOutputRemoteDataSource.saveOutputs([
        _activityOutputPayload(activity, now),
        _sleepOutputPayload(sleep, now),
        _stressOutputPayload(stress),
        _physiologyOutputPayload(physiologyAnomaly),
        _baselineForecastOutputPayload(baselineForecast),
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

  HealthModelOutputPayload _activityOutputPayload(
    HarvardActivityRecommendationResult activity,
    DateTime now,
  ) {
    return HealthModelOutputPayload(
      modelId: 'harvard_activity_recommendation_v1',
      modelVersion: activity.modelVersion,
      windowStart: now.subtract(const Duration(days: 30)),
      windowEnd: now,
      score: activity.activityClass == HarvardActivityClass.insufficientData
          ? null
          : activity.confidence * 100.0,
      confidence: activity.confidence,
      status: _activityClassCode(activity.activityClass),
      source: 'harvard_aw_model',
      reason: activity.activityClass == HarvardActivityClass.insufficientData
          ? 'insufficient_data'
          : 'ok',
      reasonCodes: const [],
      dataQuality: _safeJsonMap({
        'recommendations_count': activity.recommendationKeys.length,
      }),
      features: _safeJsonMap({
        'activity_class': _activityClassCode(activity.activityClass),
        'recommendation_keys': activity.recommendationKeys,
      }),
    );
  }

  Future<void> _persistHealthScoreOutput({
    required HealthScoreInput input,
    required HealthScoreResult result,
  }) async {
    if (!AppEnv.isSupabaseConfigured) {
      return;
    }

    try {
      await modelOutputRemoteDataSource.saveOutputs([
        _healthScoreOutputPayload(input: input, result: result),
      ]);
    } on AuthFailure {
      // Auth can expire between dashboard load and persistence. Dashboard
      // should still render current in-memory health score.
    } catch (error, stackTrace) {
      _logger.warning(
        'dashboard.repository',
        'Failed to persist healthscore_v1 output',
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
      features: _safeJsonMap({
        ...result.features,
        'group_scores': result.groupScores
            .map(
              (group) => _safeJsonMap({
                'code': group.code,
                'score': group.score,
                'confidence': group.confidence,
              }),
            )
            .toList(growable: false),
      }),
    );
  }

  HealthModelOutputPayload _healthScoreOutputPayload({
    required HealthScoreInput input,
    required HealthScoreResult result,
  }) {
    final inversedStress = input.stressScore == null
        ? null
        : (100.0 - input.stressScore!.clamp(0.0, 100.0)).clamp(0.0, 100.0);
    final inversedAnomaly = input.anomalyScore == null
        ? null
        : (100.0 - input.anomalyScore!.clamp(0.0, 100.0)).clamp(0.0, 100.0);
    final inversedBaseline = input.baselineDeviationScore == null
        ? null
        : (100.0 - input.baselineDeviationScore!.clamp(0.0, 100.0)).clamp(
            0.0,
            100.0,
          );
    final availableComponents =
        (result.inputQuality['available_components'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList(growable: false);
    final missingComponents =
        (result.inputQuality['missing_components'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList(growable: false);

    return HealthModelOutputPayload(
      modelId: 'healthscore_v1',
      modelVersion: HealthScoreResult.versionId,
      windowStart: input.computedAt.toUtc(),
      windowEnd: result.computedAt.toUtc(),
      score: result.score?.toDouble(),
      confidence: result.confidence,
      status: result.band.code,
      source: 'domain_formula_v1',
      reason: result.band == HealthScoreBand.noAccess
          ? 'insufficient_data'
          : 'ok',
      reasonCodes: result.alerts
          .map((alert) => _safeJsonMap(alert.toJson()))
          .toList(growable: false),
      dataQuality: _safeJsonMap({
        'completeness': result.inputQuality['completeness'],
        'confidence': result.confidence,
        'available_components': availableComponents ?? const <String>[],
        'missing_components': missingComponents ?? const <String>[],
      }),
      features: _safeJsonMap({
        'base': input.baseScore,
        'sleep': input.sleepScore,
        'stress': input.stressScore,
        'anomaly': input.anomalyScore,
        'baselineDeviation': input.baselineDeviationScore,
        'inversed': _safeJsonMap({
          'stress': inversedStress,
          'anomaly': inversedAnomaly,
          'baselineDeviation': inversedBaseline,
        }),
        'weights': _safeJsonMap({
          'base': 0.35,
          'sleep': 0.25,
          'stressInv': 0.15,
          'anomalyInv': 0.15,
          'baselineInv': 0.10,
        }),
        'drivers': result.drivers
            .map((driver) => _safeJsonMap(driver.toJson()))
            .toList(growable: false),
      }),
    );
  }

  HealthModelOutputPayload _baselineForecastOutputPayload(
    BaselineForecastInferenceResult result,
  ) {
    return HealthModelOutputPayload(
      modelId: result.modelId,
      modelVersion: result.modelVersion,
      windowStart: result.windowStart,
      windowEnd: result.windowEnd,
      score: result.overallDeviationScore,
      confidence: result.confidence,
      status: result.status,
      source: result.source,
      reason: result.reason,
      reasonCodes: result.summary.mainReasons
          .map(
            (reason) => _safeJsonMap({
              'code': reason,
              'message': reason,
              'impact': reason == 'within_expected_range' ? 0.0 : 1.0,
            }),
          )
          .toList(growable: false),
      dataQuality: _safeJsonMap(result.dataQuality.toJson()),
      features: _safeJsonMap(result.features),
    );
  }

  String _legacyStatusFromBand(HealthScoreBand band) {
    return switch (band) {
      HealthScoreBand.green => 'stable',
      HealthScoreBand.yellow => 'attention',
      HealthScoreBand.orange || HealthScoreBand.red => 'risk',
      HealthScoreBand.noAccess => 'no_access',
    };
  }

  DateTime _resolveHealthScoreComputedAt({
    required _ResolvedModelContext modelContext,
    required DateTime fallback,
  }) {
    final candidates = <DateTime>[
      fallback.toUtc(),
      modelContext.stress.windowEnd.toUtc(),
      modelContext.physiologyAnomaly.windowEnd.toUtc(),
      modelContext.baselineForecast.windowEnd.toUtc(),
    ];
    final sleepEnd = modelContext.sleep.latestNight?.endUtc.toUtc();
    if (sleepEnd != null) {
      candidates.add(sleepEnd);
    }

    var latest = candidates.first;
    for (final candidate in candidates) {
      if (candidate.isAfter(latest)) {
        latest = candidate;
      }
    }
    return latest;
  }

  _ResolvedModelContext _insufficientModelContext() {
    return _ResolvedModelContext(
      recommendations: _insufficientRecommendations(),
      activity: const HarvardActivityRecommendationResult(
        activityClass: HarvardActivityClass.insufficientData,
        confidence: 0,
        recommendationKeys: <String>[
          'modelRecInsufficient1',
          'modelRecInsufficient2',
          'modelRecInsufficient3',
        ],
        modelVersion: 'unknown',
      ),
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
      baselineForecast: BaselineForecastInferenceResult.insufficient(
        now: DateTime.now().toUtc(),
        reason: 'snapshot_unavailable',
      ),
      connectedSourceCount: 0,
      wearableSamples: const <HealthMetricSample>[],
      latestWearableSampleAt: null,
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

  DashboardModelResults _buildModelResults({
    required HarvardActivityRecommendationResult activity,
    required SleepQualityInferenceResult sleep,
    required StressInferenceResult stress,
    required BaselineForecastInferenceResult baseline,
    required PhysiologyAnomalyInferenceResult recovery,
    required HealthScoreResult healthScoreResult,
  }) {
    return DashboardModelResults(
      activity: _mapActivityResult(activity),
      sleep: _mapSleepResult(sleep, baseline),
      stress: _mapStressResult(stress),
      baseline: _mapBaselineResult(baseline),
      recovery: _mapRecoveryResult(recovery),
      healthScoreConfidence: healthScoreResult.confidence,
      healthDrivers: _mapHealthDrivers(healthScoreResult),
    );
  }

  DashboardActivityModelResult _mapActivityResult(
    HarvardActivityRecommendationResult result,
  ) {
    final insufficient =
        result.activityClass == HarvardActivityClass.insufficientData;
    return DashboardActivityModelResult(
      activityClass: _activityClassCode(result.activityClass),
      confidence: insufficient ? null : result.confidence,
      insufficientData: insufficient,
      recommendationKeys: result.recommendationKeys,
      modelVersion: result.modelVersion,
    );
  }

  DashboardSleepModelResult _mapSleepResult(
    SleepQualityInferenceResult sleep,
    BaselineForecastInferenceResult baseline,
  ) {
    final score = _normalizeSleepScore(sleep.score);
    final baselineSleep = baseline.metrics['sleep_duration'];
    final isInsufficient = sleep.insufficientData || score == null;

    return DashboardSleepModelResult(
      score: score,
      confidence: sleep.confidence,
      insufficientData: isInsufficient,
      status: isInsufficient ? 'insufficient' : _statusForModelScore(score),
      reason: sleep.reason,
      sleepMinutes: sleep.latestNight?.sleepMinutes,
      sleepDurationDeviationMinutes: baselineSleep?.actualIsPartial == true
          ? null
          : baselineSleep?.delta,
    );
  }

  DashboardStressModelResult _mapStressResult(StressInferenceResult stress) {
    return DashboardStressModelResult(
      score: _normalizeStressScore(stress.stressScore),
      confidence: stress.confidence,
      insufficientData: stress.insufficientData,
      status: stress.insufficientData
          ? 'insufficient'
          : _statusFromStressCode(stress.status),
      reason: stress.reason,
      heartRate: stress.features['hr_mean'],
      hrvSdnn: stress.features['hrv_sdnn_latest'],
      hrvRmssd: stress.features['hrv_rmssd_latest'],
      sleepHoursDelta: stress.features['sleep_hours_delta_7'],
      activitySteps1h: stress.features['steps_1h'],
      reasons: stress.reasonCodes
          .map(
            (reason) => DashboardModelReason(
              code: reason.code,
              message: reason.message,
              severity: reason.severity,
              impact: reason.contribution,
            ),
          )
          .toList(growable: false),
    );
  }

  DashboardBaselineModelResult _mapBaselineResult(
    BaselineForecastInferenceResult result,
  ) {
    final deviations =
        result.metrics.entries
            .map(
              (entry) => DashboardBaselineDeviation(
                metric: entry.key,
                expected: entry.value.expected,
                actual: entry.value.actual,
                delta: entry.value.actualIsPartial ? null : entry.value.delta,
                robustZ: entry.value.actualIsPartial
                    ? null
                    : entry.value.robustZ,
                severity: entry.value.severity,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final severityCompare = _severityRank(
              b.severity,
            ).compareTo(_severityRank(a.severity));
            if (severityCompare != 0) return severityCompare;
            return (b.robustZ?.abs() ?? 0).compareTo(a.robustZ?.abs() ?? 0);
          });

    return DashboardBaselineModelResult(
      score: _normalizeBaselineDeviationScore(result.overallDeviationScore),
      confidence: result.confidence,
      insufficientData: result.insufficientData,
      status: result.insufficientData
          ? 'insufficient'
          : _statusFromBaselineCode(result.status),
      reason: result.reason,
      mainReasons: result.summary.mainReasons.take(4).toList(growable: false),
      deviations: deviations.take(5).toList(growable: false),
    );
  }

  DashboardRecoveryModelResult _mapRecoveryResult(
    PhysiologyAnomalyInferenceResult result,
  ) {
    final reasons = result.reasonCodes
        .map(
          (reason) => DashboardModelReason(
            code: reason.code,
            message: reason.message,
            severity: reason.impact >= 0.66
                ? 'high'
                : reason.impact >= 0.33
                ? 'medium'
                : 'low',
            impact: reason.impact,
          ),
        )
        .toList(growable: false);

    return DashboardRecoveryModelResult(
      score: _normalizeAnomalyScore(result.anomalyScore),
      confidence: result.confidence,
      insufficientData: result.insufficientData,
      status: result.insufficientData
          ? 'insufficient'
          : _statusFromStressCode(result.status),
      reason: result.reason,
      reasons: reasons,
      groups: result.groupScores
          .map(
            (group) => DashboardModelGroupScore(
              code: group.code,
              score: group.score,
              confidence: group.confidence,
            ),
          )
          .toList(growable: false),
    );
  }

  List<DashboardHealthDriver> _mapHealthDrivers(HealthScoreResult result) {
    final drivers =
        result.drivers
            .map(
              (driver) => DashboardHealthDriver(
                id: driver.id,
                contribution: driver.contribution,
                effectiveScore: driver.effectiveScore,
                confidence: driver.confidence,
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => b.contribution.abs().compareTo(a.contribution.abs()),
          );
    return drivers.take(4).toList(growable: false);
  }

  List<DashboardMetric> _buildTodayMetrics({
    required List<HealthMetricSample> samples,
    required SleepQualityInferenceResult sleep,
    required StressInferenceResult stress,
    required PhysiologyAnomalyInferenceResult recovery,
  }) {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);

    final heartSeries = _buildAverageSeries(
      samples,
      types: const [HealthMetricType.heartRate],
      end: now,
      bucketCount: 8,
      bucketDuration: const Duration(hours: 3),
    );
    final hrvSeries = _buildAverageSeries(
      samples,
      types: const [
        HealthMetricType.heartRateVariabilityRmssd,
        HealthMetricType.heartRateVariabilitySdnn,
      ],
      end: now,
      bucketCount: 8,
      bucketDuration: const Duration(hours: 3),
    );
    final sleepSeries = _buildSleepDurationSeries(samples, end: now, days: 7);
    final stepsSeries = _buildSumSeries(
      samples,
      types: const [HealthMetricType.steps],
      end: now,
      bucketCount: 7,
      bucketDuration: const Duration(days: 1),
    );
    final activeMinutesSeries = _buildSumSeries(
      samples,
      types: const [HealthMetricType.exerciseTime],
      end: now,
      bucketCount: 7,
      bucketDuration: const Duration(days: 1),
      valueTransform: _exerciseMinutesFromSample,
    );

    final heart = _latestMetricValue(
      samples,
      types: const [HealthMetricType.heartRate],
      start: dayStart,
      end: now,
    );
    final hrv = _latestMetricValue(
      samples,
      types: const [
        HealthMetricType.heartRateVariabilityRmssd,
        HealthMetricType.heartRateVariabilitySdnn,
      ],
      start: dayStart,
      end: now,
    );
    final steps = _sumMetricValue(
      samples,
      types: const [HealthMetricType.steps],
      start: dayStart,
      end: now,
    );
    final activeMinutes = _sumMetricValue(
      samples,
      types: const [HealthMetricType.exerciseTime],
      start: dayStart,
      end: now,
      valueTransform: _exerciseMinutesFromSample,
    );
    final sleepHours = sleep.latestNight == null
        ? null
        : (sleep.latestNight!.sleepMinutes / 60.0);
    final stressScore = _normalizeStressScore(stress.stressScore);
    final recoveryScore = _normalizeAnomalyScore(recovery.anomalyScore);

    return List.unmodifiable([
      _buildMetric(
        id: 'heart',
        labelKey: 'heartRate',
        value: heart,
        digits: 0,
        unit: 'bpm',
        series: heartSeries,
      ),
      _buildMetric(
        id: 'hrv',
        labelKey: 'hrv',
        value: hrv,
        digits: 0,
        unit: 'ms',
        series: hrvSeries,
      ),
      _buildMetric(
        id: 'sleep',
        labelKey: 'sleep',
        value: sleepHours,
        digits: 1,
        unit: 'h',
        series: sleepSeries,
      ),
      _buildMetric(
        id: 'steps',
        labelKey: 'steps',
        value: steps,
        digits: 0,
        unit: '',
        series: stepsSeries,
      ),
      _buildMetric(
        id: 'active_minutes',
        labelKey: 'activeMinutes',
        value: activeMinutes,
        digits: 0,
        unit: 'min',
        series: activeMinutesSeries,
      ),
      _buildMetric(
        id: 'stress_today',
        labelKey: 'stress',
        value: stressScore,
        digits: 0,
        unit: '/100',
        series: stressScore == null ? const [] : [stressScore],
      ),
      _buildMetric(
        id: 'recovery_today',
        labelKey: 'recovery',
        value: recoveryScore,
        digits: 0,
        unit: '/100',
        series: recoveryScore == null ? const [] : [recoveryScore],
      ),
    ]);
  }

  DashboardMetric _buildMetric({
    required String id,
    required String labelKey,
    required double? value,
    required int digits,
    required String unit,
    required List<double> series,
  }) {
    final isAvailable = value != null && value.isFinite;
    final double? safe = isAvailable
        ? value.clamp(0.0, 1000000.0).toDouble()
        : null;
    final sanitizedSeries = series
        .where((point) => point.isFinite)
        .map((point) => point.clamp(0.0, 1000000.0).toDouble())
        .toList(growable: false);
    final resolvedSeries = sanitizedSeries.isNotEmpty
        ? sanitizedSeries
        : safe == null
        ? const <double>[]
        : <double>[safe];
    return DashboardMetric(
      id: id,
      labelKey: labelKey,
      value: safe == null ? '—' : safe.toStringAsFixed(digits),
      unit: unit,
      trend: safe == null ? 'stable' : _deriveTrend(resolvedSeries),
      data: resolvedSeries,
    );
  }

  List<double> _buildAverageSeries(
    List<HealthMetricSample> samples, {
    required List<HealthMetricType> types,
    required DateTime end,
    required int bucketCount,
    required Duration bucketDuration,
    double Function(HealthMetricSample sample)? valueTransform,
  }) {
    return _buildBucketSeries(
      samples,
      types: types,
      end: end,
      bucketCount: bucketCount,
      bucketDuration: bucketDuration,
      mode: _BucketAggregationMode.average,
      valueTransform: valueTransform,
    );
  }

  List<double> _buildSumSeries(
    List<HealthMetricSample> samples, {
    required List<HealthMetricType> types,
    required DateTime end,
    required int bucketCount,
    required Duration bucketDuration,
    double Function(HealthMetricSample sample)? valueTransform,
  }) {
    return _buildBucketSeries(
      samples,
      types: types,
      end: end,
      bucketCount: bucketCount,
      bucketDuration: bucketDuration,
      mode: _BucketAggregationMode.sum,
      valueTransform: valueTransform,
    );
  }

  List<double> _buildSleepDurationSeries(
    List<HealthMetricSample> samples, {
    required DateTime end,
    required int days,
  }) {
    final types = _pickSleepSeriesTypes(samples);
    if (types.isEmpty) {
      return const <double>[];
    }

    return _buildSumSeries(
      samples,
      types: types,
      end: end,
      bucketCount: days,
      bucketDuration: const Duration(days: 1),
      valueTransform: _sleepHoursFromSample,
    );
  }

  List<HealthMetricType> _pickSleepSeriesTypes(
    List<HealthMetricSample> samples,
  ) {
    final available = samples.map((sample) => sample.type).toSet();
    if (available.contains(HealthMetricType.sleepAsleep)) {
      return const [HealthMetricType.sleepAsleep];
    }
    if (available.contains(HealthMetricType.sleep)) {
      return const [HealthMetricType.sleep];
    }
    if (available.contains(HealthMetricType.sleepSession)) {
      return const [HealthMetricType.sleepSession];
    }

    final sleepStageTypes = <HealthMetricType>[
      HealthMetricType.sleepDeep,
      HealthMetricType.sleepLight,
      HealthMetricType.sleepRem,
    ].where(available.contains).toList(growable: false);

    return sleepStageTypes;
  }

  List<double> _buildBucketSeries(
    List<HealthMetricSample> samples, {
    required List<HealthMetricType> types,
    required DateTime end,
    required int bucketCount,
    required Duration bucketDuration,
    required _BucketAggregationMode mode,
    double Function(HealthMetricSample sample)? valueTransform,
  }) {
    if (bucketCount <= 0 || bucketDuration <= Duration.zero || types.isEmpty) {
      return const <double>[];
    }

    final typeSet = types.toSet();
    final endUtc = end.toUtc();
    final bucketMicros = bucketDuration.inMicroseconds;
    final windowStart = endUtc.subtract(
      Duration(microseconds: bucketMicros * bucketCount),
    );
    final output = <double>[];

    for (var bucketIndex = 0; bucketIndex < bucketCount; bucketIndex++) {
      final bucketStart = windowStart.add(
        Duration(microseconds: bucketMicros * bucketIndex),
      );
      final bucketEnd = bucketStart.add(bucketDuration);

      var sum = 0.0;
      var count = 0;
      for (final sample in samples) {
        if (!typeSet.contains(sample.type)) {
          continue;
        }
        final timestamp = sample.timestamp.toUtc();
        if (timestamp.isBefore(bucketStart)) {
          continue;
        }
        final isInsideBucket = bucketIndex == bucketCount - 1
            ? !timestamp.isAfter(endUtc)
            : timestamp.isBefore(bucketEnd);
        if (!isInsideBucket) {
          continue;
        }
        final value = valueTransform?.call(sample) ?? sample.value;
        if (!value.isFinite) {
          continue;
        }
        sum += value;
        count += 1;
      }

      if (count == 0) {
        continue;
      }
      output.add(mode == _BucketAggregationMode.sum ? sum : sum / count);
    }

    return output.toList(growable: false);
  }

  double _sleepHoursFromSample(HealthMetricSample sample) {
    final unit = sample.unit.trim().toLowerCase();
    if (unit.contains('sec')) {
      return sample.value / 3600.0;
    }
    if (unit.contains('min')) {
      return sample.value / 60.0;
    }
    if (unit.contains('hour') || unit == 'h' || unit == 'hr') {
      return sample.value;
    }
    if (sample.value > 24) {
      return sample.value / 60.0;
    }
    return sample.value;
  }

  double _exerciseMinutesFromSample(HealthMetricSample sample) {
    final unit = sample.unit.trim().toLowerCase();
    if (unit.contains('sec')) {
      return sample.value / 60.0;
    }
    if (unit.contains('hour') || unit == 'h' || unit == 'hr') {
      return sample.value * 60.0;
    }
    return sample.value;
  }

  double? _latestMetricValue(
    List<HealthMetricSample> samples, {
    required List<HealthMetricType> types,
    required DateTime start,
    required DateTime end,
  }) {
    double? value;
    DateTime? latest;
    final typeSet = types.toSet();
    for (final sample in samples) {
      if (!typeSet.contains(sample.type)) {
        continue;
      }
      final ts = sample.timestamp.toUtc();
      if (ts.isBefore(start) || ts.isAfter(end)) {
        continue;
      }
      if (latest == null || ts.isAfter(latest)) {
        latest = ts;
        value = sample.value;
      }
    }
    return value;
  }

  double? _sumMetricValue(
    List<HealthMetricSample> samples, {
    required List<HealthMetricType> types,
    required DateTime start,
    required DateTime end,
    double Function(HealthMetricSample sample)? valueTransform,
  }) {
    double total = 0.0;
    var hasAny = false;
    final typeSet = types.toSet();
    for (final sample in samples) {
      if (!typeSet.contains(sample.type)) {
        continue;
      }
      final ts = sample.timestamp.toUtc();
      if (ts.isBefore(start) || ts.isAfter(end)) {
        continue;
      }
      final value = valueTransform?.call(sample) ?? sample.value;
      if (!value.isFinite) {
        continue;
      }
      hasAny = true;
      total += value;
    }
    return hasAny ? total : null;
  }

  String _deriveTrend(List<double> values) {
    if (values.length < 2) return 'stable';
    final delta = values.last - values[values.length - 2];
    if (delta > 0.5) return 'up';
    if (delta < -0.5) return 'down';
    return 'stable';
  }

  int _severityRank(String severity) {
    return switch (severity) {
      'high' => 5,
      'moderate' => 4,
      'mild' => 3,
      'normal' => 2,
      'pending' => 1,
      _ => 0,
    };
  }

  String _activityClassCode(HarvardActivityClass activityClass) {
    return switch (activityClass) {
      HarvardActivityClass.lying => 'lying',
      HarvardActivityClass.sitting => 'sitting',
      HarvardActivityClass.selfPaceWalk => 'self_pace_walk',
      HarvardActivityClass.running3Met => 'running_3_met',
      HarvardActivityClass.running5Met => 'running_5_met',
      HarvardActivityClass.running7Met => 'running_7_met',
      HarvardActivityClass.insufficientData => 'insufficient_data',
    };
  }

  String _statusForModelScore(double? value) {
    if (value == null) return 'insufficient';
    if (value >= 80) return 'good';
    if (value >= 60) return 'attention';
    return 'poor';
  }

  String _statusFromStressCode(String status) {
    return switch (status) {
      'risk' => 'warning',
      'attention' => 'attention',
      'stable' => 'good',
      _ => 'insufficient',
    };
  }

  String _statusFromBaselineCode(String status) {
    return switch (status) {
      'high_deviation' => 'warning',
      'attention' => 'attention',
      'stable' => 'good',
      'pending_actuals' => 'insufficient',
      _ => 'insufficient',
    };
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

  double? _normalizeBaselineDeviationScore(double? value) {
    if (value == null || !value.isFinite) {
      if (value != null && !value.isFinite) {
        _logger.warning(
          'dashboard.repository',
          'Baseline deviation score is non-finite, dropping value',
          payload: {'baselineDeviationScore': value},
        );
      }
      return null;
    }
    final normalized = value.clamp(0.0, 100.0);
    if (normalized != value) {
      _logger.warning(
        'dashboard.repository',
        'Baseline deviation score was out of range and clamped',
        payload: {
          'baselineDeviationScore': value,
          'normalizedBaselineDeviationScore': normalized,
        },
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

enum _BucketAggregationMode { sum, average }

class _ResolvedModelContext {
  final _ResolvedRecommendations recommendations;
  final HarvardActivityRecommendationResult activity;
  final SleepQualityInferenceResult sleep;
  final StressInferenceResult stress;
  final PhysiologyAnomalyInferenceResult physiologyAnomaly;
  final BaselineForecastInferenceResult baselineForecast;
  final int connectedSourceCount;
  final List<HealthMetricSample> wearableSamples;
  final DateTime? latestWearableSampleAt;

  const _ResolvedModelContext({
    required this.recommendations,
    required this.activity,
    required this.sleep,
    required this.stress,
    required this.physiologyAnomaly,
    required this.baselineForecast,
    required this.connectedSourceCount,
    required this.wearableSamples,
    required this.latestWearableSampleAt,
  });

  bool get hasAnyWearableData => wearableSamples.isNotEmpty;
}

class _ResolvedRecommendations {
  final List<String> keys;
  final bool insufficient;

  const _ResolvedRecommendations({
    required this.keys,
    required this.insufficient,
  });
}
