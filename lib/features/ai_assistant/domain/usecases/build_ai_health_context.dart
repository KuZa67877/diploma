import 'dart:math' as math;

import 'package:dartz/dartz.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../dashboard/domain/entities/dashboard_summary.dart';
import '../../../dashboard/domain/usecases/get_dashboard_summary.dart';
import '../../../export/data/services/historical_model_output_service.dart';
import '../../../export/domain/entities/export_data_range.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/usecases/get_health_metrics.dart';
import '../../../wellbeing/domain/entities/wellbeing_entry.dart';
import '../../../wellbeing/domain/usecases/get_wellbeing_entries.dart';
import '../entities/ai_date_range_selection.dart';
import '../entities/ai_economy_options.dart';
import '../entities/ai_health_context.dart';
import '../entities/ai_health_data_type.dart';

class BuildAiHealthContextParams {
  final AiDateRangeSelection range;
  final Set<AiHealthDataType> selectedDataTypes;
  final AiEconomyOptions economyOptions;

  const BuildAiHealthContextParams({
    required this.range,
    required this.selectedDataTypes,
    required this.economyOptions,
  });
}

class BuildAiHealthContextUseCase
    implements UseCase<AiHealthContext, BuildAiHealthContextParams> {
  final GetHealthMetrics _getHealthMetrics;
  final GetWellbeingEntries _getWellbeingEntries;
  final GetDashboardSummary _getDashboardSummary;
  final HistoricalModelOutputService _historicalModelOutputService;

  const BuildAiHealthContextUseCase({
    required GetHealthMetrics getHealthMetrics,
    required GetWellbeingEntries getWellbeingEntries,
    required GetDashboardSummary getDashboardSummary,
    required HistoricalModelOutputService historicalModelOutputService,
  }) : _getHealthMetrics = getHealthMetrics,
       _getWellbeingEntries = getWellbeingEntries,
       _getDashboardSummary = getDashboardSummary,
       _historicalModelOutputService = historicalModelOutputService;

  @override
  Future<Either<Failure, AiHealthContext>> call(
    BuildAiHealthContextParams params,
  ) async {
    final warnings = <String>[];
    final missingData = <String>[];

    final metricTypes = params.selectedDataTypes
        .expand((item) => item.metricTypes)
        .toSet()
        .toList(growable: false);

    List<HealthMetricSample> metrics = const <HealthMetricSample>[];
    if (metricTypes.isNotEmpty) {
      final metricsResult = await _getHealthMetrics(
        HealthMetricsQuery(
          range: params.range.toHealthDateRange(),
          types: metricTypes,
        ),
      );
      metrics = metricsResult.fold(
        (_) => const <HealthMetricSample>[],
        (value) => value,
      );
      if (metrics.isEmpty) {
        warnings.add('За выбранный период мало подключенных health-данных.');
      }
    }

    final wellbeingResult = await _getWellbeingEntries(const NoParams());
    final wellbeingEntries = wellbeingResult.fold(
      (_) => const <WellbeingEntry>[],
      (items) => items
          .where((item) => params.range.toHealthDateRange().contains(item.date))
          .toList(growable: false),
    );

    DashboardSummary? dashboardSummary;
    final needsDashboard = params.selectedDataTypes.contains(
          AiHealthDataType.healthScore,
        ) ||
        params.selectedDataTypes.contains(AiHealthDataType.stress) ||
        params.selectedDataTypes.contains(AiHealthDataType.baseline) ||
        params.selectedDataTypes.contains(AiHealthDataType.anomalies);
    if (needsDashboard) {
      final dashboardResult = await _getDashboardSummary(const NoParams());
      dashboardSummary = dashboardResult.fold((_) => null, (value) => value);
      if (dashboardSummary == null) {
        warnings.add(
          'Не удалось получить свежую dashboard-сводку. Часть выводов будет менее точной.',
        );
      }
    }

    ExportModelOutputSnapshot modelOutputs = ExportModelOutputSnapshot.empty;
    try {
      modelOutputs = await _historicalModelOutputService.loadForRange(
        _toExportRange(params.range),
      );
    } catch (_) {
      warnings.add('История model outputs недоступна, используются только локальные данные.');
    }

    final summaries = <String, dynamic>{};
    final selectedTypes = params.selectedDataTypes.isEmpty
        ? <AiHealthDataType>{
            AiHealthDataType.healthScore,
            AiHealthDataType.sleep,
            AiHealthDataType.stress,
            AiHealthDataType.diary,
          }
        : params.selectedDataTypes;

    for (final type in selectedTypes) {
      final summary = _buildSummaryForType(
        type: type,
        metrics: metrics,
        wellbeingEntries: wellbeingEntries,
        dashboardSummary: dashboardSummary,
        modelOutputs: modelOutputs,
        economyOptions: params.economyOptions,
        warnings: warnings,
      );
      if (summary == null || summary.trim().isEmpty) {
        missingData.add(type.displayText);
        continue;
      }
      summaries[type.name] = summary;
    }

    final healthScore = dashboardSummary?.healthScore.toDouble() ??
        modelOutputs.latestByModel['healthscore_v1']?.score;
    _appendWarningsFromScores(
      warnings: warnings,
      healthScore: healthScore,
      stressScore: modelOutputs.latestByModel['stress_score_v1']?.score,
      anomalyScore:
          modelOutputs.latestByModel['personal_physiology_anomaly_v1']?.score,
      baselineScore: modelOutputs.latestByModel['baseline_forecast_v1']?.score,
    );

    if (summaries.isEmpty) {
      warnings.add(
        'Недостаточно данных для уверенного анализа. Можно отправить запрос, но ответ будет менее точным.',
      );
    }

    return Right(
      AiHealthContext(
        from: params.range.start,
        to: params.range.end,
        healthScore: healthScore,
        summaries: summaries,
        warnings: warnings.toSet().toList(growable: false),
        missingData: missingData.toSet().toList(growable: false),
      ),
    );
  }

  ExportDataRange _toExportRange(AiDateRangeSelection range) {
    final preset = range.preset;
    switch (preset) {
      case AiDateRangePreset.today:
        return ExportDataRange.today(now: range.end);
      case AiDateRangePreset.last3Days:
        return ExportDataRange.custom(start: range.start, end: range.end);
      case AiDateRangePreset.last7Days:
        return ExportDataRange.last7Days(now: range.end);
      case AiDateRangePreset.last14Days:
        return ExportDataRange.custom(start: range.start, end: range.end);
      case AiDateRangePreset.custom:
        return ExportDataRange.custom(start: range.start, end: range.end);
    }
  }

  String? _buildSummaryForType({
    required AiHealthDataType type,
    required List<HealthMetricSample> metrics,
    required List<WellbeingEntry> wellbeingEntries,
    required DashboardSummary? dashboardSummary,
    required ExportModelOutputSnapshot modelOutputs,
    required AiEconomyOptions economyOptions,
    required List<String> warnings,
  }) {
    return switch (type) {
      AiHealthDataType.healthScore => _buildHealthScoreSummary(
        dashboardSummary,
        modelOutputs,
      ),
      AiHealthDataType.sleep => _buildSleepSummary(
        metrics,
        modelOutputs,
        economyOptions,
      ),
      AiHealthDataType.pulse => _buildPulseSummary(metrics, economyOptions),
      AiHealthDataType.hrv => _buildHrvSummary(metrics),
      AiHealthDataType.spo2 => _buildSpo2Summary(metrics),
      AiHealthDataType.steps => _buildDailyTotalSummary(
        title: 'Шаги',
        samples: metrics.where((item) => item.type == HealthMetricType.steps),
        unit: 'шагов',
        economyOptions: economyOptions,
      ),
      AiHealthDataType.activeEnergy => _buildDailyTotalSummary(
        title: 'Активная энергия',
        samples: metrics.where(
          (item) =>
              item.type == HealthMetricType.activeEnergyBurned ||
              item.type == HealthMetricType.totalCaloriesBurned,
        ),
        unit: 'ккал',
        economyOptions: economyOptions,
      ),
      AiHealthDataType.distance => _buildDailyTotalSummary(
        title: 'Дистанция',
        samples: metrics.where(
          (item) =>
              item.type == HealthMetricType.distanceWalkingRunning ||
              item.type == HealthMetricType.distanceCycling ||
              item.type == HealthMetricType.distanceSwimming,
        ),
        unit: 'м',
        economyOptions: economyOptions,
      ),
      AiHealthDataType.workouts => _buildWorkoutSummary(metrics, economyOptions),
      AiHealthDataType.stress => _buildStressSummary(
        modelOutputs,
        dashboardSummary,
        wellbeingEntries,
      ),
      AiHealthDataType.anomalies => _buildAnomalySummary(modelOutputs),
      AiHealthDataType.baseline => _buildBaselineSummary(modelOutputs),
      AiHealthDataType.diary => _buildDiarySummary(wellbeingEntries),
      AiHealthDataType.comments => _buildCommentsSummary(
        wellbeingEntries,
        economyOptions,
        warnings,
      ),
    };
  }

  String? _buildHealthScoreSummary(
    DashboardSummary? dashboardSummary,
    ExportModelOutputSnapshot modelOutputs,
  ) {
    final modelRecord = modelOutputs.latestByModel['healthscore_v1'];
    final score = dashboardSummary?.healthScore ?? modelRecord?.score?.round();
    if (score == null) {
      return null;
    }

    final drivers = dashboardSummary?.modelResults.healthDrivers
            .take(3)
            .map(
              (driver) =>
                  '${driver.id}: ${driver.contribution.toStringAsFixed(1)}',
            )
            .join(', ') ??
        _reasonMessages(modelRecord?.features['drivers']).take(3).join(', ');
    final confidence = dashboardSummary?.modelResults.healthScoreConfidence;
    return [
      'Текущий HealthScore: $score/100.',
      if (dashboardSummary?.objectiveHealthScore != null)
        'Объективная оценка без дневника: ${dashboardSummary!.objectiveHealthScore}/100.',
      if (confidence != null)
        'Уверенность расчёта: ${(confidence * 100).round()}%.',
      if (drivers.isNotEmpty) 'Основные драйверы: $drivers.',
    ].join(' ');
  }

  String? _buildSleepSummary(
    List<HealthMetricSample> metrics,
    ExportModelOutputSnapshot modelOutputs,
    AiEconomyOptions economyOptions,
  ) {
    final sleepSamples = metrics
        .where((item) => item.type.name.startsWith('sleep'))
        .toList(growable: false);
    if (sleepSamples.isEmpty) {
      return null;
    }

    final byDay = <String, double>{};
    for (final sample in sleepSamples) {
      final key = _dayKey(sample.startAt);
      byDay.update(
        key,
        (value) => value + _sleepMinutes(sample),
        ifAbsent: () => _sleepMinutes(sample),
      );
    }
    final values = byDay.values.where((item) => item > 0).toList(growable: false);
    if (values.isEmpty) {
      return null;
    }

    final average = values.reduce((a, b) => a + b) / values.length;
    final latestScore = modelOutputs.latestByModel['sleep_quality']?.score;
    final lowSleepDays = values.where((item) => item < 420).length;

    final parts = <String>[
      'Средняя длительность сна: ${_minutesToHours(average)}.',
      'Минимум: ${_minutesToHours(values.reduce(math.min))}, максимум: ${_minutesToHours(values.reduce(math.max))}.',
      'Дней с недосыпом (<7 ч): $lowSleepDays из ${values.length}.',
      if (latestScore != null)
        'Последняя AI-оценка сна: ${latestScore.round()}/100.',
      _trendSentence(values, 'длительности сна'),
    ];

    if (!economyOptions.sendAggregatesOnly && !economyOptions.economizeTokens) {
      parts.add('По дням: ${_dailyBreakdown(byDay, formatter: _minutesToHours)}.');
    }

    return parts.join(' ');
  }

  String? _buildPulseSummary(
    List<HealthMetricSample> metrics,
    AiEconomyOptions economyOptions,
  ) {
    final pulse = metrics
        .where((item) => item.type == HealthMetricType.heartRate)
        .toList(growable: false);
    final resting = metrics
        .where((item) => item.type == HealthMetricType.restingHeartRate)
        .toList(growable: false);
    if (pulse.isEmpty && resting.isEmpty) {
      return null;
    }

    final values = pulse.map((item) => item.value).toList(growable: false);
    final restingValues = resting
        .map((item) => item.value)
        .toList(growable: false);
    final parts = <String>[
      if (values.isNotEmpty)
        'Пульс: средний ${_avg(values).round()} bpm, минимум ${values.reduce(math.min).round()} bpm, максимум ${values.reduce(math.max).round()} bpm.',
      if (restingValues.isNotEmpty)
        'Пульс в покое: средний ${_avg(restingValues).round()} bpm.',
    ];

    if (!economyOptions.sendAggregatesOnly && !economyOptions.economizeTokens) {
      final latest = pulse.take(8).map((item) {
        return '${_dateTime(item.timestamp)} ${item.value.round()} bpm';
      }).join('; ');
      if (latest.isNotEmpty) {
        parts.add('Последние измерения: $latest.');
      }
    }
    return parts.join(' ');
  }

  String? _buildHrvSummary(List<HealthMetricSample> metrics) {
    final sdnn = metrics
        .where((item) => item.type == HealthMetricType.heartRateVariabilitySdnn)
        .map((item) => item.value)
        .toList(growable: false);
    final rmssd = metrics
        .where((item) => item.type == HealthMetricType.heartRateVariabilityRmssd)
        .map((item) => item.value)
        .toList(growable: false);
    if (sdnn.isEmpty && rmssd.isEmpty) {
      return null;
    }
    return [
      if (rmssd.isNotEmpty) 'RMSSD: среднее ${_avg(rmssd).toStringAsFixed(1)} мс.',
      if (sdnn.isNotEmpty) 'SDNN: среднее ${_avg(sdnn).toStringAsFixed(1)} мс.',
      if (rmssd.length >= 2) _trendSentence(rmssd, 'RMSSD'),
      if (sdnn.length >= 2) _trendSentence(sdnn, 'SDNN'),
    ].join(' ');
  }

  String? _buildSpo2Summary(List<HealthMetricSample> metrics) {
    final spo2 = metrics
        .where((item) => item.type == HealthMetricType.bloodOxygen)
        .map((item) => item.value)
        .toList(growable: false);
    if (spo2.isEmpty) {
      return null;
    }
    return 'SpO2: среднее ${_avg(spo2).toStringAsFixed(1)}%, минимум ${spo2.reduce(math.min).toStringAsFixed(1)}%, максимум ${spo2.reduce(math.max).toStringAsFixed(1)}%.';
  }

  String? _buildDailyTotalSummary({
    required String title,
    required Iterable<HealthMetricSample> samples,
    required String unit,
    required AiEconomyOptions economyOptions,
  }) {
    final byDay = <String, double>{};
    for (final sample in samples) {
      final key = _dayKey(sample.startAt);
      byDay.update(key, (value) => value + sample.value, ifAbsent: () => sample.value);
    }
    final values = byDay.values.toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    final parts = <String>[
      '$title: среднее ${_avg(values).round()} $unit в день.',
      'Минимум ${values.reduce(math.min).round()} $unit, максимум ${values.reduce(math.max).round()} $unit.',
      _trendSentence(values, title.toLowerCase()),
    ];
    if (!economyOptions.sendAggregatesOnly && !economyOptions.economizeTokens) {
      parts.add('По дням: ${_dailyBreakdown(byDay, formatter: (value) => value.round().toString())}.');
    }
    return parts.join(' ');
  }

  String? _buildWorkoutSummary(
    List<HealthMetricSample> metrics,
    AiEconomyOptions economyOptions,
  ) {
    final workouts = metrics
        .where((item) => item.type == HealthMetricType.workout)
        .toList(growable: false);
    final exerciseTime = metrics
        .where((item) => item.type == HealthMetricType.exerciseTime)
        .map((item) => item.value)
        .toList(growable: false);
    if (workouts.isEmpty && exerciseTime.isEmpty) {
      return null;
    }
    final parts = <String>[
      if (workouts.isNotEmpty)
        'Количество тренировочных записей: ${workouts.length}.',
      if (exerciseTime.isNotEmpty)
        'Суммарное время активности: ${exerciseTime.fold<double>(0, (sum, item) => sum + item).round()} мин.',
    ];
    if (!economyOptions.sendAggregatesOnly && !economyOptions.economizeTokens) {
      final latest = workouts.take(5).map((item) => _dateTime(item.timestamp)).join(', ');
      if (latest.isNotEmpty) {
        parts.add('Последние тренировки: $latest.');
      }
    }
    return parts.join(' ');
  }

  String? _buildStressSummary(
    ExportModelOutputSnapshot modelOutputs,
    DashboardSummary? dashboardSummary,
    List<WellbeingEntry> wellbeingEntries,
  ) {
    final stress = modelOutputs.latestByModel['stress_score_v1'];
    final diaryHighStress = wellbeingEntries
        .where((item) => (item.stressNow ?? 0) >= 4)
        .length;
    if (stress == null && diaryHighStress == 0 && dashboardSummary == null) {
      return null;
    }

    final reasonMessages = _reasonMessages(stress?.reasonCodes);
    return [
      if (stress?.score != null)
        'Последняя модельная оценка стресса: ${stress!.score!.round()}/100.',
      if (stress != null)
        'Уверенность модели: ${(stress.confidence * 100).round()}%, статус: ${stress.status}.',
      if (dashboardSummary?.modelResults.stress.reason case final reason?)
        'Причина из dashboard: $reason.',
      if (reasonMessages.isNotEmpty)
        'Основные факторы: ${reasonMessages.take(3).join(', ')}.',
      if (diaryHighStress > 0)
        'По дневнику высокий стресс отмечался $diaryHighStress раз.',
    ].join(' ');
  }

  String? _buildAnomalySummary(ExportModelOutputSnapshot modelOutputs) {
    final anomaly = modelOutputs.latestByModel['personal_physiology_anomaly_v1'];
    if (anomaly == null) {
      return null;
    }
    final reasonMessages = _reasonMessages(anomaly.reasonCodes);
    return [
      if (anomaly.score != null)
        'Индекс физиологических аномалий: ${anomaly.score!.round()}/100.',
      'Статус: ${anomaly.status}, уверенность ${(anomaly.confidence * 100).round()}%.',
      if (reasonMessages.isNotEmpty)
        'Подозрительные сигналы: ${reasonMessages.take(4).join(', ')}.',
    ].join(' ');
  }

  String? _buildBaselineSummary(ExportModelOutputSnapshot modelOutputs) {
    final baseline = modelOutputs.latestByModel['baseline_forecast_v1'];
    if (baseline == null) {
      return null;
    }
    final reasons = _reasonMessages(baseline.reasonCodes);
    return [
      if (baseline.score != null)
        'Отклонение от базовой линии: ${baseline.score!.round()}/100.',
      'Статус: ${baseline.status}, уверенность ${(baseline.confidence * 100).round()}%.',
      if (reasons.isNotEmpty) 'Основные причины: ${reasons.take(4).join(', ')}.',
    ].join(' ');
  }

  String? _buildDiarySummary(List<WellbeingEntry> wellbeingEntries) {
    if (wellbeingEntries.isEmpty) {
      return null;
    }

    final tagCounts = <String, int>{};
    var stressCount = 0;
    var fatigueCount = 0;
    var lowWellnessCount = 0;
    final moods = <String, int>{};

    for (final entry in wellbeingEntries) {
      moods.update(entry.mood.name, (value) => value + 1, ifAbsent: () => 1);
      if ((entry.stressNow ?? 0) >= 4) {
        stressCount += 1;
      }
      if ((entry.fatigue ?? 0) >= 4) {
        fatigueCount += 1;
      }
      if ((entry.wellness ?? 5) <= 2) {
        lowWellnessCount += 1;
      }
      for (final tag in entry.tags) {
        final normalized = tag.trim();
        if (normalized.isEmpty) {
          continue;
        }
        tagCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final topTags = tagCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final moodSummary = moods.entries.map((item) => '${item.key}: ${item.value}').join(', ');

    return [
      'Дневниковых записей: ${wellbeingEntries.length}.',
      'Настроения: $moodSummary.',
      'Высокий стресс: $stressCount дн., высокая усталость: $fatigueCount дн., низкое самочувствие: $lowWellnessCount дн.',
      if (topTags.isNotEmpty)
        'Частые теги: ${topTags.take(5).map((item) => item.key).join(', ')}.',
    ].join(' ');
  }

  String? _buildCommentsSummary(
    List<WellbeingEntry> wellbeingEntries,
    AiEconomyOptions economyOptions,
    List<String> warnings,
  ) {
    if (economyOptions.excludeDiaryNotes) {
      warnings.add('Свободные заметки дневника исключены по настройке приватности.');
      return null;
    }

    final notes = wellbeingEntries
        .where((item) => (item.note ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (notes.isEmpty) {
      return null;
    }

    final limited = economyOptions.economizeTokens ? notes.take(3) : notes.take(5);
    final rendered = limited.map((item) {
      var note = item.note!.trim();
      if (economyOptions.economizeTokens && note.length > 200) {
        note = '${note.substring(0, 200)}...';
      }
      return '${_date(item.date)}: "$note"';
    }).join(' | ');
    return 'Последние комментарии пользователя: $rendered';
  }

  void _appendWarningsFromScores({
    required List<String> warnings,
    required double? healthScore,
    required double? stressScore,
    required double? anomalyScore,
    required double? baselineScore,
  }) {
    if (healthScore != null && healthScore <= 50) {
      warnings.add('HealthScore низкий, интерпретация требует осторожности.');
    }
    if (stressScore != null && stressScore >= 70) {
      warnings.add('Модельный уровень стресса повышен.');
    }
    if (anomalyScore != null && anomalyScore >= 60) {
      warnings.add('Есть повышенный индекс физиологических аномалий.');
    }
    if (baselineScore != null && baselineScore >= 60) {
      warnings.add('Наблюдается выраженное отклонение от базовой линии пользователя.');
    }
  }

  String _trendSentence(List<double> values, String subject) {
    if (values.length < 2) {
      return 'Тренд по $subject пока неясен.';
    }
    final first = values.first;
    final last = values.last;
    if (first == 0) {
      return 'Тренд по $subject пока неясен.';
    }
    final delta = ((last - first) / first) * 100;
    final direction = delta >= 0 ? 'рост' : 'снижение';
    return 'Тренд по $subject: $direction на ${delta.abs().round()}%.';
  }

  String _dailyBreakdown(
    Map<String, double> values, {
    required String Function(double value) formatter,
  }) {
    final entries = values.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .take(7)
        .map((entry) => '${entry.key}: ${formatter(entry.value)}')
        .join('; ');
  }

  String _minutesToHours(double minutes) {
    final hours = minutes / 60.0;
    return '${hours.toStringAsFixed(1)} ч';
  }

  double _sleepMinutes(HealthMetricSample sample) {
    return sample.intervalMinutes ?? sample.value;
  }

  double _avg(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _dayKey(DateTime value) => DateFormat('dd.MM').format(value.toLocal());

  String _date(DateTime value) => DateFormat('dd.MM.yyyy').format(value.toLocal());

  String _dateTime(DateTime value) =>
      DateFormat('dd.MM HH:mm').format(value.toLocal());

  List<String> _reasonMessages(Object? raw) {
    if (raw is! Iterable) {
      return const <String>[];
    }
    return raw
        .map((item) {
          if (item is Map<String, dynamic>) {
            final message = item['message']?.toString();
            if (message != null && message.trim().isNotEmpty) {
              return message.trim();
            }
            final code = item['code']?.toString();
            if (code != null && code.trim().isNotEmpty) {
              return code.trim();
            }
          }
          return item.toString();
        })
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
}
