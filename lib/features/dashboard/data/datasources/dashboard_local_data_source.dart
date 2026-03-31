import '../models/dashboard_insight_model.dart';
import '../models/dashboard_metric_model.dart';
import '../models/dashboard_summary_model.dart';

abstract class DashboardLocalDataSource {
  Future<DashboardSummaryModel> getSummary();
}

class DashboardLocalDataSourceImpl implements DashboardLocalDataSource {
  @override
  Future<DashboardSummaryModel> getSummary() async {
    final hour = DateTime.now().hour;
    final greetingKey = hour < 12
        ? 'goodMorning'
        : hour < 18
        ? 'goodAfternoon'
        : 'goodEvening';

    final metrics = const [
      DashboardMetricModel(
        id: 'heart',
        labelKey: 'heartRate',
        value: '72',
        unit: 'bpm',
        trend: 'stable',
        data: [68, 72, 75, 71, 69, 72, 74, 72],
      ),
      DashboardMetricModel(
        id: 'sleep',
        labelKey: 'sleep',
        value: '7.5',
        unit: 'hrs',
        trend: 'up',
        data: [6.5, 7, 6.8, 7.2, 7.5, 7.3, 7.5, 7.5],
      ),
      DashboardMetricModel(
        id: 'steps',
        labelKey: 'activity',
        value: '8432',
        unit: 'steps',
        trend: 'down',
        data: [9200, 8500, 7800, 8100, 9000, 8432, 7500, 8432],
      ),
    ];

    return DashboardSummaryModel(
      greetingKey: greetingKey,
      userName: 'User',
      healthScore: 78,
      status: 'stable',
      insight: const DashboardInsightModel(
        titleKey: 'aiInsight',
        descKey: 'sleepImproved',
      ),
      metrics: metrics,
    );
  }
}
