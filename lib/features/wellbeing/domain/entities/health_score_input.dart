import 'package:equatable/equatable.dart';

class HealthScoreInput extends Equatable {
  final double? baseScore;
  final double? sleepScore;
  final double? stressScore;
  final double? anomalyScore;
  final double? baselineDeviationScore;
  final double? baseConfidence;
  final double? sleepConfidence;
  final double? stressConfidence;
  final double? anomalyConfidence;
  final double? baselineDeviationConfidence;
  final DateTime computedAt;

  const HealthScoreInput({
    required this.baseScore,
    required this.sleepScore,
    required this.stressScore,
    required this.anomalyScore,
    required this.baselineDeviationScore,
    required this.baseConfidence,
    required this.sleepConfidence,
    required this.stressConfidence,
    required this.anomalyConfidence,
    required this.baselineDeviationConfidence,
    required this.computedAt,
  });

  Map<String, double?> get componentScores => {
    'base': baseScore,
    'sleep': sleepScore,
    'stress': stressScore,
    'anomaly': anomalyScore,
    'baseline_deviation': baselineDeviationScore,
  };

  Map<String, double?> get componentConfidences => {
    'base': baseConfidence,
    'sleep': sleepConfidence,
    'stress': stressConfidence,
    'anomaly': anomalyConfidence,
    'baseline_deviation': baselineDeviationConfidence,
  };

  @override
  List<Object?> get props => [
    baseScore,
    sleepScore,
    stressScore,
    anomalyScore,
    baselineDeviationScore,
    baseConfidence,
    sleepConfidence,
    stressConfidence,
    anomalyConfidence,
    baselineDeviationConfidence,
    computedAt,
  ];
}
