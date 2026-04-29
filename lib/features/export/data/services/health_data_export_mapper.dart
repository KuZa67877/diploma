import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../../dashboard/domain/entities/dashboard_summary.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metric_type.dart';
import '../../../profile/domain/entities/profile_data.dart';
import '../../domain/entities/export_data_range.dart';
import '../../domain/entities/export_data_type.dart';
import '../../domain/entities/export_payload.dart';

class HealthDataExportMapper {
  const HealthDataExportMapper();

  ExportPayload map({
    required ExportDataRange range,
    required Set<ExportDataType> selectedTypes,
    required bool includePersonalData,
    required List<HealthMetricSample> metrics,
    Map<String, HealthModelOutputRecord> latestModelOutputs =
        const <String, HealthModelOutputRecord>{},
    List<HealthModelOutputRecord> modelOutputHistory =
        const <HealthModelOutputRecord>[],
    DashboardSummary? dashboardSummary,
    ProfileData? profileData,
  }) {
    final includesAll = selectedTypes.contains(ExportDataType.everything);
    final wantsAnomalies =
        includesAll || selectedTypes.contains(ExportDataType.anomaliesOnly);
    final wantsRaw =
        includesAll || selectedTypes.contains(ExportDataType.rawMetrics);

    final sections = <ExportSection>[];
    final missingSections = <String>[];
    final recommendations = _resolveRecommendations(
      latestRecommendationOutput:
          latestModelOutputs['harvard_activity_recommendation_v1'],
      summary: dashboardSummary,
    );
    final observations = _buildObservations(
      metrics: metrics,
      modelOutputHistory: modelOutputHistory,
      includeDerived:
          includesAll ||
          selectedTypes.contains(ExportDataType.modelResults) ||
          selectedTypes.contains(ExportDataType.stress) ||
          selectedTypes.contains(ExportDataType.recovery) ||
          wantsAnomalies,
    );

    void addSection(ExportSection section, {required bool requested}) {
      if (!requested) {
        return;
      }
      if (!section.hasData) {
        missingSections.add(section.title);
        return;
      }
      sections.add(section);
    }

    addSection(
      _buildPulseSection(metrics),
      requested: includesAll || selectedTypes.contains(ExportDataType.pulse),
    );
    addSection(
      _buildHrvSection(metrics),
      requested: includesAll || selectedTypes.contains(ExportDataType.hrv),
    );
    addSection(
      _buildSleepSection(metrics),
      requested: includesAll || selectedTypes.contains(ExportDataType.sleep),
    );
    addSection(
      _buildActivitySection(metrics),
      requested: includesAll || selectedTypes.contains(ExportDataType.activity),
    );
    addSection(
      _buildStressSection(latestModelOutputs['stress_score_v1']),
      requested: includesAll || selectedTypes.contains(ExportDataType.stress),
    );
    addSection(
      _buildRecoverySection(
        latestModelOutputs['personal_physiology_anomaly_v1'],
      ),
      requested: includesAll || selectedTypes.contains(ExportDataType.recovery),
    );
    addSection(
      _buildModelResultsSection(latestModelOutputs),
      requested:
          includesAll || selectedTypes.contains(ExportDataType.modelResults),
    );
    addSection(
      _buildRecommendationsSection(recommendations),
      requested:
          includesAll || selectedTypes.contains(ExportDataType.recommendations),
    );
    addSection(_buildRawMetricsSection(metrics), requested: wantsRaw);
    addSection(
      _buildAnomaliesSection(latestModelOutputs),
      requested: wantsAnomalies,
    );

    final hasSectionData = sections.any((section) => section.hasData);
    final hasRecommendations = recommendations.isNotEmpty;
    final hasObservations = observations.isNotEmpty;

    return ExportPayload(
      range: range,
      personalData: includePersonalData
          ? _buildPersonalData(profileData)
          : const <String, String>{},
      sections: sections,
      observations: observations,
      recommendations: recommendations,
      warnings: const <String>[
        'Вы копируете медицинские данные. Вставляйте их только в сервисы, которым доверяете.',
        'Экспорт сформирован автоматически и не является медицинским заключением.',
      ],
      missingSections: missingSections,
      sourceCount: metrics.map((sample) => sample.sourceId).toSet().length,
      recordCount: metrics.length,
      hasAnyData: hasSectionData || hasRecommendations || hasObservations,
      isPartialData: missingSections.isNotEmpty,
    );
  }

  ExportSection _buildPulseSection(List<HealthMetricSample> metrics) {
    final heart = metrics
        .where((sample) => sample.type == HealthMetricType.heartRate)
        .toList(growable: false);
    final resting = metrics
        .where((sample) => sample.type == HealthMetricType.restingHeartRate)
        .toList(growable: false);

    return ExportSection(
      id: 'pulse',
      title: 'Пульс',
      fields: [
        _numericField(
          'avg_heart_rate',
          'Средний',
          _average(heart),
          unit: 'bpm',
        ),
        _numericField(
          'min_heart_rate',
          'Минимальный',
          _minValue(heart),
          unit: 'bpm',
        ),
        _numericField(
          'max_heart_rate',
          'Максимальный',
          _maxValue(heart),
          unit: 'bpm',
        ),
        _numericField(
          'resting_heart_rate',
          'Пульс в покое',
          _average(resting),
          unit: 'bpm',
        ),
      ],
    );
  }

  ExportSection _buildHrvSection(List<HealthMetricSample> metrics) {
    final rmssd = metrics
        .where(
          (sample) => sample.type == HealthMetricType.heartRateVariabilityRmssd,
        )
        .toList(growable: false);
    final sdnn = metrics
        .where(
          (sample) => sample.type == HealthMetricType.heartRateVariabilitySdnn,
        )
        .toList(growable: false);

    return ExportSection(
      id: 'hrv',
      title: 'HRV',
      fields: [
        _numericField(
          'rmssd_avg',
          'RMSSD, среднее',
          _average(rmssd),
          unit: 'ms',
        ),
        _numericField('sdnn_avg', 'SDNN, среднее', _average(sdnn), unit: 'ms'),
        ExportField(
          code: 'hrv_trend',
          label: 'Тренд',
          displayValue: _trendDescription(
            _latestTwoValues([...rmssd, ...sdnn]),
          ),
        ),
      ],
    );
  }

  ExportSection _buildSleepSection(List<HealthMetricSample> metrics) {
    final sleepSamples = _preferredSleepSamples(metrics);
    final grouped = <String, double>{};
    for (final sample in sleepSamples) {
      final key = DateFormat('yyyy-MM-dd').format(sample.startAt.toLocal());
      grouped.update(
        key,
        (value) => value + _sleepMinutes(sample),
        ifAbsent: () => _sleepMinutes(sample),
      );
    }
    final dailyMinutes = grouped.values.toList(growable: false);
    final avgMinutes = dailyMinutes.isEmpty
        ? null
        : dailyMinutes.reduce((a, b) => a + b) / dailyMinutes.length;
    final insufficientDays = dailyMinutes
        .where((minutes) => minutes > 0 && minutes < 420)
        .length;

    return ExportSection(
      id: 'sleep',
      title: 'Сон',
      fields: [
        _durationField('sleep_avg', 'Средняя длительность', avgMinutes),
        ExportField(
          code: 'sleep_quality',
          label: 'Качество сна',
          displayValue: _sleepQualityLabel(avgMinutes),
        ),
        ExportField(
          code: 'sleep_low_days',
          label: 'Частота недостаточного сна',
          displayValue: dailyMinutes.isEmpty
              ? null
              : '$insufficientDays из ${dailyMinutes.length} дней',
        ),
      ],
    );
  }

  ExportSection _buildActivitySection(List<HealthMetricSample> metrics) {
    final steps = metrics
        .where((sample) => sample.type == HealthMetricType.steps)
        .toList(growable: false);
    final activeMinutes = metrics
        .where((sample) => sample.type == HealthMetricType.exerciseTime)
        .toList(growable: false);
    final calories = metrics
        .where((sample) => sample.type == HealthMetricType.activeEnergyBurned)
        .toList(growable: false);

    return ExportSection(
      id: 'activity',
      title: 'Активность',
      fields: [
        _numericField('steps_total', 'Шаги', _sum(steps), unit: 'count'),
        _numericField(
          'active_minutes_total',
          'Активные минуты',
          _sum(activeMinutes, transform: _exerciseMinutes),
          unit: 'min',
        ),
        _numericField(
          'active_energy',
          'Активная энергия',
          _sum(calories),
          unit: 'kcal',
        ),
      ],
    );
  }

  ExportSection _buildStressSection(HealthModelOutputRecord? stress) {
    return ExportSection(
      id: 'stress',
      title: 'Стресс',
      fields: [
        _numericField(
          'stress_score',
          'Уровень стресса',
          stress?.score,
          unit: '/100',
          source: 'ML model',
          status: stress?.status,
        ),
        _numericField(
          'stress_hr',
          'Пульс в модели',
          _featureDouble(stress?.features, 'hr_mean'),
          unit: 'bpm',
          source: 'ML model',
        ),
        _numericField(
          'stress_hrv_sdnn',
          'HRV SDNN',
          _featureDouble(stress?.features, 'hrv_sdnn_latest'),
          unit: 'ms',
          source: 'ML model',
        ),
        _numericField(
          'stress_hrv_rmssd',
          'HRV RMSSD',
          _featureDouble(stress?.features, 'hrv_rmssd_latest'),
          unit: 'ms',
          source: 'ML model',
        ),
      ],
      note: stress == null
          ? 'Нет сохранённых модельных оценок стресса в выбранном периоде.'
          : 'Показана последняя сохранённая оценка внутри выбранного периода.',
    );
  }

  ExportSection _buildRecoverySection(HealthModelOutputRecord? recovery) {
    return ExportSection(
      id: 'recovery',
      title: 'Восстановление',
      fields: [
        _numericField(
          'recovery_score',
          'Индекс восстановления',
          recovery?.score,
          unit: '/100',
          source: 'ML model',
          status: recovery?.status,
        ),
        ExportField(
          code: 'recovery_groups',
          label: 'Группы факторов',
          displayValue: _groupScoresSummary(recovery),
          source: 'ML model',
          isDerived: true,
        ),
      ],
      note: recovery == null
          ? 'Нет сохранённых оценок восстановления в выбранном периоде.'
          : 'Показана последняя сохранённая оценка внутри выбранного периода.',
    );
  }

  ExportSection _buildModelResultsSection(
    Map<String, HealthModelOutputRecord> latestModelOutputs,
  ) {
    final healthScore = latestModelOutputs['healthscore_v1'];
    final activity = latestModelOutputs['harvard_activity_recommendation_v1'];
    final sleep = latestModelOutputs['sleep_quality'];
    final stress = latestModelOutputs['stress_score_v1'];
    final baseline = latestModelOutputs['baseline_forecast_v1'];

    return ExportSection(
      id: 'models',
      title: 'Результаты моделей',
      fields: [
        _numericField(
          'health_score',
          'Общий score',
          healthScore?.score,
          unit: '/100',
          source: 'MediAI',
          status: healthScore?.status,
        ),
        ExportField(
          code: 'activity_model',
          label: 'Модель активности',
          displayValue: _activityClassLabel(
            _featureString(activity?.features, 'activity_class') ??
                activity?.status ??
                '',
          ),
          source: 'Harvard activity model',
          status: activity?.status,
          isDerived: true,
        ),
        _numericField(
          'sleep_model',
          'Модель сна',
          sleep?.score,
          unit: '/100',
          source: 'Sleep model',
          status: sleep?.status,
        ),
        _numericField(
          'stress_model',
          'Модель стресса',
          stress?.score,
          unit: '/100',
          source: 'Stress model',
          status: stress?.status,
        ),
        _numericField(
          'baseline_model',
          'Личная норма / anomaly',
          baseline?.score,
          unit: '/100',
          source: 'Baseline model',
          status: baseline?.status,
        ),
      ],
      note: latestModelOutputs.isEmpty
          ? 'В выбранном периоде нет сохранённых model outputs.'
          : 'Результаты моделей привязаны к сохранённым окнам inferencing, пересекающим выбранный период.',
    );
  }

  ExportSection _buildRecommendationsSection(List<String> recommendations) {
    return ExportSection(
      id: 'recommendations',
      title: 'Рекомендации приложения',
      fields: recommendations
          .map(
            (line) => ExportField(
              code: line,
              label: 'Рекомендация',
              displayValue: line,
              isDerived: true,
              source: 'MediAI',
            ),
          )
          .toList(growable: false),
      note: recommendations.isEmpty
          ? 'Рекомендации пока не сформированы.'
          : 'Показаны последние рекомендации приложения.',
    );
  }

  ExportSection _buildRawMetricsSection(List<HealthMetricSample> metrics) {
    final sorted = [...metrics]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final preview = sorted
        .take(5)
        .map((sample) {
          final timestamp = DateFormat(
            'dd.MM HH:mm',
          ).format(sample.timestamp.toLocal());
          return ExportField(
            code: '${sample.type.key}_${sample.id}',
            label: _metricLabel(sample.type),
            displayValue: '${_formatNumber(sample.value)} ${sample.unit}'
                .trim(),
            source: sample.sourceId,
            effectiveDateTime: sample.timestamp,
            comment: timestamp,
          );
        })
        .toList(growable: false);

    return ExportSection(
      id: 'raw',
      title: 'Сырые показатели',
      fields: preview,
      note: metrics.isEmpty
          ? 'Сырые показатели не найдены.'
          : 'Показаны последние 5 записей из ${metrics.length}.',
    );
  }

  ExportSection _buildAnomaliesSection(
    Map<String, HealthModelOutputRecord> latestModelOutputs,
  ) {
    final fields = <ExportField>[];
    final baseline = latestModelOutputs['baseline_forecast_v1'];
    final stress = latestModelOutputs['stress_score_v1'];
    final recovery = latestModelOutputs['personal_physiology_anomaly_v1'];

    final baselineMetrics = _nestedMap(baseline?.features, 'metrics');
    for (final entry in baselineMetrics.entries.take(5)) {
      final metricPayload = _mapValue(entry.value);
      final delta = _toDouble(metricPayload['delta']);
      final actual = _toDouble(metricPayload['actual']);
      final expected = _toDouble(metricPayload['expected']);
      if (delta == null && actual == null && expected == null) {
        continue;
      }
      fields.add(
        ExportField(
          code: 'baseline_${entry.key}',
          label: _baselineMetricLabel(entry.key),
          displayValue:
              'Факт ${_formatOptionalNumber(actual)}, ожидалось ${_formatOptionalNumber(expected)}',
          deviation: delta == null
              ? null
              : _formatDeviation(delta, _baselineUnit(entry.key)),
          status: metricPayload['severity']?.toString(),
          source: 'Baseline model',
          isDerived: true,
        ),
      );
    }

    if (stress != null) {
      for (final reason in stress.reasonCodes.take(3)) {
        fields.add(
          ExportField(
            code: 'stress_reason_${reason['code']}',
            label: 'Фактор стресса',
            displayValue: reason['message']?.toString(),
            status: reason['severity']?.toString(),
            comment: _reasonImpactLabel(reason['impact']),
            source: 'Stress model',
            isDerived: true,
          ),
        );
      }
    }

    if (recovery != null) {
      for (final reason in recovery.reasonCodes.take(3)) {
        fields.add(
          ExportField(
            code: 'recovery_reason_${reason['code']}',
            label: 'Фактор восстановления',
            displayValue: reason['message']?.toString(),
            status: _impactSeverity(_toDouble(reason['impact'])),
            comment: _reasonImpactLabel(reason['impact']),
            source: 'Recovery model',
            isDerived: true,
          ),
        );
      }
    }

    return ExportSection(
      id: 'anomalies',
      title: 'Отклонения от нормы',
      fields: fields,
      note: fields.isEmpty
          ? 'Выраженные отклонения от личной нормы в сохранённых model outputs не найдены.'
          : null,
    );
  }

  List<ExportObservation> _buildObservations({
    required List<HealthMetricSample> metrics,
    required List<HealthModelOutputRecord> modelOutputHistory,
    required bool includeDerived,
  }) {
    final output = metrics
        .where((sample) => sample.value.isFinite)
        .map(
          (sample) => ExportObservation(
            effectiveDateTime: sample.timestamp,
            metricType: sample.type.key,
            metricLabel: _metricLabel(sample.type),
            value: sample.value,
            unit: sample.unit,
            source: sample.sourceId,
          ),
        )
        .toList(growable: true);

    if (!includeDerived) {
      return output;
    }

    for (final record in modelOutputHistory) {
      final score = record.score;
      if (score == null || !score.isFinite) {
        continue;
      }
      output.add(
        ExportObservation(
          effectiveDateTime: record.windowEnd,
          metricType: record.modelId,
          metricLabel: _modelLabel(record.modelId),
          value: score,
          unit: '/100',
          source: record.source ?? record.modelId,
          status: record.status,
          comment: 'model output',
          isDerived: true,
        ),
      );
    }
    return output;
  }

  Map<String, String> _buildPersonalData(ProfileData? profileData) {
    final user = profileData?.user;
    if (user == null) {
      return const <String, String>{};
    }

    final data = <String, String>{};
    if (user.name.trim().isNotEmpty) {
      data['name'] = user.name.trim();
    }
    if (user.email.trim().isNotEmpty) {
      data['email'] = user.email.trim();
    }
    if (user.age != null) {
      data['age'] = '${user.age}';
    }
    if (user.sex != null && user.sex!.trim().isNotEmpty) {
      data['sex'] = user.sex!.trim();
    }
    if (user.heightCm != null) {
      data['heightCm'] = _formatNumber(user.heightCm!);
    }
    if (user.weightKg != null) {
      data['weightKg'] = _formatNumber(user.weightKg!);
    }
    return data;
  }

  List<String> _resolveRecommendations({
    HealthModelOutputRecord? latestRecommendationOutput,
    DashboardSummary? summary,
  }) {
    final featureKeys =
        latestRecommendationOutput?.features['recommendation_keys'];
    final keys = featureKeys is List
        ? featureKeys
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : (summary?.recommendationKeys ?? const <String>[]);
    final output = <String>[];
    for (final key in keys) {
      final resolved = AppLocalizations.lookup(
        key,
        language: AppLanguage.russian,
      );
      if (resolved.trim().isEmpty || resolved == key) {
        continue;
      }
      output.add(resolved);
    }
    return output;
  }

  ExportField _numericField(
    String code,
    String label,
    double? value, {
    String? unit,
    String? source,
    String? status,
    String? deviation,
  }) {
    return ExportField(
      code: code,
      label: label,
      displayValue: value == null ? null : _formatNumber(value),
      numericValue: value,
      unit: unit,
      source: source,
      status: status,
      deviation: deviation,
      isDerived: source != null,
    );
  }

  ExportField _durationField(String code, String label, double? minutes) {
    return ExportField(
      code: code,
      label: label,
      displayValue: minutes == null ? null : _formatDuration(minutes),
      numericValue: minutes,
      unit: 'min',
    );
  }

  double? _average(List<HealthMetricSample> samples) {
    final values = samples
        .map((sample) => sample.value)
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _sum(
    List<HealthMetricSample> samples, {
    double Function(HealthMetricSample sample)? transform,
  }) {
    if (samples.isEmpty) {
      return null;
    }
    double total = 0;
    var hasAny = false;
    for (final sample in samples) {
      final value = transform?.call(sample) ?? sample.value;
      if (!value.isFinite) {
        continue;
      }
      total += value;
      hasAny = true;
    }
    return hasAny ? total : null;
  }

  double? _minValue(List<HealthMetricSample> samples) {
    if (samples.isEmpty) {
      return null;
    }
    return samples.map((sample) => sample.value).reduce(math.min);
  }

  double? _maxValue(List<HealthMetricSample> samples) {
    if (samples.isEmpty) {
      return null;
    }
    return samples.map((sample) => sample.value).reduce(math.max);
  }

  List<double> _latestTwoValues(List<HealthMetricSample> samples) {
    final sorted = [...samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (sorted.length < 2) {
      return sorted.map((sample) => sample.value).toList(growable: false);
    }
    return sorted
        .skip(sorted.length - 2)
        .map((sample) => sample.value)
        .toList(growable: false);
  }

  String? _trendDescription(List<double> values) {
    if (values.length < 2) {
      return null;
    }
    final delta = values.last - values.first;
    if (delta.abs() < 1) {
      return 'стабильно';
    }
    return delta > 0 ? 'рост' : 'снижение';
  }

  List<HealthMetricSample> _preferredSleepSamples(
    List<HealthMetricSample> metrics,
  ) {
    const typesByPriority = [
      HealthMetricType.sleepAsleep,
      HealthMetricType.sleep,
      HealthMetricType.sleepSession,
      HealthMetricType.sleepDeep,
      HealthMetricType.sleepLight,
      HealthMetricType.sleepRem,
    ];
    for (final type in typesByPriority) {
      final filtered = metrics.where((sample) => sample.type == type).toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return const <HealthMetricSample>[];
  }

  double _sleepMinutes(HealthMetricSample sample) {
    final interval = sample.intervalMinutes;
    if (interval != null && interval > 0) {
      return interval;
    }
    final unit = sample.unit.toLowerCase();
    if (unit.contains('sec')) {
      return sample.value / 60;
    }
    if (unit.contains('hour') || unit == 'h' || unit == 'hr') {
      return sample.value * 60;
    }
    if (unit.contains('min')) {
      return sample.value;
    }
    if (sample.value > 24) {
      return sample.value;
    }
    return sample.value * 60;
  }

  double _exerciseMinutes(HealthMetricSample sample) {
    final unit = sample.unit.toLowerCase();
    if (unit.contains('sec')) {
      return sample.value / 60;
    }
    if (unit.contains('hour') || unit == 'h' || unit == 'hr') {
      return sample.value * 60;
    }
    return sample.value;
  }

  String? _sleepQualityLabel(double? avgMinutes) {
    if (avgMinutes == null) {
      return null;
    }
    if (avgMinutes >= 480) {
      return 'хорошее';
    }
    if (avgMinutes >= 420) {
      return 'умеренное';
    }
    return 'ниже желаемого';
  }

  String _formatDuration(double minutes) {
    final rounded = minutes.round();
    final hours = rounded ~/ 60;
    final mins = rounded % 60;
    if (hours <= 0) {
      return '$mins мин';
    }
    return '$hours ч ${mins.toString().padLeft(2, '0')} мин';
  }

  String _formatNumber(double value) {
    if ((value - value.round()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatOptionalNumber(double? value) {
    if (value == null) {
      return 'нет данных';
    }
    return _formatNumber(value);
  }

  String _formatDeviation(double delta, String unit) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${_formatNumber(delta)} $unit'.trim();
  }

  String _metricLabel(HealthMetricType type) {
    return switch (type) {
      HealthMetricType.heartRate => 'Пульс',
      HealthMetricType.restingHeartRate => 'Пульс в покое',
      HealthMetricType.walkingHeartRate => 'Пульс при ходьбе',
      HealthMetricType.heartRateVariabilityRmssd => 'HRV RMSSD',
      HealthMetricType.heartRateVariabilitySdnn => 'HRV SDNN',
      HealthMetricType.steps => 'Шаги',
      HealthMetricType.exerciseTime => 'Активные минуты',
      HealthMetricType.activeEnergyBurned => 'Активная энергия',
      HealthMetricType.sleepAsleep => 'Сон',
      HealthMetricType.sleep => 'Сон',
      HealthMetricType.sleepSession => 'Сон',
      HealthMetricType.sleepDeep => 'Глубокий сон',
      HealthMetricType.sleepLight => 'Лёгкий сон',
      HealthMetricType.sleepRem => 'REM сон',
      _ => type.displayName,
    };
  }

  String _activityClassLabel(String code) {
    return switch (code) {
      'lying' => 'Преимущественно отдых',
      'sitting' => 'Низкая активность',
      'self_pace_walk' => 'Ходьба',
      'running_3_met' => 'Лёгкая пробежка',
      'running_5_met' => 'Умеренная пробежка',
      'running_7_met' => 'Интенсивная пробежка',
      'insufficient_data' || '' => 'нет данных',
      _ => code,
    };
  }

  String _groupLabel(String code) {
    return switch (code) {
      'cardio' => 'Кардио',
      'sleep' => 'Сон',
      'stress' => 'Стресс',
      'activity' => 'Активность',
      _ => code,
    };
  }

  String _baselineMetricLabel(String metric) {
    return switch (metric) {
      'sleep_duration' => 'Длительность сна',
      'resting_hr' => 'Пульс в покое',
      'steps' => 'Шаги',
      'hrv_rmssd' => 'HRV RMSSD',
      'hrv_sdnn' => 'HRV SDNN',
      _ => metric,
    };
  }

  String _baselineUnit(String metric) {
    return switch (metric) {
      'sleep_duration' => 'мин',
      'resting_hr' => 'bpm',
      'steps' => 'count',
      'hrv_rmssd' || 'hrv_sdnn' => 'ms',
      _ => '',
    };
  }

  String _modelLabel(String modelId) {
    return switch (modelId) {
      'healthscore_v1' => 'Общий score',
      'sleep_quality' => 'Модель сна',
      'stress_score_v1' => 'Модель стресса',
      'baseline_forecast_v1' => 'Отклонение от нормы',
      'personal_physiology_anomaly_v1' => 'Восстановление',
      'harvard_activity_recommendation_v1' => 'Модель активности',
      _ => modelId,
    };
  }

  double? _featureDouble(Map<String, dynamic>? map, String key) {
    return _toDouble(map?[key]);
  }

  String? _featureString(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    return value?.toString();
  }

  String? _groupScoresSummary(HealthModelOutputRecord? recovery) {
    final groups = recovery?.features['group_scores'];
    if (groups is! List || groups.isEmpty) {
      return null;
    }
    return groups
        .whereType<Map>()
        .map((group) {
          final code = group['code']?.toString() ?? '';
          final score = _toDouble(group['score']);
          if (score == null) {
            return _groupLabel(code);
          }
          return '${_groupLabel(code)} ${score.toStringAsFixed(0)}/100';
        })
        .join(', ');
  }

  Map<String, dynamic> _nestedMap(Map<String, dynamic>? parent, String key) {
    final value = parent?[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse(value.toString());
  }

  String? _reasonImpactLabel(Object? value) {
    final impact = _toDouble(value);
    if (impact == null) {
      return null;
    }
    return 'Вклад ${impact.toStringAsFixed(2)}';
  }

  String? _impactSeverity(double? impact) {
    if (impact == null) {
      return null;
    }
    if (impact >= 0.66) {
      return 'high';
    }
    if (impact >= 0.33) {
      return 'medium';
    }
    return 'low';
  }
}
