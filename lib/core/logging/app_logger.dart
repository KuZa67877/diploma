import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_env.dart';
import 'app_log_entry.dart';
import 'app_log_level.dart';

class AppLogger {
  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 800;

  final ValueNotifier<List<AppLogEntry>> entriesNotifier =
      ValueNotifier<List<AppLogEntry>>(const []);

  AppLogger._();

  bool get isEnabled => AppEnv.isDevFlavor;

  List<AppLogEntry> get entries => entriesNotifier.value;

  void clear() {
    if (!isEnabled) {
      return;
    }
    entriesNotifier.value = const [];
  }

  void debug(String category, String message, {Object? payload}) {
    log(
      level: AppLogLevel.debug,
      category: category,
      message: message,
      payload: payload,
    );
  }

  void info(String category, String message, {Object? payload}) {
    log(
      level: AppLogLevel.info,
      category: category,
      message: message,
      payload: payload,
    );
  }

  void warning(String category, String message, {Object? payload}) {
    log(
      level: AppLogLevel.warning,
      category: category,
      message: message,
      payload: payload,
    );
  }

  void error(String category, String message, {Object? payload}) {
    log(
      level: AppLogLevel.error,
      category: category,
      message: message,
      payload: payload,
    );
  }

  void log({
    required AppLogLevel level,
    required String category,
    required String message,
    Object? payload,
  }) {
    if (!isEnabled) {
      return;
    }

    final timestamp = DateTime.now();
    final payloadText = _payloadToText(payload);
    final entry = AppLogEntry(
      timestamp: timestamp,
      level: level,
      category: category,
      message: message,
      payload: payloadText,
    );

    final updated = List<AppLogEntry>.from(entriesNotifier.value)..add(entry);
    if (updated.length > _maxEntries) {
      updated.removeRange(0, updated.length - _maxEntries);
    }
    entriesNotifier.value = List.unmodifiable(updated);

    final ts = timestamp.toIso8601String();
    if (payloadText == null || payloadText.isEmpty) {
      debugPrint('[$ts] [${level.label}] [$category] $message');
    } else {
      debugPrint('[$ts] [${level.label}] [$category] $message | $payloadText');
    }
  }

  String? _payloadToText(Object? payload) {
    if (payload == null) {
      return null;
    }

    try {
      if (payload is Map || payload is List) {
        return const JsonEncoder.withIndent('  ').convert(payload);
      }
      return payload.toString();
    } catch (_) {
      return payload.toString();
    }
  }
}
