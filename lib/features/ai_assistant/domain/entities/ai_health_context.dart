import 'package:equatable/equatable.dart';

class AiHealthContext extends Equatable {
  final DateTime from;
  final DateTime to;
  final double? healthScore;
  final Map<String, dynamic> summaries;
  final List<String> warnings;
  final List<String> missingData;

  const AiHealthContext({
    required this.from,
    required this.to,
    required this.healthScore,
    required this.summaries,
    required this.warnings,
    required this.missingData,
  });

  @override
  List<Object?> get props => [
    from,
    to,
    healthScore,
    summaries,
    warnings,
    missingData,
  ];
}
