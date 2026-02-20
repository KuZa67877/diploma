import '../../domain/entities/dashboard_insight.dart';

class DashboardInsightModel extends DashboardInsight {
  const DashboardInsightModel({
    required super.titleKey,
    required super.descKey,
  });

  factory DashboardInsightModel.fromJson(Map<String, dynamic> json) {
    return DashboardInsightModel(
      titleKey: json['titleKey']?.toString() ?? '',
      descKey: json['descKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titleKey': titleKey,
      'descKey': descKey,
    };
  }
}
