import '../../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../domain/entities/export_data_range.dart';

class ExportModelOutputSnapshot {
  final List<HealthModelOutputRecord> records;
  final Map<String, HealthModelOutputRecord> latestByModel;

  const ExportModelOutputSnapshot({
    required this.records,
    required this.latestByModel,
  });

  static const empty = ExportModelOutputSnapshot(
    records: <HealthModelOutputRecord>[],
    latestByModel: <String, HealthModelOutputRecord>{},
  );
}

class HistoricalModelOutputService {
  static const List<String> trackedModelIds = [
    'harvard_activity_recommendation_v1',
    'sleep_quality',
    'stress_score_v1',
    'personal_physiology_anomaly_v1',
    'baseline_forecast_v1',
    'healthscore_v1',
  ];

  final HealthModelOutputRemoteDataSource remoteDataSource;

  const HistoricalModelOutputService({required this.remoteDataSource});

  Future<ExportModelOutputSnapshot> loadForRange(ExportDataRange range) async {
    final records = await remoteDataSource.getOutputsByModelIdsForRange(
      modelIds: trackedModelIds,
      start: range.start,
      end: range.end,
    );
    final latestByModel = <String, HealthModelOutputRecord>{};
    for (final record in records) {
      latestByModel.putIfAbsent(record.modelId, () => record);
    }
    return ExportModelOutputSnapshot(
      records: records,
      latestByModel: latestByModel,
    );
  }
}
