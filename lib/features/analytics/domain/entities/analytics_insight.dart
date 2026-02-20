import 'package:equatable/equatable.dart';

class AnalyticsInsight extends Equatable {
  final String type;
  final String titleKey;
  final String descKey;
  final String severity;

  const AnalyticsInsight({
    required this.type,
    required this.titleKey,
    required this.descKey,
    required this.severity,
  });

  @override
  List<Object> get props => [type, titleKey, descKey, severity];
}
