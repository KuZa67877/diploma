import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dashboard_insight_model.dart';
import '../models/dashboard_metric_model.dart';
import '../models/dashboard_summary_model.dart';

abstract class DashboardLocalDataSource {
  Future<DashboardSummaryModel> getSummary();
}

class DashboardLocalDataSourceImpl implements DashboardLocalDataSource {
  static const String _assetPath = 'assets/data/dashboard.json';

  @override
  Future<DashboardSummaryModel> getSummary() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final hour = DateTime.now().hour;
    final greetingKey = hour < 12
        ? 'goodMorning'
        : hour < 18
            ? 'goodAfternoon'
            : 'goodEvening';

    final user = decoded['user'] as Map<String, dynamic>? ?? const {};
    final summary = decoded['summary'] as Map<String, dynamic>? ?? const {};
    final insightJson = summary['insight'] as Map<String, dynamic>? ?? const {};

    final metrics = (decoded['metrics'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => DashboardMetricModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    return DashboardSummaryModel(
      greetingKey: greetingKey,
      userName: user['name']?.toString() ?? '',
      healthScore: summary['healthScore'] is int
          ? summary['healthScore'] as int
          : int.tryParse('${summary['healthScore']}') ?? 0,
      status: summary['status']?.toString() ?? 'stable',
      insight: DashboardInsightModel.fromJson(insightJson),
      metrics: metrics,
    );
  }
}
