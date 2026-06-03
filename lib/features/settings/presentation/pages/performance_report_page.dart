import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/perf/perf_trace_service.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../features/export/data/services/export_file_service.dart';
import '../../../../features/export/data/services/native_share_service.dart';
import '../../../../injection_container.dart';

class PerformanceReportPage extends StatefulWidget {
  const PerformanceReportPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PerformanceReportPage> createState() => _PerformanceReportPageState();
}

class _PerformanceReportPageState extends State<PerformanceReportPage> {
  final PerfTraceService _perfTraceService = getIt<PerfTraceService>();
  final ExportFileService _exportFileService = getIt<ExportFileService>();
  final NativeShareService _nativeShareService = getIt<NativeShareService>();

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final subtitleColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: ValueListenableBuilder<List<PerfTraceRecord>>(
              valueListenable: _perfTraceService.entriesNotifier,
              builder: (context, entries, _) {
                final summary = _perfTraceService.buildSummary();
                final recentEntries = entries.reversed
                    .take(30)
                    .toList(growable: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Performance report',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                'Локальные trace, JSON-логи и экспорт отчёта',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Скопировать JSON',
                          onPressed: _isBusy ? null : _copyJsonReport,
                          icon: const Icon(LucideIcons.copy, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Очистить отчёт',
                          onPressed: _isBusy ? null : _clearReport,
                          icon: const Icon(LucideIcons.trash2, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _SummaryCard(
                          title: 'Events',
                          value: '${summary.totalEvents}',
                          subtitle:
                              '${summary.measurementsCount} measurements / ${summary.marksCount} marks',
                          cardColor: cardColor,
                          borderColor: borderColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                        ),
                        _SummaryCard(
                          title: 'Latest ms',
                          value: _formatMs(summary.latestMeasurementMs),
                          subtitle:
                              'avg ${_formatMs(summary.averageMeasurementMs)} / max ${_formatMs(summary.maxMeasurementMs)}',
                          cardColor: cardColor,
                          borderColor: borderColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                        ),
                        _SummaryCard(
                          title: 'Session',
                          value: _formatMs(summary.sessionElapsedMs),
                          subtitle: summary.firebaseForwardingEnabled
                              ? 'Firebase Perf forwarding enabled'
                              : 'Firebase Perf forwarding disabled',
                          cardColor: cardColor,
                          borderColor: borderColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _exportJsonReport,
                            icon: const Icon(LucideIcons.download, size: 16),
                            label: Text(_isBusy ? 'Экспорт...' : 'Export JSON'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _shareJsonReport,
                            icon: const Icon(LucideIcons.share2, size: 16),
                            label: const Text('Share JSON'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          border: Border.all(color: borderColor),
                        ),
                        child: recentEntries.isEmpty
                            ? Center(
                                child: Text(
                                  'Отчёт пока пуст. Откройте аналитический экран, экспорт или debug-модели, чтобы появились замеры.',
                                  style: TextStyle(color: subtitleColor),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: recentEntries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = recentEntries[index];
                                  final accent =
                                      entry.type ==
                                          PerfTraceRecordType.measurement
                                      ? AppColors.primary
                                      : AppColors.success;
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: accent.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                entry.type.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                entry.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: titleColor,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatClock(entry.recordedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'session ${_formatMs(entry.sessionElapsedMs)}${entry.durationMs == null ? '' : ' • duration ${_formatMs(entry.durationMs!)}'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                        ),
                                        if (entry.payload != null &&
                                            entry.payload!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppColors.darkCard
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: SelectableText(
                                              _prettyPayload(entry.payload!),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: subtitleColor,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyJsonReport() async {
    final report = _perfTraceService.buildReportJson();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON-отчёт скопирован в буфер обмена')),
    );
  }

  Future<void> _exportJsonReport() async {
    await _runBusyAction(() async {
      final exportedFile = await _exportFileService.saveDebugJson(
        content: _perfTraceService.buildReportJson(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отчёт сохранён: ${exportedFile.fileName}')),
      );
    });
  }

  Future<void> _shareJsonReport() async {
    await _runBusyAction(() async {
      final exportedFile = await _exportFileService.saveDebugJson(
        content: _perfTraceService.buildReportJson(),
      );
      await _nativeShareService.shareFile(
        path: exportedFile.path,
        mimeType: exportedFile.mimeType,
        subject: 'MediAI performance report',
        text: 'Performance report exported from dev build.',
      );
    });
  }

  Future<void> _clearReport() async {
    _perfTraceService.clear();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Отчёт очищен')));
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  String _prettyPayload(Map<String, Object?> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _formatMs(double value) => '${value.toStringAsFixed(1)} ms';

  String _formatClock(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.cardColor,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color cardColor;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Container(
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
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}
