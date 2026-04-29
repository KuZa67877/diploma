import 'package:equatable/equatable.dart';
import '../../../wellbeing/domain/entities/diary_health_adjustment.dart';
import 'dashboard_insight.dart';
import 'dashboard_metric.dart';

class DashboardSummary extends Equatable {
  final String greetingKey;
  final String userName;
  final int healthScore;
  final String status;
  final List<String> recommendationKeys;
  final bool hasInsufficientModelData;
  final DashboardInsight insight;
  final List<DashboardMetric> metrics;
  final int? objectiveHealthScore;
  final DashboardDataSnapshot dataSnapshot;
  final DashboardModelResults modelResults;

  const DashboardSummary({
    required this.greetingKey,
    required this.userName,
    required this.healthScore,
    required this.status,
    this.recommendationKeys = const <String>[],
    this.hasInsufficientModelData = false,
    required this.insight,
    required this.metrics,
    this.objectiveHealthScore,
    this.dataSnapshot = const DashboardDataSnapshot(),
    this.modelResults = const DashboardModelResults(),
  });

  @override
  List<Object?> get props => [
    greetingKey,
    userName,
    healthScore,
    status,
    recommendationKeys,
    hasInsufficientModelData,
    insight,
    metrics,
    objectiveHealthScore,
    dataSnapshot,
    modelResults,
  ];
}

class DashboardDataSnapshot extends Equatable {
  final int connectedSources;
  final int wearableSampleCount;
  final DateTime? latestWearableSampleAt;

  const DashboardDataSnapshot({
    this.connectedSources = 0,
    this.wearableSampleCount = 0,
    this.latestWearableSampleAt,
  });

  bool get hasConnectedSources => connectedSources > 0;
  bool get hasWearableSamples => wearableSampleCount > 0;

  @override
  List<Object?> get props => [
    connectedSources,
    wearableSampleCount,
    latestWearableSampleAt,
  ];
}

class DashboardModelResults extends Equatable {
  final DashboardActivityModelResult activity;
  final DashboardSleepModelResult sleep;
  final DashboardStressModelResult stress;
  final DashboardBaselineModelResult baseline;
  final DashboardRecoveryModelResult recovery;
  final List<DashboardHealthDriver> healthDrivers;
  final double healthScoreConfidence;
  final DiaryHealthAdjustment diaryAdjustment;

  const DashboardModelResults({
    this.activity = const DashboardActivityModelResult.insufficient(),
    this.sleep = const DashboardSleepModelResult.insufficient(),
    this.stress = const DashboardStressModelResult.insufficient(),
    this.baseline = const DashboardBaselineModelResult.insufficient(),
    this.recovery = const DashboardRecoveryModelResult.insufficient(),
    this.healthDrivers = const <DashboardHealthDriver>[],
    this.healthScoreConfidence = 0,
    this.diaryAdjustment = const DiaryHealthAdjustment.none(),
  });

  @override
  List<Object> get props => [
    activity,
    sleep,
    stress,
    baseline,
    recovery,
    healthDrivers,
    healthScoreConfidence,
    diaryAdjustment,
  ];
}

class DashboardActivityModelResult extends Equatable {
  final String activityClass;
  final double? confidence;
  final bool insufficientData;
  final List<String> recommendationKeys;
  final String modelVersion;

  const DashboardActivityModelResult({
    required this.activityClass,
    required this.confidence,
    required this.insufficientData,
    required this.recommendationKeys,
    required this.modelVersion,
  });

  const DashboardActivityModelResult.insufficient({
    this.activityClass = 'insufficient_data',
    this.confidence,
    this.insufficientData = true,
    this.recommendationKeys = const <String>[],
    this.modelVersion = 'unknown',
  });

  @override
  List<Object?> get props => [
    activityClass,
    confidence,
    insufficientData,
    recommendationKeys,
    modelVersion,
  ];
}

class DashboardSleepModelResult extends Equatable {
  final double? score;
  final double confidence;
  final bool insufficientData;
  final String status;
  final String reason;
  final double? sleepMinutes;
  final double? sleepDurationDeviationMinutes;

  const DashboardSleepModelResult({
    required this.score,
    required this.confidence,
    required this.insufficientData,
    required this.status,
    required this.reason,
    required this.sleepMinutes,
    required this.sleepDurationDeviationMinutes,
  });

  const DashboardSleepModelResult.insufficient({
    this.score,
    this.confidence = 0,
    this.insufficientData = true,
    this.status = 'insufficient',
    this.reason = 'insufficient_data',
    this.sleepMinutes,
    this.sleepDurationDeviationMinutes,
  });

  @override
  List<Object?> get props => [
    score,
    confidence,
    insufficientData,
    status,
    reason,
    sleepMinutes,
    sleepDurationDeviationMinutes,
  ];
}

class DashboardStressModelResult extends Equatable {
  final double? score;
  final double confidence;
  final bool insufficientData;
  final String status;
  final String reason;
  final double? heartRate;
  final double? hrvSdnn;
  final double? hrvRmssd;
  final double? sleepHoursDelta;
  final double? activitySteps1h;
  final List<DashboardModelReason> reasons;

  const DashboardStressModelResult({
    required this.score,
    required this.confidence,
    required this.insufficientData,
    required this.status,
    required this.reason,
    required this.heartRate,
    required this.hrvSdnn,
    required this.hrvRmssd,
    required this.sleepHoursDelta,
    required this.activitySteps1h,
    required this.reasons,
  });

  const DashboardStressModelResult.insufficient({
    this.score,
    this.confidence = 0,
    this.insufficientData = true,
    this.status = 'insufficient',
    this.reason = 'insufficient_data',
    this.heartRate,
    this.hrvSdnn,
    this.hrvRmssd,
    this.sleepHoursDelta,
    this.activitySteps1h,
    this.reasons = const <DashboardModelReason>[],
  });

  @override
  List<Object?> get props => [
    score,
    confidence,
    insufficientData,
    status,
    reason,
    heartRate,
    hrvSdnn,
    hrvRmssd,
    sleepHoursDelta,
    activitySteps1h,
    reasons,
  ];
}

class DashboardBaselineModelResult extends Equatable {
  final double? score;
  final double confidence;
  final bool insufficientData;
  final String status;
  final String reason;
  final List<String> mainReasons;
  final List<DashboardBaselineDeviation> deviations;

  const DashboardBaselineModelResult({
    required this.score,
    required this.confidence,
    required this.insufficientData,
    required this.status,
    required this.reason,
    required this.mainReasons,
    required this.deviations,
  });

  const DashboardBaselineModelResult.insufficient({
    this.score,
    this.confidence = 0,
    this.insufficientData = true,
    this.status = 'insufficient',
    this.reason = 'insufficient_data',
    this.mainReasons = const <String>[],
    this.deviations = const <DashboardBaselineDeviation>[],
  });

  @override
  List<Object?> get props => [
    score,
    confidence,
    insufficientData,
    status,
    reason,
    mainReasons,
    deviations,
  ];
}

class DashboardBaselineDeviation extends Equatable {
  final String metric;
  final double? expected;
  final double? actual;
  final double? delta;
  final double? robustZ;
  final String severity;

  const DashboardBaselineDeviation({
    required this.metric,
    required this.expected,
    required this.actual,
    required this.delta,
    required this.robustZ,
    required this.severity,
  });

  @override
  List<Object?> get props => [
    metric,
    expected,
    actual,
    delta,
    robustZ,
    severity,
  ];
}

class DashboardRecoveryModelResult extends Equatable {
  final double? score;
  final double confidence;
  final bool insufficientData;
  final String status;
  final String reason;
  final List<DashboardModelReason> reasons;
  final List<DashboardModelGroupScore> groups;

  const DashboardRecoveryModelResult({
    required this.score,
    required this.confidence,
    required this.insufficientData,
    required this.status,
    required this.reason,
    required this.reasons,
    required this.groups,
  });

  const DashboardRecoveryModelResult.insufficient({
    this.score,
    this.confidence = 0,
    this.insufficientData = true,
    this.status = 'insufficient',
    this.reason = 'insufficient_data',
    this.reasons = const <DashboardModelReason>[],
    this.groups = const <DashboardModelGroupScore>[],
  });

  @override
  List<Object?> get props => [
    score,
    confidence,
    insufficientData,
    status,
    reason,
    reasons,
    groups,
  ];
}

class DashboardModelReason extends Equatable {
  final String code;
  final String message;
  final String severity;
  final double impact;

  const DashboardModelReason({
    required this.code,
    required this.message,
    required this.severity,
    required this.impact,
  });

  @override
  List<Object> get props => [code, message, severity, impact];
}

class DashboardModelGroupScore extends Equatable {
  final String code;
  final double score;
  final double confidence;

  const DashboardModelGroupScore({
    required this.code,
    required this.score,
    required this.confidence,
  });

  @override
  List<Object> get props => [code, score, confidence];
}

class DashboardHealthDriver extends Equatable {
  final String id;
  final double contribution;
  final double effectiveScore;
  final double confidence;

  const DashboardHealthDriver({
    required this.id,
    required this.contribution,
    required this.effectiveScore,
    required this.confidence,
  });

  @override
  List<Object> get props => [id, contribution, effectiveScore, confidence];
}
