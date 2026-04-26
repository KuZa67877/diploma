import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../../dashboard/data/services/stress_inference_model.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';

class StressModelDebugPage extends StatefulWidget {
  final VoidCallback onBack;

  const StressModelDebugPage({super.key, required this.onBack});

  @override
  State<StressModelDebugPage> createState() => _StressModelDebugPageState();
}

class _StressModelDebugPageState extends State<StressModelDebugPage> {
  static const int _maxAnchors = 1000;

  final _remote = getIt<HealthDataRemoteDataSource>();
  final _model = getIt<StressInferenceModel>();

  bool _loading = true;
  bool _running = false;
  String? _error;
  String? _lastRunLabel;
  String? _anchorStepLabel;
  double _progress = 0;

  List<HealthMetricSample> _wearableSamples = const [];
  List<_StressDebugResultRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
      _lastRunLabel = null;
      _anchorStepLabel = null;
      _progress = 0;
    });

    try {
      final snapshot = await _remote.getSnapshot();
      final wearable =
          snapshot.cachedSamples
              .where(
                (sample) =>
                    sample.sourceId.trim().toLowerCase() != 'local_manual',
              )
              .toList(growable: false)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _wearableSamples = wearable;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _runRecent7Days() async {
    if (_wearableSamples.isEmpty) {
      setState(() {
        _error = 'Нет wearable-данных в snapshot.';
      });
      return;
    }

    final first = _wearableSamples.first.timestamp.toUtc();
    final latest = _wearableSamples.last.timestamp.toUtc();
    final baselineReady = first.add(const Duration(days: 3));
    final requestedStart = latest.subtract(const Duration(days: 7));
    final start = requestedStart.isBefore(baselineReady)
        ? baselineReady
        : requestedStart;

    if (start.isAfter(latest)) {
      setState(() {
        _error = 'История короче минимального baseline-окна модели стресса.';
      });
      return;
    }

    final build = _buildAdaptiveAnchors(start: start, end: latest);
    await _runAnchors(
      anchors: build.anchors,
      runLabel: 'Последние 7 дней',
      stepLabel: build.stepLabel,
    );
  }

  Future<void> _runFullHistory() async {
    if (_wearableSamples.isEmpty) {
      setState(() {
        _error = 'Нет wearable-данных в snapshot.';
      });
      return;
    }

    final first = _wearableSamples.first.timestamp.toUtc();
    final latest = _wearableSamples.last.timestamp.toUtc();
    final start = first.add(const Duration(days: 3));

    if (start.isAfter(latest)) {
      setState(() {
        _error =
            'История короче минимального baseline-окна модели стресса. Прогон невозможен.';
      });
      return;
    }

    final build = _buildAdaptiveAnchors(start: start, end: latest);
    await _runAnchors(
      anchors: build.anchors,
      runLabel: 'Вся доступная история',
      stepLabel: build.stepLabel,
    );
  }

  _AnchorBuildResult _buildAdaptiveAnchors({
    required DateTime start,
    required DateTime end,
  }) {
    final startHour = DateTime.utc(
      start.year,
      start.month,
      start.day,
      start.hour,
    );
    final endHour = DateTime.utc(end.year, end.month, end.day, end.hour);
    if (startHour.isAfter(endHour)) {
      return const _AnchorBuildResult(anchors: [], stepLabel: 'none');
    }

    final totalHours = max(1, endHour.difference(startHour).inHours);
    final minStepHours = max(1, (totalHours / _maxAnchors).ceil());
    final stepHours = switch (minStepHours) {
      <= 1 => 1,
      <= 3 => 3,
      <= 6 => 6,
      <= 12 => 12,
      <= 24 => 24,
      _ => minStepHours,
    };

    final anchors = <DateTime>[];
    var cursor = startHour;
    while (!cursor.isAfter(endHour)) {
      anchors.add(cursor);
      cursor = cursor.add(Duration(hours: stepHours));
    }
    if (anchors.isEmpty || anchors.last.isBefore(end)) {
      anchors.add(end);
    }

    return _AnchorBuildResult(
      anchors: anchors,
      stepLabel: stepHours == 1 ? '1 hour' : '$stepHours hours',
    );
  }

  Future<void> _runAnchors({
    required List<DateTime> anchors,
    required String runLabel,
    required String stepLabel,
  }) async {
    if (anchors.isEmpty) {
      setState(() {
        _error = 'Нет якорных дат для прогона.';
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _rows = const [];
      _lastRunLabel = runLabel;
      _anchorStepLabel = stepLabel;
      _progress = 0;
    });

    final results = <_StressDebugResultRow>[];
    var cursor = 0;
    final total = anchors.length;

    try {
      for (var i = 0; i < anchors.length; i++) {
        final anchor = anchors[i];

        while (cursor < _wearableSamples.length &&
            !_wearableSamples[cursor].timestamp.toUtc().isAfter(anchor)) {
          cursor += 1;
        }

        final slice = cursor > 0
            ? _wearableSamples.sublist(0, cursor)
            : const <HealthMetricSample>[];
        final inference = await _model.infer(samples: slice, now: anchor);

        results.add(
          _StressDebugResultRow(
            anchorUtc: anchor,
            sampleCount: cursor,
            inference: inference,
          ),
        );

        final nextProgress = (i + 1) / max(total, 1);
        if ((i + 1) % 8 == 0 || i == total - 1) {
          if (!mounted) return;
          setState(() {
            _progress = nextProgress;
            _rows = List.unmodifiable(results);
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка прогона: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _progress = 1;
          _rows = List.unmodifiable(results);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(LucideIcons.chevronLeft),
                    ),
                    Expanded(
                      child: Text(
                        l10n.get('stressModelDebug'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.get('stressModelDebugSubtitle'),
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildSummaryCard(
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    cardColor: cardColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _running ? null : _runRecent7Days,
                          child: Text(l10n.get('stressModelDebugRunRecent')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _running ? null : _runFullHistory,
                          child: Text(l10n.get('stressModelDebugRunAll')),
                        ),
                      ),
                    ],
                  ),
                  if (_running) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _progress),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_rows.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.get('stressModelDebugNoRows'),
                          style: TextStyle(color: subtitleColor),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = _rows[_rows.length - 1 - index];
                          return _buildResultCard(
                            row: row,
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required Color titleColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final first = _wearableSamples.isEmpty
        ? null
        : _wearableSamples.first.timestamp.toUtc();
    final last = _wearableSamples.isEmpty
        ? null
        : _wearableSamples.last.timestamp.toUtc();
    final typeCounts = <String, int>{};
    for (final sample in _wearableSamples) {
      final key = sample.type.name;
      typeCounts[key] = (typeCounts[key] ?? 0) + 1;
    }
    final topTypes = typeCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = topTypes.take(6).map((e) => '${e.key}:${e.value}').join(', ');

    final scoredRows = _rows
        .where((row) => row.inference.stressScore != null)
        .toList(growable: false);
    final mlRows = _rows
        .where((row) => row.inference.source == 'scorecard_logistic_trained')
        .toList(growable: false);
    final avgScore = scoredRows.isEmpty
        ? null
        : scoredRows
                  .map((row) => row.inference.stressScore!)
                  .reduce((a, b) => a + b) /
              scoredRows.length;
    final avgConfidence = _rows.isEmpty
        ? null
        : _rows.map((row) => row.inference.confidence).reduce((a, b) => a + b) /
              _rows.length;
    final statusCounts = <String, int>{};
    for (final row in _rows) {
      final status = row.inference.status;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    final statuses = statusCounts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Samples: ${_wearableSamples.length}',
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (first != null && last != null)
            Text(
              'Окно данных: ${_fmtDate(first)} .. ${_fmtDate(last)}',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          if (_lastRunLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Последний прогон: $_lastRunLabel, шаг: $_anchorStepLabel',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Результатов: ${_rows.length}, ML: ${mlRows.length}, fallback/insufficient: ${_rows.length - mlRows.length}'
              '${avgScore == null ? '' : ', avg score: ${avgScore.toStringAsFixed(1)}'}'
              '${avgConfidence == null ? '' : ', avg confidence: ${avgConfidence.toStringAsFixed(2)}'}',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
          if (statuses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Statuses: $statuses',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
          if (top.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Top metric types: $top',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required _StressDebugResultRow row,
    required Color titleColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final inference = row.inference;
    final score = inference.stressScore;
    final statusColor = _statusColor(inference.status);
    final topReasons = inference.reasonCodes.take(4).toList(growable: false);
    final topContributions = inference.modelContributions
        .take(5)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtDateTime(row.anchorUtc),
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  score == null
                      ? inference.status
                      : '${score.toStringAsFixed(1)} / ${inference.status}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'samples<=anchor: ${row.sampleCount}, confidence: ${inference.confidence.toStringAsFixed(2)}, source: ${inference.source}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'reason: ${inference.reason}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'model: ${inference.modelVersion}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 6),
          Text(
            'quality: overall ${inference.quality.overall.toStringAsFixed(2)} | hr ${inference.quality.heartRate.toStringAsFixed(2)} | baseline ${inference.quality.baseline.toStringAsFixed(2)} | sleep ${inference.quality.sleep.toStringAsFixed(2)} | hrv ${inference.quality.hrv.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          if (inference.missingModalities.isNotEmpty)
            Text(
              'missing: ${inference.missingModalities.join(', ')}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          if (topContributions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'model drivers',
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final contribution in topContributions)
              Text(
                _contributionLine(contribution),
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
          ],
          if (topReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'reason codes',
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final reason in topReasons)
              Text(
                '${reason.code} (${reason.severity}, ${reason.contribution.toStringAsFixed(2)})',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            _featureLine(inference.features),
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
        ],
      ),
    );
  }

  String _featureLine(Map<String, double?> features) {
    return [
      'hr ${_fmtNullable(features['hr_mean'], 1)}',
      'hr5 ${_fmtNullable(features['hr_mean_5m'], 1)}',
      'hr_z ${_fmtNullable(features['hr_z_14'], 2)}',
      'hr5_z ${_fmtNullable(features['hr_z_5m_14'], 2)}',
      'rhr_z ${_fmtNullable(features['resting_hr_z_30'], 2)}',
      'sdnn_z ${_fmtNullable(features['hrv_sdnn_z_30'], 2)}',
      'rmssd_z ${_fmtNullable(features['hrv_rmssd_z_30'], 2)}',
      'resp_z ${_fmtNullable(features['resp_rate_z_14'], 2)}',
      'sleep_d ${_fmtNullable(features['sleep_hours_delta_7'], 2)}',
      'steps1h ${_fmtNullable(features['steps_1h'], 0)}',
      'steps5m ${_fmtNullable(features['steps_5m'], 0)}',
      'workout_min ${_fmtNullable(features['minutes_since_workout'], 0)}',
    ].join(' | ');
  }

  String _contributionLine(StressModelContribution contribution) {
    final sign = contribution.contribution >= 0 ? '+' : '';
    final raw = contribution.rawValue == null
        ? 'missing->${_fmtNullable(contribution.imputedValue, 2)}'
        : _fmtNullable(contribution.rawValue, 2);
    return '${contribution.featureName} $sign${contribution.contribution.toStringAsFixed(2)} | raw $raw | z ${contribution.normalizedValue.toStringAsFixed(2)}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'risk' => AppColors.danger,
      'attention' => AppColors.warning,
      'stable' => AppColors.success,
      _ => AppColors.mutedForeground,
    };
  }

  String _fmtNullable(double? value, int digits) {
    if (value == null || !value.isFinite) return '-';
    return value.toStringAsFixed(digits);
  }

  String _fmtDate(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmtDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _AnchorBuildResult {
  final List<DateTime> anchors;
  final String stepLabel;

  const _AnchorBuildResult({required this.anchors, required this.stepLabel});
}

class _StressDebugResultRow {
  final DateTime anchorUtc;
  final int sampleCount;
  final StressInferenceResult inference;

  const _StressDebugResultRow({
    required this.anchorUtc,
    required this.sampleCount,
    required this.inference,
  });
}
