import 'package:equatable/equatable.dart';

class RiskFactorInsight extends Equatable {
  final String code;
  final String label;
  final double contribution;

  const RiskFactorInsight({
    required this.code,
    required this.label,
    required this.contribution,
  });

  @override
  List<Object> get props => [code, label, contribution];
}
