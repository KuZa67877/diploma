import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/dashboard_insight.dart';
import '../../domain/entities/dashboard_metric.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../models/dashboard_ui_models.dart';
import '../widgets/mini_chart.dart';

part 'dashboard_cubit.freezed.dart';
part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetDashboardSummary getDashboardSummary;

  DashboardCubit({required this.getDashboardSummary})
    : super(const DashboardState.initial());

  Future<void> load() async {
    emit(const DashboardState.loading());

    final result = await getDashboardSummary(const NoParams());
    result.fold(
      (failure) =>
          emit(DashboardState.error(message: _mapFailureMessage(failure))),
      (summary) => emit(DashboardState.loaded(data: _mapToViewData(summary))),
    );
  }

  DashboardViewData _mapToViewData(DashboardSummary summary) {
    final dataStatus = _mapDataStatus(summary.dataSnapshot);
    final realScore = summary.healthScore > 0 ? summary.healthScore : null;
    final temporaryScore = realScore == null
        ? _calculateTemporaryScore(summary.modelResults)
        : null;
    final healthScore = realScore ?? temporaryScore ?? 0;
    final healthScoreIsTemporary = realScore == null && temporaryScore != null;
    final scoreState = _mapScoreState(
      status: summary.status,
      healthScore: healthScore,
      noData: !summary.dataSnapshot.hasWearableSamples,
    );

    return DashboardViewData(
      greetingKey: summary.greetingKey,
      userName: summary.userName,
      dateLabel: _formatDateLabel(DateTime.now()),
      dataStatus: dataStatus,
      dataStatusLabel: _dataStatusLabel(dataStatus),
      healthScore: healthScore,
      healthScoreIsTemporary: healthScoreIsTemporary,
      scoreState: scoreState,
      scoreStateLabel: _scoreStateLabel(scoreState),
      overallState: _mapOverallState(scoreState),
      overallSummary: _overallSummary(
        scoreState: scoreState,
        dataStatus: dataStatus,
        isTemporaryScore: healthScoreIsTemporary,
      ),
      overallExplanation: _overallExplanation(summary.modelResults),
      showInsufficientDataBanner:
          summary.hasInsufficientModelData ||
          dataStatus != DashboardDataStatusState.upToDate,
      recommendations: summary.recommendationKeys.isEmpty
          ? _recommendationsFor(scoreState)
          : summary.recommendationKeys.take(3).toList(growable: false),
      insight: _mapInsight(summary.insight),
      modelCards: _buildModelCards(summary.modelResults),
      aiRecommendations: _buildAiRecommendations(
        modelResults: summary.modelResults,
        dataStatus: dataStatus,
      ),
      keyMetrics: _mapKeyMetrics(summary.metrics),
      showNoDataState: _showNoDataState(summary, dataStatus),
      noDataMessage: const DashboardLocalizedText('dashboardNoDataMessage'),
      noDataHint: const DashboardLocalizedText('dashboardNoDataHint'),
      metrics: _mapMetrics(summary.metrics),
    );
  }

  bool _showNoDataState(
    DashboardSummary summary,
    DashboardDataStatusState dataStatus,
  ) {
    if (summary.dataSnapshot.hasWearableSamples) {
      return false;
    }
    return dataStatus == DashboardDataStatusState.insufficient ||
        dataStatus == DashboardDataStatusState.syncRequired;
  }

  DashboardDataStatusState _mapDataStatus(DashboardDataSnapshot snapshot) {
    if (!snapshot.hasConnectedSources) {
      return DashboardDataStatusState.syncRequired;
    }
    if (!snapshot.hasWearableSamples) {
      return DashboardDataStatusState.insufficient;
    }
    final latest = snapshot.latestWearableSampleAt;
    if (latest == null) {
      return DashboardDataStatusState.insufficient;
    }
    final age = DateTime.now().toUtc().difference(latest.toUtc());
    if (age > const Duration(hours: 36)) {
      return DashboardDataStatusState.syncRequired;
    }
    return DashboardDataStatusState.upToDate;
  }

  String _dataStatusLabel(DashboardDataStatusState state) {
    return switch (state) {
      DashboardDataStatusState.upToDate => 'dashboardDataStatusUpToDate',
      DashboardDataStatusState.insufficient =>
        'dashboardDataStatusInsufficient',
      DashboardDataStatusState.syncRequired =>
        'dashboardDataStatusSyncRequired',
    };
  }

  String _formatDateLabel(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$d.$m.$y';
  }

  int? _calculateTemporaryScore(DashboardModelResults results) {
    // Temporary aggregation for UI fallback when canonical healthscore
    // calculation returns no score.
    final weighted = <double>[];
    if (results.sleep.score != null) {
      weighted.add(results.sleep.score! * 0.30);
    }
    if (results.stress.score != null) {
      final inversed = 100.0 - results.stress.score!.clamp(0.0, 100.0);
      weighted.add(inversed * 0.20);
    }
    if (results.recovery.score != null) {
      final inversed = 100.0 - results.recovery.score!.clamp(0.0, 100.0);
      weighted.add(inversed * 0.20);
    }
    if (results.baseline.score != null) {
      final inversed = 100.0 - results.baseline.score!.clamp(0.0, 100.0);
      weighted.add(inversed * 0.20);
    }
    final activityScore = _activityScore(results.activity.activityClass);
    if (activityScore != null) {
      weighted.add(activityScore * 0.10);
    }
    if (weighted.isEmpty) {
      return null;
    }
    final totalWeight = weighted.fold<double>(0, (sum, item) => sum + item);
    return (totalWeight / 1.0).clamp(0, 100).round();
  }

  double? _activityScore(String activityClass) {
    return switch (activityClass) {
      'running_7_met' => 86,
      'running_5_met' => 80,
      'running_3_met' => 74,
      'self_pace_walk' => 68,
      'sitting' => 48,
      'lying' => 42,
      _ => null,
    };
  }

  DashboardVisualState _mapOverallState(DashboardScoreState state) {
    return switch (state) {
      DashboardScoreState.stable => DashboardVisualState.good,
      DashboardScoreState.attention => DashboardVisualState.attention,
      DashboardScoreState.risk => DashboardVisualState.warning,
      DashboardScoreState.noAccess ||
      DashboardScoreState.calculating => DashboardVisualState.insufficient,
    };
  }

  DashboardLocalizedText _overallSummary({
    required DashboardScoreState scoreState,
    required DashboardDataStatusState dataStatus,
    required bool isTemporaryScore,
  }) {
    if (dataStatus == DashboardDataStatusState.syncRequired) {
      return const DashboardLocalizedText('dashboardOverallSyncRequired');
    }
    if (dataStatus == DashboardDataStatusState.insufficient) {
      return const DashboardLocalizedText('dashboardOverallInsufficient');
    }
    final baseKey = switch (scoreState) {
      DashboardScoreState.stable => 'dashboardOverallStable',
      DashboardScoreState.attention => 'dashboardOverallAttention',
      DashboardScoreState.risk => 'dashboardOverallRisk',
      DashboardScoreState.noAccess ||
      DashboardScoreState.calculating => 'dashboardOverallNoAccess',
    };
    if (isTemporaryScore) {
      return const DashboardLocalizedText('dashboardOverallTemporary');
    }
    return DashboardLocalizedText(baseKey);
  }

  DashboardLocalizedText _overallExplanation(DashboardModelResults results) {
    if (results.healthDrivers.isEmpty) {
      return const DashboardLocalizedText('dashboardOverallFactorsPending');
    }
    final top = results.healthDrivers
        .take(3)
        .map((driver) => _driverLabel(driver.id))
        .join(', ');
    return DashboardLocalizedText(
      'dashboardOverallFactors',
      params: {'factors': top},
    );
  }

  String _driverLabel(String id) {
    return switch (id) {
      'sleep' => 'сон',
      'stress' => 'стресс',
      'anomaly' => 'восстановление',
      'baseline_deviation' => 'личная норма',
      'base' => 'базовые показатели профиля',
      _ => id,
    };
  }

  DashboardInsightUiModel _mapInsight(DashboardInsight insight) {
    return DashboardInsightUiModel(
      titleKey: insight.titleKey,
      descKey: insight.descKey,
    );
  }

  List<DashboardModelCardUiModel> _buildModelCards(DashboardModelResults data) {
    return [
      _activityCard(data.activity),
      _sleepCard(data.sleep),
      _stressCard(data.stress),
      _baselineCard(data.baseline),
      _recoveryCard(data.recovery),
    ];
  }

  DashboardModelCardUiModel _activityCard(DashboardActivityModelResult result) {
    if (result.insufficientData) {
      return const DashboardModelCardUiModel(
        id: 'activity',
        titleKey: 'activity',
        state: DashboardVisualState.insufficient,
        badge: DashboardLocalizedText('dashboardBadgeInsufficient'),
        summary: DashboardLocalizedText('dashboardActivitySummaryInsufficient'),
        explanation: DashboardLocalizedText(
          'dashboardActivityExplainInsufficient',
        ),
        recommendation: DashboardLocalizedText(
          'dashboardActivityRecInsufficient',
        ),
        progress: null,
      );
    }

    final confidencePct = ((result.confidence ?? 0) * 100).round();
    return DashboardModelCardUiModel(
      id: 'activity',
      titleKey: 'activity',
      state: _activityState(result.activityClass),
      badge: DashboardLocalizedText(
        'dashboardBadgeConfidence',
        params: {'value': '$confidencePct'},
      ),
      summary: DashboardLocalizedText(
        _activitySummaryKey(result.activityClass),
      ),
      explanation: const DashboardLocalizedText('dashboardActivityExplain'),
      recommendation: DashboardLocalizedText(
        _activityRecommendationKey(result.activityClass),
      ),
      progress: (result.confidence ?? 0).clamp(0.0, 1.0),
    );
  }

  DashboardVisualState _activityState(String activityClass) {
    return switch (activityClass) {
      'running_7_met' ||
      'running_5_met' ||
      'running_3_met' => DashboardVisualState.good,
      'self_pace_walk' => DashboardVisualState.attention,
      'sitting' || 'lying' => DashboardVisualState.warning,
      _ => DashboardVisualState.insufficient,
    };
  }

  String _activitySummaryKey(String activityClass) {
    return switch (activityClass) {
      'running_7_met' => 'dashboardActivitySummaryRunningHigh',
      'running_5_met' => 'dashboardActivitySummaryRunningModerate',
      'running_3_met' => 'dashboardActivitySummaryRunningLight',
      'self_pace_walk' => 'dashboardActivitySummaryWalk',
      'sitting' => 'dashboardActivitySummarySitting',
      'lying' => 'dashboardActivitySummaryRest',
      _ => 'dashboardActivitySummaryUnknown',
    };
  }

  String _activityRecommendationKey(String activityClass) {
    return switch (activityClass) {
      'sitting' || 'lying' => 'dashboardActivityRecLow',
      'self_pace_walk' => 'dashboardActivityRecWalk',
      'running_3_met' ||
      'running_5_met' ||
      'running_7_met' => 'dashboardActivityRecHigh',
      _ => 'dashboardActivityRecInsufficient',
    };
  }

  DashboardModelCardUiModel _sleepCard(DashboardSleepModelResult result) {
    if (result.insufficientData || result.score == null) {
      return const DashboardModelCardUiModel(
        id: 'sleep',
        titleKey: 'dashboardSleepRecoveryTitle',
        state: DashboardVisualState.insufficient,
        badge: DashboardLocalizedText('dashboardBadgeInsufficient'),
        summary: DashboardLocalizedText('dashboardSleepSummaryInsufficient'),
        explanation: DashboardLocalizedText(
          'dashboardSleepExplainInsufficient',
        ),
        recommendation: DashboardLocalizedText('dashboardSleepRecInsufficient'),
        progress: null,
      );
    }

    final hours = result.sleepMinutes == null
        ? '—'
        : (result.sleepMinutes! / 60.0).toStringAsFixed(1);
    final deviation = result.sleepDurationDeviationMinutes;
    final deviationText = deviation == null
        ? const DashboardLocalizedText('dashboardSleepDeviationUnavailable')
        : deviation >= 0
        ? DashboardLocalizedText(
            'dashboardSleepDeviationAbove',
            params: {'minutes': deviation.toStringAsFixed(0)},
          )
        : DashboardLocalizedText(
            'dashboardSleepDeviationBelow',
            params: {'minutes': deviation.abs().toStringAsFixed(0)},
          );

    return DashboardModelCardUiModel(
      id: 'sleep',
      titleKey: 'dashboardSleepRecoveryTitle',
      state: _stateFromStatus(result.status),
      badge: DashboardLocalizedText(
        'dashboardBadgeScoreOutOf100',
        params: {'value': result.score!.toStringAsFixed(0)},
      ),
      summary: DashboardLocalizedText(
        'dashboardSleepSummary',
        params: {'score': result.score!.toStringAsFixed(0), 'hours': hours},
      ),
      explanation: deviationText,
      recommendation: DashboardLocalizedText(
        result.score! < 60 ? 'dashboardSleepRecLow' : 'dashboardSleepRecGood',
      ),
      progress: (result.score! / 100).clamp(0.0, 1.0),
    );
  }

  DashboardModelCardUiModel _stressCard(DashboardStressModelResult result) {
    if (result.insufficientData || result.score == null) {
      return const DashboardModelCardUiModel(
        id: 'stress',
        titleKey: 'stress',
        state: DashboardVisualState.insufficient,
        badge: DashboardLocalizedText('dashboardBadgeInsufficient'),
        summary: DashboardLocalizedText('dashboardStressSummaryInsufficient'),
        explanation: DashboardLocalizedText(
          'dashboardStressExplainInsufficient',
        ),
        recommendation: DashboardLocalizedText(
          'dashboardStressRecInsufficient',
        ),
        progress: null,
      );
    }

    final factors = <String>[];
    if (result.heartRate != null) {
      factors.add('HR ${result.heartRate!.toStringAsFixed(0)} bpm');
    }
    if (result.hrvRmssd != null) {
      factors.add('RMSSD ${result.hrvRmssd!.toStringAsFixed(1)}');
    } else if (result.hrvSdnn != null) {
      factors.add('SDNN ${result.hrvSdnn!.toStringAsFixed(1)}');
    }
    if (result.sleepHoursDelta != null) {
      factors.add('Δсон ${result.sleepHoursDelta!.toStringAsFixed(1)} ч');
    }
    if (result.activitySteps1h != null) {
      factors.add('шаги 1ч ${result.activitySteps1h!.toStringAsFixed(0)}');
    }
    final factorsText = factors.isEmpty
        ? const DashboardLocalizedText('dashboardStressFactorsUnavailable')
        : DashboardLocalizedText(
            'dashboardStressFactors',
            params: {'factors': factors.join(', ')},
          );

    return DashboardModelCardUiModel(
      id: 'stress',
      titleKey: 'stress',
      state: _stateFromStatus(result.status),
      badge: DashboardLocalizedText(
        'dashboardBadgeScoreOutOf100',
        params: {'value': result.score!.toStringAsFixed(0)},
      ),
      summary: DashboardLocalizedText(_stressSummaryKey(result.score!)),
      explanation: factorsText,
      recommendation: DashboardLocalizedText(
        result.score! >= 70
            ? 'dashboardStressRecHigh'
            : result.score! >= 40
            ? 'dashboardStressRecModerate'
            : 'dashboardStressRecLow',
      ),
      progress: (result.score! / 100).clamp(0.0, 1.0),
    );
  }

  String _stressSummaryKey(double score) {
    if (score >= 70) {
      return 'dashboardStressSummaryHigh';
    }
    if (score >= 40) {
      return 'dashboardStressSummaryModerate';
    }
    return 'dashboardStressSummaryLow';
  }

  DashboardModelCardUiModel _baselineCard(DashboardBaselineModelResult result) {
    if (result.insufficientData || result.score == null) {
      return const DashboardModelCardUiModel(
        id: 'baseline',
        titleKey: 'dashboardBaselineTitle',
        state: DashboardVisualState.insufficient,
        badge: DashboardLocalizedText('dashboardBadgeInsufficient'),
        summary: DashboardLocalizedText('dashboardBaselineSummaryInsufficient'),
        explanation: DashboardLocalizedText(
          'dashboardBaselineExplainInsufficient',
        ),
        recommendation: DashboardLocalizedText(
          'dashboardBaselineRecInsufficient',
        ),
        progress: null,
      );
    }

    final mainDeviation = result.deviations.isEmpty
        ? null
        : result.deviations.first;
    final deviationLine = mainDeviation == null
        ? 'Ключевые отклонения не определены.'
        : _baselineDeviationText(mainDeviation);

    return DashboardModelCardUiModel(
      id: 'baseline',
      titleKey: 'dashboardBaselineTitle',
      state: _stateFromStatus(result.status),
      badge: DashboardLocalizedText(
        'dashboardBadgeScoreOutOf100',
        params: {'value': result.score!.toStringAsFixed(0)},
      ),
      summary: DashboardLocalizedText(
        'dashboardBaselineSummary',
        params: {'score': result.score!.toStringAsFixed(0)},
      ),
      explanation: DashboardLocalizedText(
        'dashboardBaselineExplain',
        params: {'line': deviationLine},
      ),
      recommendation: DashboardLocalizedText(
        result.score! >= 60
            ? 'dashboardBaselineRecHigh'
            : 'dashboardBaselineRecLow',
      ),
      progress: (result.score! / 100).clamp(0.0, 1.0),
    );
  }

  String _baselineDeviationText(DashboardBaselineDeviation deviation) {
    final metric = _baselineMetricLabel(deviation.metric);
    final expected = deviation.expected == null
        ? '—'
        : deviation.expected!.toStringAsFixed(1);
    final actual = deviation.actual == null
        ? '—'
        : deviation.actual!.toStringAsFixed(1);
    final delta = deviation.delta == null
        ? '—'
        : deviation.delta!.toStringAsFixed(1);
    return '$metric: expected $expected, actual $actual, Δ $delta.';
  }

  String _baselineMetricLabel(String metric) {
    return switch (metric) {
      'resting_hr' => 'Пульс покоя',
      'hrv' => 'HRV',
      'respiratory_rate' => 'Дыхание',
      'sleep_duration' => 'Длительность сна',
      'deep_sleep' => 'Глубокий сон',
      'rem_sleep' => 'REM-сон',
      'steps' => 'Шаги',
      'active_energy' => 'Активная энергия',
      'exercise_time' => 'Активные минуты',
      'blood_oxygen' => 'Кислород крови',
      'temperature' => 'Температура',
      _ => metric,
    };
  }

  DashboardModelCardUiModel _recoveryCard(DashboardRecoveryModelResult result) {
    if (result.insufficientData || result.score == null) {
      return const DashboardModelCardUiModel(
        id: 'recovery',
        titleKey: 'dashboardRecoveryTitle',
        state: DashboardVisualState.insufficient,
        badge: DashboardLocalizedText('dashboardBadgeInsufficient'),
        summary: DashboardLocalizedText('dashboardRecoverySummaryInsufficient'),
        explanation: DashboardLocalizedText(
          'dashboardRecoveryExplainInsufficient',
        ),
        recommendation: DashboardLocalizedText(
          'dashboardRecoveryRecInsufficient',
        ),
        progress: null,
      );
    }

    final reason = result.reasons.isEmpty
        ? 'Ключевые отклонения не определены.'
        : result.reasons.first.message;

    return DashboardModelCardUiModel(
      id: 'recovery',
      titleKey: 'dashboardRecoveryTitle',
      state: _stateFromStatus(result.status),
      badge: DashboardLocalizedText(
        'dashboardBadgeScoreOutOf100',
        params: {'value': result.score!.toStringAsFixed(0)},
      ),
      summary: DashboardLocalizedText(
        'dashboardRecoverySummary',
        params: {'score': result.score!.toStringAsFixed(0)},
      ),
      explanation: DashboardLocalizedText(
        'dashboardRecoveryExplain',
        params: {'reason': reason},
      ),
      recommendation: DashboardLocalizedText(
        result.score! >= 60
            ? 'dashboardRecoveryRecHigh'
            : 'dashboardRecoveryRecLow',
      ),
      progress: (result.score! / 100).clamp(0.0, 1.0),
    );
  }

  DashboardVisualState _stateFromStatus(String status) {
    return switch (status) {
      'good' => DashboardVisualState.good,
      'attention' => DashboardVisualState.attention,
      'warning' || 'poor' => DashboardVisualState.warning,
      _ => DashboardVisualState.insufficient,
    };
  }

  List<DashboardAiRecommendationUiModel> _buildAiRecommendations({
    required DashboardModelResults modelResults,
    required DashboardDataStatusState dataStatus,
  }) {
    final items = <DashboardAiRecommendationUiModel>[];

    if (dataStatus != DashboardDataStatusState.upToDate) {
      items.add(
        const DashboardAiRecommendationUiModel(
          importance: DashboardVisualState.warning,
          text: DashboardLocalizedText('dashboardAiSyncText'),
          reason: DashboardLocalizedText('dashboardAiSyncReason'),
        ),
      );
    }

    if (modelResults.sleep.score != null && modelResults.sleep.score! < 70) {
      items.add(
        const DashboardAiRecommendationUiModel(
          importance: DashboardVisualState.attention,
          text: DashboardLocalizedText('dashboardAiSleepText'),
          reason: DashboardLocalizedText('dashboardAiSleepReason'),
        ),
      );
    }

    if (modelResults.stress.score != null && modelResults.stress.score! >= 40) {
      items.add(
        const DashboardAiRecommendationUiModel(
          importance: DashboardVisualState.attention,
          text: DashboardLocalizedText('dashboardAiStressText'),
          reason: DashboardLocalizedText('dashboardAiStressReason'),
        ),
      );
    }

    final activityClass = modelResults.activity.activityClass;
    if (activityClass == 'sitting' || activityClass == 'lying') {
      items.add(
        const DashboardAiRecommendationUiModel(
          importance: DashboardVisualState.good,
          text: DashboardLocalizedText('dashboardAiActivityText'),
          reason: DashboardLocalizedText('dashboardAiActivityReason'),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const DashboardAiRecommendationUiModel(
          importance: DashboardVisualState.good,
          text: DashboardLocalizedText('dashboardAiStableText'),
          reason: DashboardLocalizedText('dashboardAiStableReason'),
        ),
      );
    }

    return items.take(3).toList(growable: false);
  }

  List<DashboardKeyMetricUiModel> _mapKeyMetrics(
    List<DashboardMetric> metrics,
  ) {
    return metrics
        .map(
          (metric) => DashboardKeyMetricUiModel(
            id: metric.id,
            labelKey: metric.labelKey,
            value: metric.value,
            unit: metric.unit,
            hasData: metric.value != '—',
          ),
        )
        .toList(growable: false);
  }

  List<DashboardMetricUiModel> _mapMetrics(List<DashboardMetric> metrics) {
    return metrics
        .map(
          (metric) => DashboardMetricUiModel(
            id: metric.id,
            icon: _mapIcon(metric.id),
            labelKey: metric.labelKey,
            value: metric.value,
            unit: metric.unit,
            trend: _mapTrend(metric.trend),
            data: metric.data,
          ),
        )
        .toList(growable: false);
  }

  ChartTrend _mapTrend(String trend) {
    return switch (trend) {
      'up' => ChartTrend.up,
      'down' => ChartTrend.down,
      _ => ChartTrend.stable,
    };
  }

  IconData _mapIcon(String id) {
    return switch (id) {
      'heart' => LucideIcons.heart,
      'sleep' => LucideIcons.moon,
      'steps' => LucideIcons.footprints,
      'hrv' => LucideIcons.activity,
      'active_minutes' => LucideIcons.timer,
      'stress_today' => LucideIcons.zap,
      'recovery_today' => LucideIcons.heart,
      _ => LucideIcons.activity,
    };
  }

  DashboardScoreState _mapScoreState({
    required String status,
    required int healthScore,
    required bool noData,
  }) {
    if (noData) {
      return DashboardScoreState.noAccess;
    }
    return switch (status) {
      'no_access' => DashboardScoreState.noAccess,
      'calculating' => DashboardScoreState.calculating,
      'risk' => DashboardScoreState.risk,
      'attention' => DashboardScoreState.attention,
      'stable' => DashboardScoreState.stable,
      _ =>
        healthScore >= 80
            ? DashboardScoreState.stable
            : healthScore >= 60
            ? DashboardScoreState.attention
            : DashboardScoreState.risk,
    };
  }

  String _scoreStateLabel(DashboardScoreState state) {
    return switch (state) {
      DashboardScoreState.noAccess => 'noAccess',
      DashboardScoreState.calculating => 'calculating',
      DashboardScoreState.risk => 'riskDetected',
      DashboardScoreState.attention => 'attentionNeeded',
      DashboardScoreState.stable => 'stable',
    };
  }

  List<String> _recommendationsFor(DashboardScoreState state) {
    return switch (state) {
      DashboardScoreState.noAccess => [
        'recNoAccess1',
        'recNoAccess2',
        'recNoAccess3',
      ],
      DashboardScoreState.calculating => [
        'recCalculating1',
        'recCalculating2',
        'recCalculating3',
      ],
      DashboardScoreState.risk => ['recRisk1', 'recRisk2', 'recRisk3'],
      DashboardScoreState.attention => [
        'recAttention1',
        'recAttention2',
        'recAttention3',
      ],
      DashboardScoreState.stable => ['recStable1', 'recStable2', 'recStable3'],
    };
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message.isEmpty
        ? 'Не удалось обновить анализ'
        : failure.message;
  }
}
