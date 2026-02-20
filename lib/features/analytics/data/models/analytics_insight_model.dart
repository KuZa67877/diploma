import '../../domain/entities/analytics_insight.dart';

class AnalyticsInsightModel extends AnalyticsInsight {
  const AnalyticsInsightModel({
    required super.type,
    required super.titleKey,
    required super.descKey,
    required super.severity,
  });

  factory AnalyticsInsightModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsInsightModel(
      type: json['type']?.toString() ?? '',
      titleKey: json['titleKey']?.toString() ?? '',
      descKey: json['descKey']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'titleKey': titleKey,
      'descKey': descKey,
      'severity': severity,
    };
  }
}
