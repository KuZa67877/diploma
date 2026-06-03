import 'dart:async';

typedef PerfProbeListener = void Function(PerfProbeEvent event);

class PerfProbe {
  PerfProbe._();

  static final Stopwatch _session = Stopwatch()..start();
  static final Map<String, List<_PerfMeasurement>> _measurements =
      <String, List<_PerfMeasurement>>{};
  static final List<_PerfMark> _marks = <_PerfMark>[];
  static final List<PerfProbeListener> _listeners = <PerfProbeListener>[];
  static int _nextTraceId = 0;

  static void reset() {
    _session
      ..reset()
      ..start();
    _measurements.clear();
    _marks.clear();
    _nextTraceId = 0;
  }

  static void addListener(PerfProbeListener listener) {
    if (_listeners.contains(listener)) {
      return;
    }
    _listeners.add(listener);
  }

  static void removeListener(PerfProbeListener listener) {
    _listeners.remove(listener);
  }

  static void mark(String name, {Map<String, Object?>? payload}) {
    final event = PerfMarkEvent(
      name: name,
      sessionElapsedMicros: _session.elapsedMicroseconds,
      payload: payload,
    );
    _marks.add(
      _PerfMark(
        name: name,
        elapsedMicros: event.sessionElapsedMicros,
        payload: payload,
      ),
    );
    _notify(event);
  }

  static T measureSync<T>(
    String name,
    T Function() action, {
    Map<String, Object?>? payload,
  }) {
    final traceId = ++_nextTraceId;
    _notify(
      PerfMeasurementStartedEvent(
        traceId: traceId,
        name: name,
        sessionElapsedMicros: _session.elapsedMicroseconds,
        payload: payload,
      ),
    );
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      _record(
        traceId: traceId,
        name: name,
        elapsedMicros: stopwatch.elapsedMicroseconds,
        payload: payload,
      );
    }
  }

  static Future<T> measureAsync<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object?>? payload,
  }) async {
    final traceId = ++_nextTraceId;
    _notify(
      PerfMeasurementStartedEvent(
        traceId: traceId,
        name: name,
        sessionElapsedMicros: _session.elapsedMicroseconds,
        payload: payload,
      ),
    );
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _record(
        traceId: traceId,
        name: name,
        elapsedMicros: stopwatch.elapsedMicroseconds,
        payload: payload,
      );
    }
  }

  static Map<String, Object?> snapshot() {
    final measurements = <String, Object?>{};
    for (final entry in _measurements.entries) {
      final values = entry.value
          .map((item) => item.elapsedMicros / 1000.0)
          .toList(growable: false);
      final count = values.length;
      final totalMs = values.fold<double>(0, (sum, value) => sum + value);
      final averageMs = count == 0 ? 0.0 : totalMs / count;
      final maxMs = count == 0
          ? 0.0
          : values.reduce((current, next) => current > next ? current : next);
      measurements[entry.key] = <String, Object?>{
        'count': count,
        'latest_ms': values.isEmpty ? 0.0 : values.last,
        'average_ms': averageMs,
        'max_ms': maxMs,
        'samples_ms': values,
        'payloads': entry.value
            .map((item) => item.payload)
            .whereType<Map<String, Object?>>()
            .toList(growable: false),
      };
    }

    return <String, Object?>{
      'session_elapsed_ms': _session.elapsedMicroseconds / 1000.0,
      'marks': _marks
          .map(
            (item) => <String, Object?>{
              'name': item.name,
              'elapsed_ms': item.elapsedMicros / 1000.0,
              if (item.payload != null) 'payload': item.payload,
            },
          )
          .toList(growable: false),
      'measurements': measurements,
    };
  }

  static void _record({
    required int traceId,
    required String name,
    required int elapsedMicros,
    Map<String, Object?>? payload,
  }) {
    final bucket = _measurements.putIfAbsent(name, () => <_PerfMeasurement>[]);
    bucket.add(
      _PerfMeasurement(elapsedMicros: elapsedMicros, payload: payload),
    );
    _notify(
      PerfMeasurementCompletedEvent(
        traceId: traceId,
        name: name,
        durationMicros: elapsedMicros,
        sessionElapsedMicros: _session.elapsedMicroseconds,
        payload: payload,
      ),
    );
  }

  static void _notify(PerfProbeEvent event) {
    for (final listener in List<PerfProbeListener>.from(_listeners)) {
      listener(event);
    }
  }
}

abstract class PerfProbeEvent {
  final String name;
  final int sessionElapsedMicros;
  final Map<String, Object?>? payload;

  const PerfProbeEvent({
    required this.name,
    required this.sessionElapsedMicros,
    required this.payload,
  });
}

class PerfMarkEvent extends PerfProbeEvent {
  const PerfMarkEvent({
    required super.name,
    required super.sessionElapsedMicros,
    super.payload,
  });
}

class PerfMeasurementStartedEvent extends PerfProbeEvent {
  final int traceId;

  const PerfMeasurementStartedEvent({
    required this.traceId,
    required super.name,
    required super.sessionElapsedMicros,
    super.payload,
  });
}

class PerfMeasurementCompletedEvent extends PerfProbeEvent {
  final int traceId;
  final int durationMicros;

  const PerfMeasurementCompletedEvent({
    required this.traceId,
    required this.durationMicros,
    required super.name,
    required super.sessionElapsedMicros,
    super.payload,
  });
}

class _PerfMeasurement {
  final int elapsedMicros;
  final Map<String, Object?>? payload;

  const _PerfMeasurement({required this.elapsedMicros, required this.payload});
}

class _PerfMark {
  final String name;
  final int elapsedMicros;
  final Map<String, Object?>? payload;

  const _PerfMark({
    required this.name,
    required this.elapsedMicros,
    required this.payload,
  });
}
