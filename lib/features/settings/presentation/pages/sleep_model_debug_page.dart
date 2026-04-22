import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../../dashboard/data/services/sleep_quality_inference_model.dart';
import '../../../health_data/data/datasources/health_data_remote_data_source.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';

class SleepModelDebugPage extends StatefulWidget {
  final VoidCallback onBack;

  const SleepModelDebugPage({super.key, required this.onBack});

  @override
  State<SleepModelDebugPage> createState() => _SleepModelDebugPageState();
}

class _SleepModelDebugPageState extends State<SleepModelDebugPage> {
  final _remote = getIt<HealthDataRemoteDataSource>();
  final _model = getIt<SleepQualityInferenceModel>();

  bool _loading = true;
  bool _running = false;
  String? _error;
  String? _lastRunLabel;
  double _progress = 0;

  List<HealthMetricSample> _wearableSamples = const [];
  List<_DebugResultRow> _rows = const [];

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

  Future<void> _runPresetRange2130() async {
    if (_wearableSamples.isEmpty) {
      setState(() {
        _error = 'Нет wearable-данных в snapshot.';
      });
      return;
    }

    final latest = _wearableSamples.last.timestamp.toUtc();
    final first = _wearableSamples.first.timestamp.toUtc();
    final start = DateTime.utc(
      latest.year,
      latest.month,
      latest.day,
    ).subtract(const Duration(days: 30));
    final end = DateTime.utc(
      latest.year,
      latest.month,
      latest.day,
    ).subtract(const Duration(days: 21));

    final boundedStart = start.isBefore(first) ? first : start;
    if (boundedStart.isAfter(end)) {
      setState(() {
        _error =
            'Недостаточно старых данных для диапазона 21-30 дней до последней записи.';
      });
      return;
    }

    final anchors = _buildDailyAnchors(start: boundedStart, end: end);
    await _runAnchors(
      anchors: anchors,
      runLabel: 'Диапазон 21-30 дней до последней записи',
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
    final start = first.add(const Duration(days: 14));
    if (start.isAfter(latest)) {
      setState(() {
        _error =
            'История короче минимального окна модели (14 дней). Прогон невозможен.';
      });
      return;
    }

    final anchors = _buildDailyAnchors(start: start, end: latest);
    await _runAnchors(anchors: anchors, runLabel: 'Вся доступная история');
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

    final results = <_DebugResultRow>[];
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
          _DebugResultRow(
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
                        l10n.get('sleepModelDebug'),
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
                  l10n.get('sleepModelDebugSubtitle'),
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
                          onPressed: _running ? null : _runPresetRange2130,
                          child: Text(l10n.get('sleepModelDebugRun2130')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _running ? null : _runFullHistory,
                          child: Text(l10n.get('sleepModelDebugRunAll')),
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
                          l10n.get('sleepModelDebugNoRows'),
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

    final okRows = _rows
        .where((row) => row.inference.score != null)
        .toList(growable: false);
    final avgScore = okRows.isEmpty
        ? null
        : okRows.map((row) => row.inference.score!).reduce((a, b) => a + b) /
              okRows.length;

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
              'Результатов: ${_rows.length}, OK: ${okRows.length}, insufficient: ${_rows.length - okRows.length}'
              '${avgScore == null ? '' : ', avg score: ${avgScore.toStringAsFixed(1)}'}',
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
    required _DebugResultRow row,
    required Color titleColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final inference = row.inference;
    final score = inference.score;

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
                  color: score == null
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  score == null
                      ? 'insufficient'
                      : 'score ${score.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: score == null
                        ? const Color(0xFFB45309)
                        : const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'samples<=anchor: ${row.sampleCount}, nights: ${inference.nightsUsed}, confidence: ${inference.confidence.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'reason: ${inference.reason}',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          Text(
            'model: ${inference.selectedModel} (${inference.modelVersion})',
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          if (inference.latestNight != null) ...[
            const SizedBox(height: 8),
            Text(
              'night: ${_fmtDateTime(inference.latestNight!.startUtc)} -> ${_fmtDateTime(inference.latestNight!.endUtc)}',
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'sleep: ${_fmtDurationH(inference.latestNight!.sleepMinutes)} | in bed: ${_fmtDurationH(inference.latestNight!.inBedMinutes)} | efficiency: ${inference.latestNight!.sleepEfficiencyPct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              'clock: asleep~${_fmtHourAsClock(inference.latestNight!.asleepHour)} | wake~${_fmtHourAsClock(inference.latestNight!.wakeupHour)}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              'hr: mean ${_fmtNullable(inference.latestNight!.hrMean, 1)} | std ${_fmtNullable(inference.latestNight!.hrStd, 1)} | min ${_fmtNullable(inference.latestNight!.hrMin, 1)} | max ${_fmtNullable(inference.latestNight!.hrMax, 1)}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              'hrv: rmssd ${_fmtNullable(inference.latestNight!.rmssdMean, 2)} | sdnn ${_fmtNullable(inference.latestNight!.sdnnMean, 2)}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              'activity: steps mean ${_fmtNullable(inference.latestNight!.stepsMean, 2)} | distance mean ${_fmtNullable(inference.latestNight!.distanceMean, 3)} | calories mean ${_fmtNullable(inference.latestNight!.caloriesMean, 2)}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              inference.latestNight!.missingOptionalModalities.isEmpty
                  ? 'optional modalities: all present'
                  : 'optional modalities missing: ${inference.latestNight!.missingOptionalModalities.join(', ')}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            Text(
              'coverage: ${inference.latestNight!.coverageHours.toStringAsFixed(2)} h | windows: ${inference.latestNight!.windowCount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDurationH(double minutes) {
    final hours = minutes / 60.0;
    return '${hours.toStringAsFixed(2)} h';
  }

  String _fmtNullable(double? value, int digits) {
    if (value == null) return '-';
    return value.toStringAsFixed(digits);
  }

  String _fmtHourAsClock(double hour) {
    final safeHour = hour.isFinite ? hour.clamp(0.0, 24.0) : 0.0;
    final whole = safeHour.floor();
    final minute = ((safeHour - whole) * 60).round().clamp(0, 59);
    final hh = (whole % 24).toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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

class _DebugResultRow {
  final DateTime anchorUtc;
  final int sampleCount;
  final SleepQualityInferenceResult inference;

  const _DebugResultRow({
    required this.anchorUtc,
    required this.sampleCount,
    required this.inference,
  });
}
