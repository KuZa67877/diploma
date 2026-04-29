import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_env.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/anonymous_user_snapshot_data_source.dart';
import '../../../../core/supabase/onboarding_profile_snapshot.dart';
import '../../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../../wellbeing/domain/entities/health_score_input.dart';
import '../../../wellbeing/domain/entities/wellbeing_entry.dart';
import '../../../wellbeing/domain/repositories/wellbeing_repository.dart';
import '../../../wellbeing/domain/services/healthscore_base_component_service.dart';
import '../../../wellbeing/domain/usecases/calculate_healthscore.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_data_model.dart';
import '../models/profile_user_model.dart';
import '../datasources/profile_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  static const List<String> _healthScoreModelIds = [
    'sleep_quality',
    'stress_score_v1',
    'personal_physiology_anomaly_v1',
    'baseline_forecast_v1',
  ];

  final ProfileLocalDataSource localDataSource;
  final AnonymousUserSnapshotDataSource snapshotDataSource;
  final HealthModelOutputRemoteDataSource modelOutputRemoteDataSource;
  final HealthScoreBaseComponentService healthScoreBaseComponentService;
  final CalculateHealthScore calculateHealthScore;
  final WellbeingRepository wellbeingRepository;
  final _logger = AppLogger.instance;

  ProfileRepositoryImpl({
    required this.localDataSource,
    required this.snapshotDataSource,
    required this.modelOutputRemoteDataSource,
    required this.healthScoreBaseComponentService,
    required this.calculateHealthScore,
    required this.wellbeingRepository,
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
      Map<String, HealthModelOutputRecord> latestOutputs = const {};
      try {
        latestOutputs = await modelOutputRemoteDataSource
            .getLatestOutputsByModelIds(_healthScoreModelIds);
      } on AuthFailure {
        latestOutputs = const {};
      } catch (error, stackTrace) {
        latestOutputs = const {};
        _logger.warning(
          'profile.repository',
          'Failed to load latest model outputs, fallback to available base score only',
          payload: {'error': '$error', 'stackTrace': '$stackTrace'},
        );
      }

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
      final sleepOutput = latestOutputs['sleep_quality'];
      final stressOutput = latestOutputs['stress_score_v1'];
      final anomalyOutput = latestOutputs['personal_physiology_anomaly_v1'];
      final baselineOutput = latestOutputs['baseline_forecast_v1'];
      final wellbeingEntry = await _loadLatestWellbeingEntry();
      final input = HealthScoreInput(
        baseScore: baseScore,
        sleepScore: _normalizeScore(sleepOutput?.score),
        stressScore: _normalizeScore(stressOutput?.score),
        anomalyScore: _normalizeScore(anomalyOutput?.score),
        baselineDeviationScore: _normalizeScore(baselineOutput?.score),
        baseConfidence: baseScore == null ? null : baseConfidence,
        sleepConfidence: sleepOutput?.confidence,
        stressConfidence: stressOutput?.confidence,
        anomalyConfidence: anomalyOutput?.confidence,
        baselineDeviationConfidence: baselineOutput?.confidence,
        computedAt: _resolveComputedAt(
          fallback: DateTime.now().toUtc(),
          outputs: [sleepOutput, stressOutput, anomalyOutput, baselineOutput],
        ),
        wellbeingEntry: wellbeingEntry,
        scoreNow: DateTime.now(),
      );
      final healthScoreResult = calculateHealthScore(input);
      final healthScore = healthScoreResult.score;
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

  double? _normalizeScore(double? score) {
    if (score == null || !score.isFinite) {
      return null;
    }
    return score.clamp(0.0, 100.0).toDouble();
  }

  DateTime _resolveComputedAt({
    required DateTime fallback,
    required List<HealthModelOutputRecord?> outputs,
  }) {
    var latest = fallback.toUtc();
    for (final output in outputs) {
      final end = output?.windowEnd.toUtc();
      if (end != null && end.isAfter(latest)) {
        latest = end;
      }
    }
    return latest;
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

  Future<WellbeingEntry?> _loadLatestWellbeingEntry() async {
    final result = await wellbeingRepository.getEntries();
    return result.fold(
      (_) => null,
      (entries) => entries.isEmpty ? null : entries.first,
    );
  }
}
