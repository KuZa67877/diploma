import 'package:flutter/material.dart';
import '../widgets/mini_chart.dart';

class DashboardMetricUiModel {
  final String id;
  final IconData icon;
  final String labelKey;
  final String value;
  final String unit;
  final ChartTrend trend;
  final List<double> data;

  const DashboardMetricUiModel({
    required this.id,
    required this.icon,
    required this.labelKey,
    required this.value,
    required this.unit,
    required this.trend,
    required this.data,
  });
}

class DashboardInsightUiModel {
  final String titleKey;
  final String descKey;

  const DashboardInsightUiModel({
    required this.titleKey,
    required this.descKey,
  });
}

class DashboardViewData {
  final String greetingKey;
  final String userName;
  final int healthScore;
  final String status;
  final DashboardInsightUiModel insight;
  final List<DashboardMetricUiModel> metrics;

  const DashboardViewData({
    required this.greetingKey,
    required this.userName,
    required this.healthScore,
    required this.status,
    required this.insight,
    required this.metrics,
  });
}
