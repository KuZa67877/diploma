import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/logging/app_log_entry.dart';
import '../../../../core/logging/app_log_level.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/widgets/gradient_background.dart';

enum _LogFilter { all, debug, info, warning, error }

class DebugLogsPage extends StatefulWidget {
  final VoidCallback onBack;

  const DebugLogsPage({super.key, required this.onBack});

  @override
  State<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends State<DebugLogsPage> {
  final _logger = AppLogger.instance;
  _LogFilter _filter = _LogFilter.all;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
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
            child: Column(
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
                            localizations.get('debugLogs'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            localizations.get('debugLogsSubtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: localizations.get('copy'),
                      onPressed: () => _copyVisibleLogs(context),
                      icon: const Icon(LucideIcons.copy, size: 18),
                    ),
                    IconButton(
                      tooltip: localizations.get('clear'),
                      onPressed: _logger.clear,
                      icon: const Icon(LucideIcons.trash2, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      localizations.get('filterLabel'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<_LogFilter>(
                      value: _filter,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _filter = value);
                      },
                      items: [
                        DropdownMenuItem(
                          value: _LogFilter.all,
                          child: Text(localizations.get('all')),
                        ),
                        DropdownMenuItem(
                          value: _LogFilter.debug,
                          child: Text(localizations.get('debug')),
                        ),
                        DropdownMenuItem(
                          value: _LogFilter.info,
                          child: Text(localizations.get('info')),
                        ),
                        DropdownMenuItem(
                          value: _LogFilter.warning,
                          child: Text(localizations.get('warn')),
                        ),
                        DropdownMenuItem(
                          value: _LogFilter.error,
                          child: Text(localizations.get('error')),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ValueListenableBuilder<List<AppLogEntry>>(
                    valueListenable: _logger.entriesNotifier,
                    builder: (context, entries, _) {
                      final filtered = entries
                          .where(_matchesFilter)
                          .toList(growable: false)
                          .reversed
                          .toList(growable: false);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            localizations.get('noLogsYet'),
                            style: TextStyle(color: subtitleColor),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final levelColor = _levelColor(entry.level);
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMd,
                              ),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: levelColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        entry.level.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: levelColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(entry.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: titleColor,
                                  ),
                                ),
                                if (entry.payload != null &&
                                    entry.payload!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      entry.payload!,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(AppLogEntry entry) {
    switch (_filter) {
      case _LogFilter.all:
        return true;
      case _LogFilter.debug:
        return entry.level == AppLogLevel.debug;
      case _LogFilter.info:
        return entry.level == AppLogLevel.info;
      case _LogFilter.warning:
        return entry.level == AppLogLevel.warning;
      case _LogFilter.error:
        return entry.level == AppLogLevel.error;
    }
  }

  Future<void> _copyVisibleLogs(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entries = _logger.entries
        .where(_matchesFilter)
        .toList(growable: false);
    if (entries.isEmpty) {
      return;
    }

    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln(
        '[${entry.timestamp.toIso8601String()}] '
        '[${entry.level.label}] '
        '[${entry.category}] ${entry.message}',
      );
      if (entry.payload != null && entry.payload!.trim().isNotEmpty) {
        buffer.writeln(entry.payload);
      }
      buffer.writeln('---');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(localizations.get('logsCopiedToClipboard'))),
    );
  }

  String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    final ms = value.millisecond.toString().padLeft(3, '0');
    return '$hh:$mm:$ss.$ms';
  }

  Color _levelColor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return const Color(0xFF6B7280);
      case AppLogLevel.info:
        return AppColors.primary;
      case AppLogLevel.warning:
        return const Color(0xFFF59E0B);
      case AppLogLevel.error:
        return const Color(0xFFEF4444);
    }
  }
}
