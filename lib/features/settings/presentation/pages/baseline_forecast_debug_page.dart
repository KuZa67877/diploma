import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../../dashboard/data/services/baseline_forecast_inference_model.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';

class BaselineForecastDebugPage extends StatefulWidget {
  final VoidCallback onBack;

  const BaselineForecastDebugPage({super.key, required this.onBack});

  @override
  State<BaselineForecastDebugPage> createState() =>
      _BaselineForecastDebugPageState();
}

class _BaselineForecastDebugPageState extends State<BaselineForecastDebugPage> {
  final _remote = getIt<HealthDataRemoteDataSource>();
  final _model = getIt<BaselineForecastInferenceModel>();

  bool _loading = true;
  bool _running = false;
  String? _error;
  String? _lastRunLabel;
  double _progress = 0;

  List<HealthMetricSample> _wearableSamples = const [];
  List<_BaselineDebugResultRow> _rows = const [];

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

  Future<void> _runLatestDay() async {
    if (_wearableSamples.isEmpty) {
      setState(() {
        _error = 'Нет wearable-данных в snapshot.';
      });
      return;
    }

    await _runAnchors(
      anchors: [_wearableSamples.last.timestamp.toUtc()],
      runLabel: 'Последний доступный день',
    );
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
    final baselineReady = first.add(const Duration(days: 3));
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
    final start = first.add(const Duration(days: 3));

    if (start.isAfter(latest)) {
      setState(() {
        _error =
            'История короче минимального baseline-окна модели. Прогон невозможен.';
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
    final startDay = BaselineForecastInferenceModel.startOfUtcDay(start);
    final endDay = BaselineForecastInferenceModel.startOfUtcDay(end);
    if (startDay.isAfter(endDay)) {
      return const [];
    }

    final days = endDay.difference(startDay).inDays;
    final anchors = <DateTime>[];
    for (var i = 0; i <= days; i++) {
      final day = startDay.add(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1, seconds: -1));
      anchors.add(day == endDay ? end : dayEnd);
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

    final results = <_BaselineDebugResultRow>[];
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
          _BaselineDebugResultRow(
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
                        l10n.get('baselineForecastDebug'),
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
                  l10n.get('baselineForecastDebugSubtitle'),
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
                          onPressed: _running ? null : _runLatestDay,
                          child: Text(
                            l10n.get('baselineForecastDebugRunLatest'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _running ? null : _runRecent14Days,
                          child: Text(
                            l10n.get('baselineForecastDebugRunRecent'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _running ? null : _runFullHistory,
                    child: Text(l10n.get('baselineForecastDebugRunAll')),
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
                          l10n.get('baselineForecastDebugNoRows'),
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
    final scoredRows = _rows
        .where((row) => row.inference.overallDeviationScore != null)
        .toList(growable: false);
    final avgScore = scoredRows.isEmpty
        ? null
        : scoredRows
                  .map((row) => row.inference.overallDeviationScore!)
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
              'Результатов: ${_rows.length}, scored: ${scoredRows.length}, insufficient: ${_rows.length - scoredRows.length}'
              '${avgScore == null ? '' : ', avg deviation: ${avgScore.toStringAsFixed(1)}'}'
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
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required _BaselineDebugResultRow row,
    required Color titleColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final inference = row.inference;
    final score = inference.overallDeviationScore;
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
            'forecast_for: ${_fmtDate(inference.forecastFor)} | samples<=anchor: ${row.sampleCount}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'confidence: ${inference.confidence.toStringAsFixed(2)}, source: ${inference.source}, reason: ${inference.reason}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'quality: overall ${inference.dataQuality.overall.toStringAsFixed(2)} | history ${inference.dataQuality.historyCoverage.toStringAsFixed(2)} | actual ${inference.dataQuality.actualCoverage.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 8),
          Text(
            'reasons',
            style: TextStyle(
              fontSize: 12,
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            inference.summary.mainReasons.join(', '),
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 8),
          Text(
            'metrics',
            style: TextStyle(
              fontSize: 12,
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ..._orderedMetrics(inference.metrics).map(
            (entry) => _buildMetricLine(
              name: entry.key,
              metric: entry.value,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricLine({
    required String name,
    required BaselineForecastMetricResult metric,
    required Color titleColor,
    required Color subtitleColor,
    required Color borderColor,
  }) {
    final severityColor = _severityColor(metric.severity);
    final expected = _fmtNullable(metric.expected, 1);
    final actual = _fmtNullable(metric.actual, 1);
    final low = _fmtNullable(metric.expectedRangeLow, 1);
    final high = _fmtNullable(metric.expectedRangeHigh, 1);
    final delta = _fmtNullable(metric.delta, 1);
    final deltaPct = _fmtNullable(metric.deltaPercent, 1);
    final z = _fmtNullable(metric.robustZ, 2);
    final partial = metric.actualIsPartial ? ' | partial' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${metric.severity}$partial',
                style: TextStyle(
                  color: severityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'expected $expected | actual $actual | delta $delta ($deltaPct%)',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'range [$low, $high] | robust_z $z | conf ${metric.confidence.toStringAsFixed(2)} | q ${metric.dataQuality.toStringAsFixed(2)} | days ${metric.validDays}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'method: ${metric.method}',
            style: TextStyle(fontSize: 11, color: subtitleColor),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, BaselineForecastMetricResult>> _orderedMetrics(
    Map<String, BaselineForecastMetricResult> metrics,
  ) {
    final entries = metrics.entries.toList(growable: false);
    entries.sort((a, b) {
      final severityCompare = _severityRank(
        b.value.severity,
      ).compareTo(_severityRank(a.value.severity));
      if (severityCompare != 0) {
        return severityCompare;
      }
      final zCompare = (b.value.robustZ?.abs() ?? 0).compareTo(
        a.value.robustZ?.abs() ?? 0,
      );
      if (zCompare != 0) {
        return zCompare;
      }
      return a.key.compareTo(b.key);
    });
    return entries;
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

  Color _statusColor(String status) {
    return switch (status) {
      'high_deviation' => AppColors.danger,
      'attention' => AppColors.warning,
      'stable' => AppColors.success,
      'pending_actuals' => AppColors.primary,
      _ => AppColors.mutedForeground,
    };
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'high' => AppColors.danger,
      'moderate' => AppColors.warning,
      'mild' => AppColors.warning,
      'normal' => AppColors.success,
      'pending' => AppColors.primary,
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

class _BaselineDebugResultRow {
  final DateTime anchorUtc;
  final int sampleCount;
  final BaselineForecastInferenceResult inference;

  const _BaselineDebugResultRow({
    required this.anchorUtc,
    required this.sampleCount,
    required this.inference,
  });
}
