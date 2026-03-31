import '../../domain/entities/risk_assessment_request.dart';
import '../../domain/entities/risk_assessment_response.dart';
import '../../domain/entities/risk_factor_insight.dart';

abstract class DiagnosticsLocalDataSource {
  Future<RiskAssessmentResponse> assessRisk(RiskAssessmentRequest request);
}

/// Mock local inference that simulates a triage-oriented risk model.
/// It is intentionally heuristic and should be replaced by a trained model/API.
class DiagnosticsLocalDataSourceImpl implements DiagnosticsLocalDataSource {
  static const _disclaimer =
      'Предварительная оценка риска носит информационный характер и не заменяет решение врача.';

  static const _modelVersion = 'mock-triage-v0.1.0';

  @override
  Future<RiskAssessmentResponse> assessRisk(
    RiskAssessmentRequest request,
  ) async {
    var score = 0.05;
    final factors = <RiskFactorInsight>[];
    final symptoms = request.symptoms.toSet();
    final vitals = request.manualVitals;
    final wearable = request.wearableAggregates;
    final age = request.patientContext.age;

    void addFactor(String code, String label, double delta) {
      score += delta;
      factors.add(
        RiskFactorInsight(code: code, label: label, contribution: delta),
      );
    }

    if (age != null && age >= 60) {
      addFactor('age_60_plus', 'Возраст 60+ лет', 0.08);
    } else if (age != null && age >= 45) {
      addFactor('age_45_plus', 'Возраст 45+ лет', 0.04);
    }

    if (symptoms.contains('chestPain')) {
      addFactor('symptom_chest_pain', 'Боль в груди', 0.28);
    }
    if (symptoms.contains('shortnessOfBreath')) {
      addFactor('symptom_sob', 'Одышка', 0.22);
    }
    if (symptoms.contains('dizziness')) {
      addFactor('symptom_dizziness', 'Головокружение', 0.10);
    }
    if (symptoms.contains('fatigue')) {
      addFactor('symptom_fatigue', 'Выраженная усталость', 0.04);
    }

    final systolic = vitals.systolic;
    if (systolic != null) {
      if (systolic >= 180) {
        addFactor('bp_sys_180', 'Систолическое АД >= 180 мм рт. ст.', 0.32);
      } else if (systolic >= 140) {
        addFactor('bp_sys_140', 'Повышенное систолическое АД', 0.14);
      } else if (systolic < 90) {
        addFactor('bp_sys_low', 'Низкое систолическое АД', 0.18);
      }
    }

    final diastolic = vitals.diastolic;
    if (diastolic != null) {
      if (diastolic >= 120) {
        addFactor('bp_dia_120', 'Диастолическое АД >= 120 мм рт. ст.', 0.24);
      } else if (diastolic >= 90) {
        addFactor('bp_dia_90', 'Повышенное диастолическое АД', 0.10);
      }
    }

    final temp = vitals.temperature;
    if (temp != null && temp >= 38.0) {
      addFactor('temp_fever', 'Повышенная температура тела', 0.06);
    }

    final glucose = vitals.glucose;
    if (glucose != null && glucose >= 200) {
      addFactor(
        'glucose_high',
        'Высокий уровень глюкозы (по введенному значению)',
        0.08,
      );
    }

    final hr = wearable.heartRate;
    if (hr != null) {
      if (hr >= 110) {
        addFactor('hr_high', 'Повышенная ЧСС', 0.18);
      } else if (hr <= 45) {
        addFactor('hr_low', 'Пониженная ЧСС', 0.14);
      }
    }

    final spo2 = wearable.bloodOxygen;
    if (spo2 != null) {
      if (spo2 < 92) {
        addFactor('spo2_critical', 'Низкая сатурация (SpO2 < 92%)', 0.30);
      } else if (spo2 < 95) {
        addFactor('spo2_low', 'Пониженная сатурация', 0.14);
      }
    }

    final sleep = wearable.sleepHours;
    if (sleep != null && sleep < 4) {
      addFactor('sleep_short', 'Короткая продолжительность сна', 0.05);
    }

    final steps = wearable.steps;
    if (steps != null && steps < 1500) {
      addFactor('low_activity', 'Низкая физическая активность', 0.03);
    }

    if (request.missingFlags.values.where((v) => v).length >= 3) {
      addFactor('missing_many', 'Недостаточность входных данных', 0.04);
    }

    final normalizedScore = score.clamp(0.0, 1.0);
    final riskLevel = _riskLevelForScore(normalizedScore);
    final action = _recommendedActionForLevel(riskLevel);
    final topFactors = factors
      ..sort((a, b) => b.contribution.compareTo(a.contribution));

    return RiskAssessmentResponse(
      riskScore: normalizedScore,
      riskLevel: riskLevel,
      recommendedAction: action,
      topFactors: topFactors.take(5).toList(growable: false),
      disclaimer: _disclaimer,
      modelVersion: _modelVersion,
      inferenceTimestamp: DateTime.now().toUtc(),
    );
  }

  RiskLevel _riskLevelForScore(double score) {
    if (score >= 0.66) return RiskLevel.high;
    if (score >= 0.33) return RiskLevel.medium;
    return RiskLevel.low;
  }

  RecommendedAction _recommendedActionForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return RecommendedAction.selfMonitoring;
      case RiskLevel.medium:
        return RecommendedAction.scheduleConsultation;
      case RiskLevel.high:
        return RecommendedAction.urgentMedicalAttention;
    }
  }
}
