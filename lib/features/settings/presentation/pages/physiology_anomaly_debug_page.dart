import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../../dashboard/data/services/physiology_anomaly_inference_model.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';

class PhysiologyAnomalyDebugPage extends StatefulWidget {
  final VoidCallback onBack;

  const PhysiologyAnomalyDebugPage({super.key, required this.onBack});

  @override
  State<PhysiologyAnomalyDebugPage> createState() =>
      _PhysiologyAnomalyDebugPageState();
}

class _PhysiologyAnomalyDebugPageState
    extends State<PhysiologyAnomalyDebugPage> {
  final _remote = getIt<HealthDataRemoteDataSource>();
  final _model = getIt<PhysiologyAnomalyInferenceModel>();

  bool _loading = true;
  bool _running = false;
  String? _error;
  String? _lastRunLabel;
  double _progress = 0;

  List<HealthMetricSample> _wearableSamples = const [];
  List<_PhysiologyDebugResultRow> _rows = const [];

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

  Future<void> _runRecent14Days() async {
    if (_wearableSamples.isEmpty) {
      setState(() {
        _error = 'Нет wearable-данных в snapshot.';
      });
      return;
    }

    final first = _wearableSamples.first.timestamp.toUtc();
    final latest = _wearableSamples.last.timestamp.toUtc();
    final baselineReady = first.add(const Duration(days: 7));
    final requestedStart = latest.subtract(const Duration(days: 14));
    final start = requestedStart.isBefore(baselineReady)
        ? baselineReady
        : requestedStart;

    if (start.isAfter(latest)) {
      setState(() {
        _error = 'История короче минимального baseline-окна модели.';
      });
      return;
    }

    await _runAnchors(
      anchors: _buildDailyAnchors(start: start, end: latest),
      runLabel: 'Последние 14 дней',
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
    final start = first.add(const Duration(days: 7));

    if (start.isAfter(latest)) {
      setState(() {
        _error =
            'История короче минимального окна модели (7 дней). Прогон невозможен.';
      });
      return;
    }

    await _runAnchors(
      anchors: _buildDailyAnchors(start: start, end: latest),
      runLabel: 'Вся доступная история',
    );
  }

  List<DateTime> _buildDailyAnchors({
    required DateTime start,
    required DateTime end,
  }) {
    final startDay = DateTime.utc(start.year, start.month, start.day);
    final endDay = DateTime.utc(end.year, end.month, end.day);
    if (startDay.isAfter(endDay)) {
      return const [];
    }

    final days = endDay.difference(startDay).inDays;
    final anchors = <DateTime>[];
    for (var i = 0; i <= days; i++) {
      final day = startDay.add(Duration(days: i));
      anchors.add(DateTime.utc(day.year, day.month, day.day, 23, 59, 59));
    }
    return anchors;
  }

  Future<void> _runAnchors({
    required List<DateTime> anchors,
    required String runLabel,
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
      _progress = 0;
    });

    final results = <_PhysiologyDebugResultRow>[];
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
        final inference = _model.inferSync(samples: slice, now: anchor);

        results.add(
          _PhysiologyDebugResultRow(
            anchorUtc: anchor,
            sampleCount: cursor,
            inference: inference,
          ),
        );

        final nextProgress = (i + 1) / max(total, 1);
        if ((i + 1) % 2 == 0 || i == total - 1) {
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
                        l10n.get('physiologyAnomalyDebug'),
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
                  l10n.get('physiologyAnomalyDebugSubtitle'),
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
                          onPressed: _running ? null : _runRecent14Days,
                          child: Text(
                            l10n.get('physiologyAnomalyDebugRunRecent'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _running ? null : _runFullHistory,
                          child: Text(l10n.get('physiologyAnomalyDebugRunAll')),
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
                          l10n.get('physiologyAnomalyDebugNoRows'),
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
        .where((row) => row.inference.anomalyScore != null)
        .toList(growable: false);
    final avgScore = scoredRows.isEmpty
        ? null
        : scoredRows
                  .map((row) => row.inference.anomalyScore!)
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
              'Последний прогон: $_lastRunLabel',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Результатов: ${_rows.length}, scored: ${scoredRows.length}, fallback/insufficient: ${_rows.length - scoredRows.length}'
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
    required _PhysiologyDebugResultRow row,
    required Color titleColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final inference = row.inference;
    final score = inference.anomalyScore;
    final statusColor = _statusColor(inference.status);

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
            'model: ${inference.modelId} (${inference.modelVersion})',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 6),
          Text(
            'quality: overall ${inference.dataQuality.overall.toStringAsFixed(2)} | heart ${inference.dataQuality.heart.toStringAsFixed(2)} | hrv ${inference.dataQuality.hrv.toStringAsFixed(2)} | sleep ${inference.dataQuality.sleep.toStringAsFixed(2)} | activity ${inference.dataQuality.activity.toStringAsFixed(2)} | temp ${inference.dataQuality.temperature.toStringAsFixed(2)} | resp ${inference.dataQuality.respiration.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          if (inference.groupScores.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'group scores',
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final group in inference.groupScores)
              Text(
                '${group.code}: ${group.score.toStringAsFixed(1)} | confidence ${group.confidence.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
          ],
          if (inference.reasonCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'reason codes',
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final reason in inference.reasonCodes.take(5))
              Text(
                '${reason.code} (${reason.impact.toStringAsFixed(2)})',
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
      'rhr_z ${_fmtNullable(features['resting_hr_zscore'], 2)}',
      'hrv_z ${_fmtNullable(features['hrv_sdnn_zscore'], 2)}',
      'resp_z ${_fmtNullable(features['respiratory_rate_zscore'], 2)}',
      'temp_z ${_fmtNullable(features['temperature_zscore'], 2)}',
      'sleep_d ${_fmtNullable(features['sleep_duration_delta_vs_baseline'], 0)}m',
      'activity_z ${_fmtNullable(features['activity_zscore'], 2)}',
      'iforest ${_fmtNullable(features['isolation_forest_score'], 1)}',
      'iforest_raw ${_fmtNullable(features['isolation_forest_raw_score'], 3)}',
      'train ${_fmtNullable(features['isolation_forest_training_days'], 0)}d',
      'baseline_days ${_fmtNullable(features['baseline_days_60'], 0)}',
    ].join(' | ');
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

class _PhysiologyDebugResultRow {
  final DateTime anchorUtc;
  final int sampleCount;
  final PhysiologyAnomalyInferenceResult inference;

  const _PhysiologyDebugResultRow({
    required this.anchorUtc,
    required this.sampleCount,
    required this.inference,
  });
}
