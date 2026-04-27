import '../entities/health_score_alert.dart';
import '../entities/health_score_band.dart';
import '../entities/health_score_driver.dart';
import '../entities/health_score_input.dart';
import '../entities/health_score_result.dart';

class HealthScoreCalculatorService {
  static const double _wBase = 0.35;
  static const double _wSleep = 0.25;
  static const double _wStressInv = 0.15;
  static const double _wAnomalyInv = 0.15;
  static const double _wBaselineInv = 0.10;

  const HealthScoreCalculatorService();

  HealthScoreResult calculate(HealthScoreInput input) {
    final computedAt = input.computedAt.toUtc();
    final components = <_HealthScoreComponent>[
      _buildComponent(
        id: 'base',
        score: input.baseScore,
        confidence: input.baseConfidence,
        rawWeight: _wBase,
      ),
      _buildComponent(
        id: 'sleep',
        score: input.sleepScore,
        confidence: input.sleepConfidence,
        rawWeight: _wSleep,
      ),
      _buildComponent(
        id: 'stress',
        score: input.stressScore,
        confidence: input.stressConfidence,
        rawWeight: _wStressInv,
        inversed: true,
      ),
      _buildComponent(
        id: 'anomaly',
        score: input.anomalyScore,
        confidence: input.anomalyConfidence,
        rawWeight: _wAnomalyInv,
        inversed: true,
      ),
      _buildComponent(
        id: 'baseline_deviation',
        score: input.baselineDeviationScore,
        confidence: input.baselineDeviationConfidence,
        rawWeight: _wBaselineInv,
        inversed: true,
      ),
    ];

    final available = components
        .where((component) => component.effectiveScore != null)
        .toList(growable: false);
    final missing = components
        .where((component) => component.effectiveScore == null)
        .map((component) => component.id)
        .toList(growable: false);
    final rawWeightsAvailable = available.fold<double>(
      0,
      (sum, component) => sum + component.rawWeight,
    );
    final completeness = rawWeightsAvailable.clamp(0.0, 1.0);

    if (available.isEmpty || rawWeightsAvailable <= 0) {
      final confidence = 0.0;
      return HealthScoreResult(
        score: null,
        band: HealthScoreBand.noAccess,
        confidence: confidence,
        drivers: const [],
        alerts: _buildAlerts(
          input: input,
          completeness: completeness,
          confidence: confidence,
        ),
        version: HealthScoreResult.versionId,
        computedAt: computedAt,
        inputQuality: _buildInputQuality(
          completeness: completeness,
          confidence: confidence,
          available: const [],
          missing: missing,
        ),
      );
    }

    var rawScore = 0.0;
    var qualityWeighted = 0.0;
    final drivers = <HealthScoreDriver>[];

    for (final component in available) {
      final normalizedWeight = component.rawWeight / rawWeightsAvailable;
      final componentQuality = _normalizeConfidence(component.confidence);
      final effectiveScore = component.effectiveScore!;
      final sourceScore = component.sourceScore!;
      final contribution = effectiveScore * normalizedWeight;
      rawScore += contribution;
      qualityWeighted += componentQuality * normalizedWeight;
      drivers.add(
        HealthScoreDriver(
          id: component.id,
          sourceScore: sourceScore,
          effectiveScore: effectiveScore,
          inversed: component.inversed,
          rawWeight: component.rawWeight,
          normalizedWeight: normalizedWeight,
          confidence: componentQuality,
          contribution: contribution,
        ),
      );
    }

    final score = rawScore.clamp(0.0, 100.0).round().clamp(0, 100);
    final confidence = (qualityWeighted * completeness).clamp(0.0, 1.0);
    final band = _bandForScore(score);
    final availableIds = available
        .map((component) => component.id)
        .toList(growable: false);

    return HealthScoreResult(
      score: score,
      band: band,
      confidence: confidence,
      drivers: List.unmodifiable(drivers),
      alerts: _buildAlerts(
        input: input,
        completeness: completeness,
        confidence: confidence,
      ),
      version: HealthScoreResult.versionId,
      computedAt: computedAt,
      inputQuality: _buildInputQuality(
        completeness: completeness,
        confidence: confidence,
        available: availableIds,
        missing: missing,
      ),
    );
  }

  _HealthScoreComponent _buildComponent({
    required String id,
    required double? score,
    required double? confidence,
    required double rawWeight,
    bool inversed = false,
  }) {
    final normalizedScore = _normalizeScore(score);
    if (normalizedScore == null) {
      return _HealthScoreComponent(
        id: id,
        sourceScore: null,
        effectiveScore: null,
        confidence: confidence,
        rawWeight: rawWeight,
        inversed: inversed,
      );
    }

    final effectiveScore = inversed
        ? (100.0 - normalizedScore).clamp(0.0, 100.0)
        : normalizedScore;

    return _HealthScoreComponent(
      id: id,
      sourceScore: normalizedScore,
      effectiveScore: effectiveScore.toDouble(),
      confidence: confidence,
      rawWeight: rawWeight,
      inversed: inversed,
    );
  }

  List<HealthScoreAlert> _buildAlerts({
    required HealthScoreInput input,
    required double completeness,
    required double confidence,
  }) {
    final alerts = <HealthScoreAlert>[];

    if (completeness < 0.6) {
      alerts.add(
        const HealthScoreAlert(
          code: 'low_data_completeness',
          severity: 'warning',
          message: 'Not enough available components for a stable score.',
        ),
      );
    }
    if (confidence < 0.5) {
      alerts.add(
        const HealthScoreAlert(
          code: 'low_confidence',
          severity: 'warning',
          message: 'The confidence level of the score is low.',
        ),
      );
    }

    final sleepScore = _normalizeScore(input.sleepScore);
    if (sleepScore != null && sleepScore < 60) {
      alerts.add(
        const HealthScoreAlert(
          code: 'sleep_low',
          severity: 'info',
          message: 'Sleep score is below the healthy threshold.',
        ),
      );
    }

    final stressScore = _normalizeScore(input.stressScore);
    if (stressScore != null && stressScore >= 70) {
      alerts.add(
        const HealthScoreAlert(
          code: 'stress_high',
          severity: 'warning',
          message: 'Stress score is elevated.',
        ),
      );
    }

    final anomalyScore = _normalizeScore(input.anomalyScore);
    if (anomalyScore != null && anomalyScore >= 60) {
      alerts.add(
        const HealthScoreAlert(
          code: 'anomaly_high',
          severity: 'warning',
          message: 'Physiology anomaly score is elevated.',
        ),
      );
    }

    final baselineDeviationScore = _normalizeScore(
      input.baselineDeviationScore,
    );
    if (baselineDeviationScore != null && baselineDeviationScore >= 60) {
      alerts.add(
        const HealthScoreAlert(
          code: 'baseline_deviation_high',
          severity: 'warning',
          message: 'Deviation from baseline is elevated.',
        ),
      );
    }

    return List.unmodifiable(alerts);
  }

  Map<String, dynamic> _buildInputQuality({
    required double completeness,
    required double confidence,
    required List<String> available,
    required List<String> missing,
  }) {
    return {
      'completeness': completeness,
      'confidence': confidence,
      'available_components': List.unmodifiable(available),
      'missing_components': List.unmodifiable(missing),
      'available_count': available.length,
      'missing_count': missing.length,
    };
  }

  HealthScoreBand _bandForScore(int score) {
    if (score >= 80) {
      return HealthScoreBand.green;
    }
    if (score >= 60) {
      return HealthScoreBand.yellow;
    }
    if (score >= 40) {
      return HealthScoreBand.orange;
    }
    return HealthScoreBand.red;
  }

  double? _normalizeScore(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return value.clamp(0.0, 100.0).toDouble();
  }

  double _normalizeConfidence(double? value) {
    if (value == null || !value.isFinite) {
      return 0.0;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }
}

class _HealthScoreComponent {
  final String id;
  final double? sourceScore;
  final double? effectiveScore;
  final double? confidence;
  final double rawWeight;
  final bool inversed;

  const _HealthScoreComponent({
    required this.id,
    required this.sourceScore,
    required this.effectiveScore,
    required this.confidence,
    required this.rawWeight,
    required this.inversed,
  });
}
