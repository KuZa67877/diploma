import 'package:equatable/equatable.dart';
import 'dashboard_insight.dart';
import 'dashboard_metric.dart';

class DashboardSummary extends Equatable {
  final String greetingKey;
  final String userName;
  final int healthScore;
  final String status;
  final DashboardInsight insight;
  final List<DashboardMetric> metrics;

  const DashboardSummary({
    required this.greetingKey,
    required this.userName,
    required this.healthScore,
    required this.status,
    required this.insight,
    required this.metrics,
  });

  @override
  List<Object> get props => [
        greetingKey,
        userName,
        healthScore,
        status,
        insight,
        metrics,
      ];
}
