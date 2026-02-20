import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_insight_model.dart';
import 'dashboard_metric_model.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.greetingKey,
    required super.userName,
    required super.healthScore,
    required super.status,
    required super.insight,
    required super.metrics,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final metrics = (json['metrics'] as List<dynamic>?)
            ?.map((item) => DashboardMetricModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <DashboardMetricModel>[];

    final insight = json['insight'] is Map<String, dynamic>
        ? DashboardInsightModel.fromJson(
            json['insight'] as Map<String, dynamic>,
          )
        : const DashboardInsightModel(
            titleKey: 'aiInsight',
            descKey: 'sleepImproved',
          );

    return DashboardSummaryModel(
      greetingKey: json['greetingKey']?.toString() ?? 'goodMorning',
      userName: json['userName']?.toString() ?? '',
      healthScore: json['healthScore'] is int
          ? json['healthScore'] as int
          : int.tryParse('${json['healthScore']}') ?? 0,
      status: json['status']?.toString() ?? 'stable',
      insight: insight,
      metrics: metrics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'greetingKey': greetingKey,
      'userName': userName,
      'healthScore': healthScore,
      'status': status,
      'insight': (insight as DashboardInsightModel).toJson(),
      'metrics': metrics
          .map((item) => (item as DashboardMetricModel).toJson())
          .toList(),
    };
  }
}
