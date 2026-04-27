import 'package:equatable/equatable.dart';

class HealthScoreDriver extends Equatable {
  final String id;
  final double sourceScore;
  final double effectiveScore;
  final bool inversed;
  final double rawWeight;
  final double normalizedWeight;
  final double confidence;
  final double contribution;

  const HealthScoreDriver({
    required this.id,
    required this.sourceScore,
    required this.effectiveScore,
    required this.inversed,
    required this.rawWeight,
    required this.normalizedWeight,
    required this.confidence,
    required this.contribution,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_score': sourceScore,
      'effective_score': effectiveScore,
      'inversed': inversed,
      'raw_weight': rawWeight,
      'normalized_weight': normalizedWeight,
      'confidence': confidence,
      'contribution': contribution,
    };
  }

  @override
  List<Object> get props => [
    id,
    sourceScore,
    effectiveScore,
    inversed,
    rawWeight,
    normalizedWeight,
    confidence,
    contribution,
  ];
}
