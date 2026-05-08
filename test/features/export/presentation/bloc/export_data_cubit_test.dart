import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/dashboard/data/datasources/health_model_output_remote_data_source.dart';
import 'package:medi_ai/features/export/data/services/ai_prompt_export_builder.dart';
import 'package:medi_ai/features/export/data/services/csv_export_builder.dart';
import 'package:medi_ai/features/export/data/services/health_data_export_mapper.dart';
import 'package:medi_ai/features/export/data/services/historical_model_output_service.dart';
import 'package:medi_ai/features/export/data/services/json_export_builder.dart';
import 'package:medi_ai/features/export/data/services/markdown_export_builder.dart';
import 'package:medi_ai/features/export/data/services/medical_export_builder.dart';
import 'package:medi_ai/features/export/domain/entities/export_format.dart';
import 'package:medi_ai/features/export/presentation/bloc/export_data_cubit.dart';
import 'package:medi_ai/features/health_data/data/models/health_metric_sample_model.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metrics_query.dart';
import 'package:medi_ai/features/health_data/domain/repositories/health_data_repository.dart';
import 'package:medi_ai/features/health_data/domain/usecases/get_health_metrics.dart';
import 'package:medi_ai/features/profile/domain/entities/connected_service.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_data.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_user.dart';
import 'package:medi_ai/features/profile/domain/repositories/profile_repository.dart';
import 'package:medi_ai/features/profile/domain/usecases/get_profile_data.dart';

void main() {
  group('ExportDataCubit', () {
    test('loads metrics into partial preview with stats', () async {
      final cubit = _buildCubit(
        metrics: _sampleMetrics(),
        profileData: _profileData(),
      );

      await cubit.load();

      expect(cubit.state.status, ExportDataStatus.partial);
      expect(cubit.state.recordCount, 4);
      expect(cubit.state.sourceCount, 2);
      expect(cubit.state.previewText, contains('ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:'));
      expect(cubit.state.previewText, contains('Пульс:'));
      expect(cubit.state.missingSections, isNotEmpty);
    });

    test('loads profile data when personal data export is enabled', () async {
      final cubit = _buildCubit(
        metrics: _sampleMetrics(),
        profileData: _profileData(),
      );
      await cubit.load();

      await cubit.toggleIncludePersonalData(true);

      expect(cubit.state.includePersonalData, isTrue);
      expect(cubit.state.previewText, contains('Личные данные:'));
      expect(cubit.state.previewText, contains('Alex Johnson'));
      expect(cubit.state.previewText, contains('alex@example.com'));
    });

    test('builds csv export from prepared payload', () async {
      final cubit = _buildCubit(
        metrics: _sampleMetrics(),
        profileData: _profileData(),
      );
      await cubit.load();

      final csv = cubit.buildExportText(formatOverride: ExportFormat.csv);

      expect(csv, startsWith('date,metric_type,metric_label'));
      expect(csv, contains('"heartRate"'));
      expect(csv, contains('"apple_health"'));
    });
  });
}

ExportDataCubit _buildCubit({
  required List<HealthMetricSample> metrics,
  required ProfileData profileData,
  List<HealthModelOutputRecord> modelOutputs = const <HealthModelOutputRecord>[],
}) {
  return ExportDataCubit(
    getHealthMetrics: GetHealthMetrics(
      _FakeHealthDataRepository(metricsResult: Right(metrics)),
    ),
    getProfileData: GetProfileData(
      _FakeProfileRepository(profileResult: Right(profileData)),
    ),
    historicalModelOutputService: HistoricalModelOutputService(
      remoteDataSource: _FakeModelOutputRemoteDataSource(records: modelOutputs),
    ),
    exportMapper: const HealthDataExportMapper(),
    aiPromptExportBuilder: const AiPromptExportBuilder(),
    medicalExportBuilder: const MedicalExportBuilder(),
    markdownExportBuilder: const MarkdownExportBuilder(),
    jsonExportBuilder: const JsonExportBuilder(),
    csvExportBuilder: const CsvExportBuilder(),
  );
}

List<HealthMetricSample> _sampleMetrics() {
  final now = DateTime.now().toUtc();
  return <HealthMetricSample>[
    HealthMetricSampleModel(
      id: 'hr_1',
      type: HealthMetricType.heartRate,
      value: 72,
      unit: 'bpm',
      timestamp: now.subtract(const Duration(hours: 2)),
      sourceId: 'apple_health',
    ),
    HealthMetricSampleModel(
      id: 'steps_1',
      type: HealthMetricType.steps,
      value: 6800,
      unit: 'count',
      timestamp: now.subtract(const Duration(hours: 1)),
      sourceId: 'apple_health',
    ),
    HealthMetricSampleModel(
      id: 'sleep_1',
      type: HealthMetricType.sleepAsleep,
      value: 420,
      unit: 'MIN',
      timestamp: now.subtract(const Duration(hours: 8)),
      intervalStart: now.subtract(const Duration(hours: 15)),
      intervalEnd: now.subtract(const Duration(hours: 8)),
      sourceId: 'google_fit',
    ),
    HealthMetricSampleModel(
      id: 'weight_1',
      type: HealthMetricType.weight,
      value: 72.4,
      unit: 'kg',
      timestamp: now.subtract(const Duration(days: 1)),
      sourceId: 'google_fit',
    ),
  ];
}

ProfileData _profileData() {
  return const ProfileData(
    user: ProfileUser(
      name: 'Alex Johnson',
      email: 'alex@example.com',
      age: 29,
      sex: 'male',
      heightCm: 178,
      weightKg: 72.4,
      healthScore: 81,
    ),
    services: <ConnectedService>[
      ConnectedService(
        id: 'apple',
        nameKey: 'appleHealth',
        iconKey: 'activity',
        colorKey: 'danger',
        connected: true,
      ),
    ],
  );
}

class _FakeHealthDataRepository implements HealthDataRepository {
  final Either<Failure, List<HealthMetricSample>> metricsResult;

  _FakeHealthDataRepository({required this.metricsResult});

  @override
  Future<Either<Failure, Unit>> connectSource(String sourceId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> disconnectSource(String sourceId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<HealthDataSource>>> getAvailableSources() async {
    return const Right(<HealthDataSource>[]);
  }

  @override
  Future<Either<Failure, List<HealthMetricSample>>> getMetrics(
    HealthMetricsQuery query,
  ) async {
    return metricsResult;
  }

  @override
  Future<Either<Failure, Unit>> syncConnectedSources() async {
    return const Right(unit);
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final Either<Failure, ProfileData> profileResult;

  _FakeProfileRepository({required this.profileResult});

  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    return profileResult;
  }
}

class _FakeModelOutputRemoteDataSource implements HealthModelOutputRemoteDataSource {
  final List<HealthModelOutputRecord> records;

  _FakeModelOutputRemoteDataSource({required this.records});

  @override
  Future<Map<String, HealthModelOutputRecord>> getLatestOutputsByModelIds(
    List<String> modelIds,
  ) async {
    final filtered = records
        .where((record) => modelIds.contains(record.modelId))
        .toList(growable: false);
    final latestByModel = <String, HealthModelOutputRecord>{};
    for (final record in filtered) {
      latestByModel.putIfAbsent(record.modelId, () => record);
    }
    return latestByModel;
  }

  @override
  Future<List<HealthModelOutputRecord>> getOutputsByModelIdsForRange({
    required List<String> modelIds,
    required DateTime start,
    required DateTime end,
  }) async {
    return records
        .where((record) => modelIds.contains(record.modelId))
        .toList(growable: false);
  }

  @override
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs) async {}
}
