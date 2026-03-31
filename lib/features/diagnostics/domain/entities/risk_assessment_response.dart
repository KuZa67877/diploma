import 'package:equatable/equatable.dart';
import 'risk_factor_insight.dart';

enum RiskLevel { low, medium, high }

enum RecommendedAction {
  selfMonitoring,
  scheduleConsultation,
  urgentMedicalAttention,
}

class RiskAssessmentResponse extends Equatable {
  final double riskScore;
  final RiskLevel riskLevel;
  final RecommendedAction recommendedAction;
  final List<RiskFactorInsight> topFactors;
  final String disclaimer;
  final String modelVersion;
  final DateTime inferenceTimestamp;

  const RiskAssessmentResponse({
    required this.riskScore,
    required this.riskLevel,
    required this.recommendedAction,
    required this.topFactors,
    required this.disclaimer,
    required this.modelVersion,
    required this.inferenceTimestamp,
  });

  @override
  List<Object> get props => [
    riskScore,
    riskLevel,
    recommendedAction,
    topFactors,
    disclaimer,
    modelVersion,
    inferenceTimestamp,
  ];
}
