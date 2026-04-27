import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/wellbeing/domain/services/healthscore_base_component_service.dart';

void main() {
  group('HealthScoreBaseComponentService', () {
    const service = HealthScoreBaseComponentService();

    test('returns null score when no core profile values are present', () {
      final score = service.estimateScore(
        systolic: null,
        diastolic: null,
        glucose: null,
        temperatureC: null,
        heightCm: null,
        weightKg: null,
      );
      final confidence = service.estimateConfidence(
        systolic: null,
        diastolic: null,
        glucose: null,
        temperatureC: null,
        heightCm: null,
        weightKg: null,
      );

      expect(score, isNull);
      expect(confidence, 0.0);
    });

    test('reduces score when vitals are abnormal', () {
      final healthy = service.estimateScore(
        systolic: 118,
        diastolic: 76,
        glucose: 92,
        temperatureC: 36.6,
        heightCm: 178,
        weightKg: 74,
      );
      final abnormal = service.estimateScore(
        systolic: 150,
        diastolic: 95,
        glucose: 190,
        temperatureC: 38.3,
        heightCm: 178,
        weightKg: 98,
      );

      expect(healthy, isNotNull);
      expect(abnormal, isNotNull);
      expect(abnormal!, lessThan(healthy!));
    });

    test('confidence reflects number of available core metrics', () {
      final partial = service.estimateConfidence(
        systolic: 120,
        diastolic: null,
        glucose: null,
        temperatureC: null,
        heightCm: null,
        weightKg: null,
      );
      final full = service.estimateConfidence(
        systolic: 120,
        diastolic: 80,
        glucose: 95,
        temperatureC: 36.6,
        heightCm: 175,
        weightKg: 70,
      );

      expect(partial, closeTo(0.2, 1e-9));
      expect(full, 1.0);
    });
  });
}
