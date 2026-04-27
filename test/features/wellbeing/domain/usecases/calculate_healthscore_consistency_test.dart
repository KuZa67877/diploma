import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/dashboard/data/datasources/health_model_output_remote_data_source.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/health_score_input.dart';
import 'package:medi_ai/features/wellbeing/domain/services/healthscore_calculator_service.dart';
import 'package:medi_ai/features/wellbeing/domain/usecases/calculate_healthscore.dart';

void main() {
  group('CalculateHealthScore consistency', () {
    final usecase = CalculateHealthScore(const HealthScoreCalculatorService());
    final now = DateTime.utc(2026, 4, 27, 19, 0);

    test(
      'returns the same result for dashboard-like and profile-like inputs',
      () {
        final dashboardInput = HealthScoreInput(
          baseScore: 78,
          sleepScore: 73,
          stressScore: 66,
          anomalyScore: 52,
          baselineDeviationScore: 44,
          baseConfidence: 0.7,
          sleepConfidence: 0.82,
          stressConfidence: 0.74,
          anomalyConfidence: 0.68,
          baselineDeviationConfidence: 0.63,
          computedAt: now,
        );
        final dashboardResult = usecase(dashboardInput);

        final latestOutputs = <String, HealthModelOutputRecord>{
          'sleep_quality': _record(
            modelId: 'sleep_quality',
            score: 73,
            confidence: 0.82,
            windowEnd: now,
          ),
          'stress_score_v1': _record(
            modelId: 'stress_score_v1',
            score: 66,
            confidence: 0.74,
            windowEnd: now,
          ),
          'personal_physiology_anomaly_v1': _record(
            modelId: 'personal_physiology_anomaly_v1',
            score: 52,
            confidence: 0.68,
            windowEnd: now,
          ),
          'baseline_forecast_v1': _record(
            modelId: 'baseline_forecast_v1',
            score: 44,
            confidence: 0.63,
            windowEnd: now,
          ),
        };
        final profileInput = HealthScoreInput(
          baseScore: 78,
          sleepScore: latestOutputs['sleep_quality']?.score,
          stressScore: latestOutputs['stress_score_v1']?.score,
          anomalyScore: latestOutputs['personal_physiology_anomaly_v1']?.score,
          baselineDeviationScore: latestOutputs['baseline_forecast_v1']?.score,
          baseConfidence: 0.7,
          sleepConfidence: latestOutputs['sleep_quality']?.confidence,
          stressConfidence: latestOutputs['stress_score_v1']?.confidence,
          anomalyConfidence:
              latestOutputs['personal_physiology_anomaly_v1']?.confidence,
          baselineDeviationConfidence:
              latestOutputs['baseline_forecast_v1']?.confidence,
          computedAt: latestOutputs.values
              .map((item) => item.windowEnd)
              .reduce((a, b) => a.isAfter(b) ? a : b),
        );
        final profileResult = usecase(profileInput);

        expect(profileResult.score, dashboardResult.score);
        expect(profileResult.band, dashboardResult.band);
        expect(
          profileResult.confidence,
          closeTo(dashboardResult.confidence, 1e-9),
        );
        expect(
          profileResult.alerts
              .map((alert) => alert.code)
              .toList(growable: false),
          dashboardResult.alerts
              .map((alert) => alert.code)
              .toList(growable: false),
        );
      },
    );
  });
}

HealthModelOutputRecord _record({
  required String modelId,
  required double score,
  required double confidence,
  required DateTime windowEnd,
}) {
  return HealthModelOutputRecord(
    modelId: modelId,
    modelVersion: 'v-test',
    windowStart: windowEnd.subtract(const Duration(hours: 24)),
    windowEnd: windowEnd,
    score: score,
    confidence: confidence,
    status: 'ready',
    source: 'test',
    reason: 'ok',
    reasonCodes: const [],
    dataQuality: const {},
    features: const {},
  );
}
