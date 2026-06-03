import 'dart:async';
import 'dart:convert';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import '../firebase/firebase_initializer.dart';
import '../logging/app_logger.dart';
import 'perf_probe.dart';

class PerfTraceService {
  PerfTraceService({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance,
      _firebaseBackend = AppEnv.enableFirebasePerformance
          ? _FirebasePerfTraceBackend()
          : null;

  final AppLogger _logger;
  final _FirebasePerfTraceBackend? _firebaseBackend;
  final ValueNotifier<List<PerfTraceRecord>> entriesNotifier =
      ValueNotifier<List<PerfTraceRecord>>(const []);

  bool _attached = false;
  DateTime _sessionStartedAt = DateTime.now().toUtc();
  int _nextRecordId = 0;
  final Map<int, _ActivePerfTrace> _activeTraces = <int, _ActivePerfTrace>{};

  List<PerfTraceRecord> get entries => entriesNotifier.value;

  bool hasMeasurementNamed(String name) {
    return entries.any(
      (record) =>
          record.type == PerfTraceRecordType.measurement && record.name == name,
    );
  }

  bool get isFirebaseForwardingEnabled =>
      _firebaseBackend != null &&
      AppEnv.enableFirebasePerformance &&
      AppEnv.enableFirebaseSync &&
      isFirebaseReady;

  Future<void> initialize() async {
    if (_attached) {
      await _firebaseBackend?.syncCollectionState();
      return;
    }

    final snapshot = PerfProbe.snapshot();
    _sessionStartedAt = DateTime.now().toUtc().subtract(
      Duration(
        microseconds: (_asDouble(snapshot['session_elapsed_ms']) * 1000)
            .round(),
      ),
    );
    PerfProbe.addListener(_handlePerfProbeEvent);
    _attached = true;
    await _firebaseBackend?.syncCollectionState();
    _seedExistingMarks(snapshot);
    _logger.info(
      'perf.trace',
      'Performance trace service initialized',
      payload: <String, Object?>{
        'firebase_forwarding_enabled': isFirebaseForwardingEnabled,
        'dev_flavor': AppEnv.isDevFlavor,
      },
    );
  }

  void clear() {
    _activeTraces.clear();
    _nextRecordId = 0;
    _sessionStartedAt = DateTime.now().toUtc();
    PerfProbe.reset();
    entriesNotifier.value = const [];
    _logger.info('perf.trace', 'Performance trace report cleared');
  }

  PerfTraceSummary buildSummary() {
    final records = entries;
    final measurements = records
        .where((record) => record.type == PerfTraceRecordType.measurement)
        .toList(growable: false);
    final marks = records
        .where((record) => record.type == PerfTraceRecordType.mark)
        .toList(growable: false);

    final latestMeasurementMs = measurements.isEmpty
        ? 0.0
        : measurements.last.durationMs ?? 0.0;
    final totalMeasurementMs = measurements.fold<double>(
      0,
      (sum, record) => sum + (record.durationMs ?? 0.0),
    );
    final averageMeasurementMs = measurements.isEmpty
        ? 0.0
        : totalMeasurementMs / measurements.length;
    final maxMeasurementMs = measurements.isEmpty
        ? 0.0
        : measurements
              .map((record) => record.durationMs ?? 0.0)
              .reduce((left, right) => left > right ? left : right);

    return PerfTraceSummary(
      sessionStartedAt: _sessionStartedAt,
      sessionElapsedMs:
          DateTime.now().toUtc().difference(_sessionStartedAt).inMicroseconds /
          1000.0,
      totalEvents: records.length,
      marksCount: marks.length,
      measurementsCount: measurements.length,
      latestMeasurementMs: latestMeasurementMs,
      averageMeasurementMs: averageMeasurementMs,
      maxMeasurementMs: maxMeasurementMs,
      firebaseForwardingEnabled: isFirebaseForwardingEnabled,
    );
  }

  Map<String, Object?> buildReport() {
    final summary = buildSummary();
    return <String, Object?>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'app': <String, Object?>{
        'flavor': AppEnv.appFlavor,
        'firebase_sync_enabled': AppEnv.enableFirebaseSync,
        'firebase_performance_enabled': AppEnv.enableFirebasePerformance,
        'firebase_ready': isFirebaseReady,
        'auth_bypass_enabled': AppEnv.enableAuthBypass,
        'platform': defaultTargetPlatform.name,
      },
      'summary': summary.toJson(),
      'entries': entries
          .map((record) => record.toJson())
          .toList(growable: false),
      'probe_snapshot': PerfProbe.snapshot(),
    };
  }

  String buildReportJson() {
    return const JsonEncoder.withIndent('  ').convert(buildReport());
  }

  void recordElapsedSinceSessionStart(
    String name, {
    Map<String, Object?>? payload,
    String source = 'manual_elapsed',
  }) {
    final snapshot = PerfProbe.snapshot();
    final durationMs = _asDouble(snapshot['session_elapsed_ms']);
    final record = PerfTraceRecord(
      id: ++_nextRecordId,
      type: PerfTraceRecordType.measurement,
      name: name,
      recordedAt: DateTime.now().toUtc(),
      sessionElapsedMs: durationMs,
      durationMs: durationMs,
      payload: payload,
      source: source,
    );
    _appendRecord(record);
    _logMeasurement(record);
  }

  void _seedExistingMarks(Map<String, Object?> snapshot) {
    final marks = snapshot['marks'] as List<Object?>? ?? const <Object?>[];

    if (marks.isEmpty) {
      return;
    }

    final existingNames = entries
        .where((record) => record.type == PerfTraceRecordType.mark)
        .map((record) => '${record.name}|${record.sessionElapsedMs}')
        .toSet();

    final seeded = <PerfTraceRecord>[];
    for (final rawMark in marks) {
      final mark = rawMark is Map<String, Object?> ? rawMark : null;
      if (mark == null) {
        continue;
      }
      final name = mark['name']?.toString();
      final sessionElapsedMs = _asDouble(mark['elapsed_ms']);
      if (name == null) {
        continue;
      }
      final dedupeKey = '$name|$sessionElapsedMs';
      if (existingNames.contains(dedupeKey)) {
        continue;
      }
      seeded.add(
        PerfTraceRecord(
          id: ++_nextRecordId,
          type: PerfTraceRecordType.mark,
          name: name,
          recordedAt: _sessionStartedAt.add(
            Duration(microseconds: (sessionElapsedMs * 1000).round()),
          ),
          sessionElapsedMs: sessionElapsedMs,
          payload: _castPayload(mark['payload']),
          source: 'probe_seed',
        ),
      );
    }

    if (seeded.isEmpty) {
      return;
    }

    entriesNotifier.value = List<PerfTraceRecord>.unmodifiable(
      <PerfTraceRecord>[...entriesNotifier.value, ...seeded],
    );
  }

  void _handlePerfProbeEvent(PerfProbeEvent event) {
    if (event is PerfMeasurementStartedEvent) {
      _activeTraces[event.traceId] = _ActivePerfTrace(
        firebaseTrace: _firebaseBackend?.startTrace(
          event.name,
          payload: event.payload,
        ),
      );
      return;
    }

    if (event is PerfMeasurementCompletedEvent) {
      final activeTrace = _activeTraces.remove(event.traceId);
      final record = PerfTraceRecord(
        id: ++_nextRecordId,
        type: PerfTraceRecordType.measurement,
        name: event.name,
        recordedAt: DateTime.now().toUtc(),
        sessionElapsedMs: event.sessionElapsedMicros / 1000.0,
        durationMs: event.durationMicros / 1000.0,
        payload: event.payload,
        source: 'probe_measurement',
      );
      _appendRecord(record);
      _logMeasurement(record);
      if (activeTrace != null) {
        unawaited(
          _firebaseBackend?.stopTrace(
            activeTrace.firebaseTrace,
            durationMs: record.durationMs ?? 0.0,
            payload: event.payload,
          ),
        );
      }
      return;
    }

    if (event is PerfMarkEvent) {
      final record = PerfTraceRecord(
        id: ++_nextRecordId,
        type: PerfTraceRecordType.mark,
        name: event.name,
        recordedAt: DateTime.now().toUtc(),
        sessionElapsedMs: event.sessionElapsedMicros / 1000.0,
        payload: event.payload,
        source: 'probe_mark',
      );
      _appendRecord(record);
      _logger.debug(
        'perf.trace',
        'Performance mark recorded',
        payload: record.toJson(),
      );
    }
  }

  void _appendRecord(PerfTraceRecord record) {
    entriesNotifier.value = List<PerfTraceRecord>.unmodifiable(
      <PerfTraceRecord>[...entriesNotifier.value, record],
    );
  }

  void _logMeasurement(PerfTraceRecord record) {
    _logger.info(
      'perf.trace',
      'Performance measurement recorded',
      payload: record.toJson(),
    );
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Map<String, Object?>? _castPayload(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }
}

enum PerfTraceRecordType { mark, measurement }

class PerfTraceRecord {
  const PerfTraceRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.recordedAt,
    required this.sessionElapsedMs,
    this.durationMs,
    this.payload,
    required this.source,
  });

  final int id;
  final PerfTraceRecordType type;
  final String name;
  final DateTime recordedAt;
  final double sessionElapsedMs;
  final double? durationMs;
  final Map<String, Object?>? payload;
  final String source;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'name': name,
      'recorded_at': recordedAt.toIso8601String(),
      'session_elapsed_ms': sessionElapsedMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (payload != null) 'payload': payload,
      'source': source,
    };
  }
}

class PerfTraceSummary {
  const PerfTraceSummary({
    required this.sessionStartedAt,
    required this.sessionElapsedMs,
    required this.totalEvents,
    required this.marksCount,
    required this.measurementsCount,
    required this.latestMeasurementMs,
    required this.averageMeasurementMs,
    required this.maxMeasurementMs,
    required this.firebaseForwardingEnabled,
  });

  final DateTime sessionStartedAt;
  final double sessionElapsedMs;
  final int totalEvents;
  final int marksCount;
  final int measurementsCount;
  final double latestMeasurementMs;
  final double averageMeasurementMs;
  final double maxMeasurementMs;
  final bool firebaseForwardingEnabled;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session_started_at': sessionStartedAt.toIso8601String(),
      'session_elapsed_ms': sessionElapsedMs,
      'total_events': totalEvents,
      'marks_count': marksCount,
      'measurements_count': measurementsCount,
      'latest_measurement_ms': latestMeasurementMs,
      'average_measurement_ms': averageMeasurementMs,
      'max_measurement_ms': maxMeasurementMs,
      'firebase_forwarding_enabled': firebaseForwardingEnabled,
    };
  }
}

class _ActivePerfTrace {
  const _ActivePerfTrace({required this.firebaseTrace});

  final Future<Trace?>? firebaseTrace;
}

class _FirebasePerfTraceBackend {
  Future<void> syncCollectionState() async {
    if (!AppEnv.enableFirebaseSync || !isFirebaseReady) {
      return;
    }
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      AppEnv.enableFirebasePerformance,
    );
  }

  Future<Trace?> startTrace(
    String name, {
    Map<String, Object?>? payload,
  }) async {
    if (!_isEnabled) {
      return null;
    }
    final trace = FirebasePerformance.instance.newTrace(
      _normalizeTraceName(name),
    );
    _applyPayloadAsAttributes(trace, payload);
    await trace.start();
    return trace;
  }

  Future<void> stopTrace(
    Future<Trace?>? traceFuture, {
    required double durationMs,
    Map<String, Object?>? payload,
  }) async {
    if (!_isEnabled || traceFuture == null) {
      return;
    }
    final trace = await traceFuture;
    if (trace == null) {
      return;
    }
    trace.setMetric('duration_ms', durationMs.round());
    _applyPayloadAsAttributes(trace, payload);
    await trace.stop();
  }

  bool get _isEnabled =>
      AppEnv.enableFirebasePerformance &&
      AppEnv.enableFirebaseSync &&
      isFirebaseReady;

  void _applyPayloadAsAttributes(Trace trace, Map<String, Object?>? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    var attributesWritten = 0;
    for (final entry in payload.entries) {
      if (attributesWritten >= 5) {
        break;
      }
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final normalizedKey = _normalizeAttributeKey(entry.key);
      if (normalizedKey.isEmpty) {
        continue;
      }
      final normalizedValue = value.toString();
      if (normalizedValue.isEmpty) {
        continue;
      }
      trace.putAttribute(
        normalizedKey,
        normalizedValue.length > 100
            ? normalizedValue.substring(0, 100)
            : normalizedValue,
      );
      attributesWritten += 1;
    }
  }

  String _normalizeTraceName(String value) {
    final normalized = value.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_./-]'),
      '_',
    );
    if (normalized.isEmpty) {
      return 'perf_trace';
    }
    return normalized.length > 90 ? normalized.substring(0, 90) : normalized;
  }

  String _normalizeAttributeKey(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.length > 32 ? normalized.substring(0, 32) : normalized;
  }
}
