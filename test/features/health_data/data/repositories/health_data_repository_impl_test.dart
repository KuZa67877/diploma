import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/health_data/data/datasources/google_fit_data_source.dart';
import 'package:medi_ai/features/health_data/data/datasources/health_data_local_data_source.dart';
import 'package:medi_ai/features/health_data/data/datasources/health_data_remote_data_source.dart';
import 'package:medi_ai/features/health_data/data/datasources/health_kit_data_source.dart';
import 'package:medi_ai/features/health_data/data/models/health_data_source_model.dart';
import 'package:medi_ai/features/health_data/data/models/health_metric_sample_model.dart';
import 'package:medi_ai/features/health_data/data/repositories/health_data_repository_impl.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_date_range.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';

void main() {
  group('HealthDataRepositoryImpl.syncConnectedSources', () {
    test('uses full 30-day window when cache is empty', () async {
      final now = DateTime.utc(2026, 4, 29, 12);
      final local = _FakeLocalDataSource(
        sources: [_appleSource()],
        connectedSourceIds: {'apple_health'},
      );
      final apple = _FakeHealthKitDataSource();
      final repository = HealthDataRepositoryImpl(
        localDataSource: local,
        remoteDataSource: _FakeRemoteDataSource(),
        healthKitDataSource: apple,
        googleFitDataSource: _FakeGoogleFitDataSource(),
        nowProvider: () => now,
      );

      final result = await repository.syncConnectedSources();

      final failure = result.fold((failure) => failure, (_) => null);
      expect(failure, isNull);
      expect(apple.lastRange, isNotNull);
      expect(apple.lastRange!.end, now);
      expect(apple.lastRange!.start, now.subtract(const Duration(days: 30)));
    });

    test('uses incremental lookback near latest cached sample', () async {
      final now = DateTime.utc(2026, 4, 29, 12);
      final latestEnd = DateTime.utc(2026, 4, 28, 7);
      final local = _FakeLocalDataSource(
        sources: [_appleSource()],
        connectedSourceIds: {'apple_health'},
        cachedExternalSamples: [
          HealthMetricSampleModel(
            id: 'sleep_1',
            type: HealthMetricType.sleepAsleep,
            value: 420,
            unit: 'MIN',
            timestamp: latestEnd,
            intervalStart: latestEnd.subtract(const Duration(hours: 7)),
            intervalEnd: latestEnd,
            sourceId: 'apple_health',
          ),
        ],
      );
      final apple = _FakeHealthKitDataSource();
      final repository = HealthDataRepositoryImpl(
        localDataSource: local,
        remoteDataSource: _FakeRemoteDataSource(),
        healthKitDataSource: apple,
        googleFitDataSource: _FakeGoogleFitDataSource(),
        nowProvider: () => now,
      );

      final result = await repository.syncConnectedSources();

      final failure = result.fold((failure) => failure, (_) => null);
      expect(failure, isNull);
      expect(apple.lastRange, isNotNull);
      expect(
        apple.lastRange!.start,
        latestEnd.subtract(const Duration(days: 3)),
      );
      expect(apple.lastRange!.end, now);
    });
  });
}

HealthDataSourceModel _appleSource() => const HealthDataSourceModel(
  id: 'apple_health',
  name: 'Apple Health',
  description: 'Apple Health',
  type: HealthDataSourceType.appleHealth,
  iconKey: 'apple_health',
  supportedMetrics: [],
  isConnected: true,
  isAvailable: true,
);

class _FakeLocalDataSource implements HealthDataLocalDataSource {
  final List<HealthDataSourceModel> sources;
  final Set<String> connectedSourceIds;
  List<HealthMetricSampleModel> cachedExternalSamples;

  _FakeLocalDataSource({
    required this.sources,
    required this.connectedSourceIds,
    List<HealthMetricSampleModel>? cachedExternalSamples,
  }) : cachedExternalSamples =
           cachedExternalSamples ?? <HealthMetricSampleModel>[];

  @override
  Future<void> clearUserScopedCache() async {}

  @override
  Future<Set<String>> getConnectedSourceIds() async => connectedSourceIds;

  @override
  Future<List<HealthMetricSampleModel>> getCachedExternalSamples() async =>
      cachedExternalSamples;

  @override
  Future<List<HealthMetricSampleModel>> getSamples() async => const [];

  @override
  Future<List<HealthDataSourceModel>> getSources() async => sources;

  @override
  Future<void> saveCachedExternalSamples(
    List<HealthMetricSampleModel> samples,
  ) async {
    cachedExternalSamples = samples;
  }

  @override
  Future<void> setSourceConnection(String sourceId, bool isConnected) async {}
}

class _FakeRemoteDataSource implements HealthDataRemoteDataSource {
  HealthRemoteSnapshot snapshot = const HealthRemoteSnapshot(
    connectedSourceIds: {},
    cachedSamples: [],
  );

  @override
  Future<HealthRemoteSnapshot> getSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(HealthRemoteSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _FakeHealthKitDataSource implements HealthKitDataSource {
  HealthDateRange? lastRange;

  @override
  bool get isAvailable => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<HealthMetricSampleModel>> getSamples({
    required HealthDateRange range,
    List<HealthMetricType> types = const [],
  }) async {
    lastRange = range;
    return const [];
  }
}

class _FakeGoogleFitDataSource implements GoogleFitDataSource {
  @override
  bool get isAvailable => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<HealthMetricSampleModel>> getSamples({
    required HealthDateRange range,
    List<HealthMetricType> types = const [],
  }) async {
    return const [];
  }
}
