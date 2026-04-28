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

    final metrics = const <DashboardMetricModel>[];

    return DashboardSummaryModel(
      greetingKey: greetingKey,
      userName: 'User',
      healthScore: 0,
      status: 'no_access',
      insight: const DashboardInsightModel(
        titleKey: 'aiInsight',
        descKey: 'sleepImproved',
      ),
      metrics: metrics,
    );
  }
}
