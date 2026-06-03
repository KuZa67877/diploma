import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medi_ai/core/perf/perf_probe.dart';
import 'package:medi_ai/features/dashboard/data/services/baseline_forecast_inference_model.dart';
import 'package:medi_ai/features/dashboard/data/services/harvard_activity_recommendation_model.dart';
import 'package:medi_ai/features/dashboard/data/services/physiology_anomaly_inference_model.dart';
import 'package:medi_ai/features/dashboard/data/services/sleep_quality_inference_model.dart';
import 'package:medi_ai/features/dashboard/data/services/stress_inference_model.dart';
import 'package:medi_ai/main.dart' as app;

import 'src/perf_sample_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('collects mobile performance metrics', (tester) async {
    PerfProbe.mark('integration_test.started');
    app.main();

    final report = <String, Object?>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'scenarios': <String, Object?>{},
    };

    final authVisible = await _waitForVisible(
      tester,
      find.text('Sign Up'),
      timeout: const Duration(seconds: 25),
      throwOnTimeout: false,
    );

    if (authVisible) {
      report['scenarios'] = <String, Object?>{
        ...(report['scenarios'] as Map<String, Object?>),
        'auth_to_home': await _measureScenario(
          tester,
          binding: binding,
          name: 'auth_to_home',
          action: () async {
            await tester.tap(find.text('Sign Up'));
            await tester.pump(const Duration(milliseconds: 250));
            await tester.enterText(
              find.byType(EditableText).at(0),
              'perf_${DateTime.now().millisecondsSinceEpoch}@example.com',
            );
            await tester.enterText(
              find.byType(EditableText).at(1),
              'secret123',
            );
            await tester.tap(find.text('Create Account'));
            await tester.pump(const Duration(milliseconds: 250));
            await _waitForVisible(tester, find.text('Basic health data'));
            await tester.tap(find.text('Continue'));
            await tester.pump(const Duration(milliseconds: 250));
            await _waitForVisible(tester, find.text('Health Data Sources'));
            await tester.tap(find.text('Skip for now'));
          },
          completionTarget: find.text('Health Score'),
        ),
      };
    } else {
      await _waitForVisible(tester, find.text('Health Score'));
    }

    report['scenarios'] = <String, Object?>{
      ...(report['scenarios'] as Map<String, Object?>),
      'analytics_open': await _measureScenario(
        tester,
        binding: binding,
        name: 'analytics_open',
        action: () async {
          await tester.tap(find.text('Analytics'));
        },
        completionTarget: find.text('Health Analytics'),
      ),
      'export_open': await _measureScenario(
        tester,
        binding: binding,
        name: 'export_open',
        action: () async {
          await _waitForVisible(tester, find.text('Export'));
          await tester.tap(find.text('Export'));
        },
        completionTarget: find.text('Preview'),
      ),
    };

    report['model_benchmarks'] = await _runModelBenchmarks();
    report['perf_probe'] = PerfProbe.snapshot();
    PerfProbe.mark('integration_test.completed');
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!.addAll(<String, dynamic>{'summary': report});
  });
}

Future<Map<String, Object?>> _measureScenario(
  WidgetTester tester, {
  required IntegrationTestWidgetsFlutterBinding binding,
  required String name,
  required Future<void> Function() action,
  required Finder completionTarget,
}) async {
  final recorder = _FrameTimingRecorder()..start();
  final stopwatch = Stopwatch()..start();
  await binding.traceAction(() async {
    await action();
    await tester.pump(const Duration(milliseconds: 150));
    await _waitForVisible(tester, completionTarget);
  }, reportKey: '${name}_timeline');
  stopwatch.stop();
  final frames = recorder.stop();
  return <String, Object?>{
    'name': name,
    'elapsed_ms': stopwatch.elapsedMilliseconds,
    'frame_metrics': frames,
  };
}

Future<Map<String, Object?>> _runModelBenchmarks() async {
  PerfProbe.mark('model_benchmark.started');
  final now = DateTime.utc(2026, 5, 25, 12, 0);
  final profile = buildPerfProfile();
  final samples = buildPerfSamples(now);

  final harvardModel = HarvardActivityRecommendationModel();
  final sleepModel = SleepQualityInferenceModel();
  final stressModel = StressInferenceModel();
  final physiologyModel = PhysiologyAnomalyInferenceModel();
  final baselineModel = BaselineForecastInferenceModel();

  final harvardResult = await harvardModel.infer(
    profile: profile,
    samples: samples,
    now: now,
  );
  final sleepResult = await sleepModel.infer(samples: samples, now: now);
  final stressResult = await stressModel.infer(
    samples: samples,
    now: now,
    recentSleepScore: sleepResult.score,
    fallbackHealthScore: 80,
  );
  final physiologyResult = physiologyModel.inferSync(
    samples: samples,
    now: now,
  );
  final baselineResult = baselineModel.inferSync(samples: samples, now: now);
  PerfProbe.mark('model_benchmark.completed');

  final measurements =
      (PerfProbe.snapshot()['measurements'] as Map<String, Object?>?) ??
      const <String, Object?>{};

  return <String, Object?>{
    'sample_count': samples.length,
    'harvard': <String, Object?>{
      'activity_class': harvardResult.activityClass.name,
      'model_version': harvardResult.modelVersion,
      'timing': measurements['model.harvard.infer'],
    },
    'sleep_quality': <String, Object?>{
      'insufficient_data': sleepResult.insufficientData,
      'score': sleepResult.score,
      'model_version': sleepResult.modelVersion,
      'timing': measurements['model.sleep_quality.infer'],
    },
    'stress': <String, Object?>{
      'insufficient_data': stressResult.insufficientData,
      'status': stressResult.status,
      'model_version': stressResult.modelVersion,
      'timing': measurements['model.stress.infer_async'],
    },
    'physiology_anomaly': <String, Object?>{
      'insufficient_data': physiologyResult.insufficientData,
      'status': physiologyResult.status,
      'model_version': physiologyResult.modelVersion,
      'timing': measurements['model.physiology_anomaly.infer_sync'],
    },
    'baseline_forecast': <String, Object?>{
      'insufficient_data': baselineResult.insufficientData,
      'status': baselineResult.status,
      'model_version': baselineResult.modelVersion,
      'timing': measurements['model.baseline_forecast.infer_sync'],
    },
  };
}

Future<bool> _waitForVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration step = const Duration(milliseconds: 100),
  bool throwOnTimeout = true,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }
  if (!throwOnTimeout) {
    return false;
  }
  throw TestFailure('Timed out waiting for $finder');
}

class _FrameTimingRecorder {
  final List<FrameTiming> _timings = <FrameTiming>[];

  void start() {
    _timings.clear();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
  }

  Map<String, Object?> stop() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    if (_timings.isEmpty) {
      return const <String, Object?>{
        'frame_count': 0,
        'average_build_ms': 0.0,
        'average_raster_ms': 0.0,
        'average_total_ms': 0.0,
        'max_build_ms': 0.0,
        'max_raster_ms': 0.0,
        'jank_frame_count': 0,
      };
    }

    final buildMs = _timings
        .map((timing) => timing.buildDuration.inMicroseconds / 1000.0)
        .toList(growable: false);
    final rasterMs = _timings
        .map((timing) => timing.rasterDuration.inMicroseconds / 1000.0)
        .toList(growable: false);
    final totalMs = _timings
        .map((timing) => timing.totalSpan.inMicroseconds / 1000.0)
        .toList(growable: false);

    return <String, Object?>{
      'frame_count': _timings.length,
      'average_build_ms': _average(buildMs),
      'average_raster_ms': _average(rasterMs),
      'average_total_ms': _average(totalMs),
      'max_build_ms': _max(buildMs),
      'max_raster_ms': _max(rasterMs),
      'jank_frame_count': totalMs.where((value) => value > 16.67).length,
    };
  }

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    final total = values.fold<double>(0.0, (sum, value) => sum + value);
    return total / values.length;
  }

  double _max(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    return values.reduce((left, right) => left > right ? left : right);
  }
}
