import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/health_score_band.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/health_score_input.dart';
import 'package:medi_ai/features/wellbeing/domain/services/healthscore_calculator_service.dart';

void main() {
  group('HealthScoreCalculatorService', () {
    const service = HealthScoreCalculatorService();
    final now = DateTime.utc(2026, 4, 27, 12, 0);

    test(
      'calculates score/confidence with all components and inverse logic',
      () {
        final result = service.calculate(
          HealthScoreInput(
            baseScore: 80,
            sleepScore: 70,
            stressScore: 30,
            anomalyScore: 20,
            baselineDeviationScore: 40,
            baseConfidence: 0.9,
            sleepConfidence: 0.8,
            stressConfidence: 0.7,
            anomalyConfidence: 0.6,
            baselineDeviationConfidence: 0.5,
            computedAt: now,
          ),
        );

        expect(result.score, 74);
        expect(result.band, HealthScoreBand.yellow);
        expect(result.confidence, closeTo(0.76, 1e-9));
        expect(result.alerts, isEmpty);
        expect(result.drivers.length, 5);
        expect(result.inputQuality['completeness'], 1.0);
        expect(result.inputQuality['available_components'], [
          'base',
          'sleep',
          'stress',
          'anomaly',
          'baseline_deviation',
        ]);
      },
    );

    test('normalizes weights on partial input and emits expected alerts', () {
      final result = service.calculate(
        HealthScoreInput(
          baseScore: null,
          sleepScore: 55,
          stressScore: null,
          anomalyScore: null,
          baselineDeviationScore: null,
          baseConfidence: null,
          sleepConfidence: 0.8,
          stressConfidence: null,
          anomalyConfidence: null,
          baselineDeviationConfidence: null,
          computedAt: now,
        ),
      );

      expect(result.score, 55);
      expect(result.band, HealthScoreBand.orange);
      expect(result.confidence, closeTo(0.2, 1e-9));
      expect(result.drivers.length, 1);
      expect(result.drivers.first.id, 'sleep');
      expect(result.drivers.first.normalizedWeight, 1.0);
      expect(result.inputQuality['completeness'], 0.25);
      expect(
        result.alerts.map((alert) => alert.code),
        containsAll(['low_data_completeness', 'low_confidence', 'sleep_low']),
      );
    });

    test('returns no_access when there are no available components', () {
      final result = service.calculate(
        HealthScoreInput(
          baseScore: null,
          sleepScore: null,
          stressScore: null,
          anomalyScore: null,
          baselineDeviationScore: null,
          baseConfidence: null,
          sleepConfidence: null,
          stressConfidence: null,
          anomalyConfidence: null,
          baselineDeviationConfidence: null,
          computedAt: now,
        ),
      );

      expect(result.score, isNull);
      expect(result.band, HealthScoreBand.noAccess);
      expect(result.confidence, 0);
      expect(result.drivers, isEmpty);
      expect(result.inputQuality['completeness'], 0.0);
      expect(result.inputQuality['available_components'], isEmpty);
      expect(
        result.alerts.map((alert) => alert.code),
        containsAll(['low_data_completeness', 'low_confidence']),
      );
    });

    test(
      'reduces score when stress component increases due to inverse branch',
      () {
        final lowStressResult = service.calculate(
          HealthScoreInput(
            baseScore: 80,
            sleepScore: null,
            stressScore: 20,
            anomalyScore: null,
            baselineDeviationScore: null,
            baseConfidence: 1,
            sleepConfidence: null,
            stressConfidence: 1,
            anomalyConfidence: null,
            baselineDeviationConfidence: null,
            computedAt: now,
          ),
        );
        final highStressResult = service.calculate(
          HealthScoreInput(
            baseScore: 80,
            sleepScore: null,
            stressScore: 80,
            anomalyScore: null,
            baselineDeviationScore: null,
            baseConfidence: 1,
            sleepConfidence: null,
            stressConfidence: 1,
            anomalyConfidence: null,
            baselineDeviationConfidence: null,
            computedAt: now,
          ),
        );

        expect(lowStressResult.score, 80);
        expect(highStressResult.score, 62);
        expect(highStressResult.score!, lessThan(lowStressResult.score!));
        expect(
          highStressResult.alerts.map((alert) => alert.code),
          contains('stress_high'),
        );
      },
    );
  });
}
