import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/reports/domain/entities/report_export_option.dart';
import 'package:medi_ai/features/reports/domain/entities/report_filter_option.dart';
import 'package:medi_ai/features/reports/domain/entities/report_item.dart';
import 'package:medi_ai/features/reports/domain/entities/reports_data.dart';
import 'package:medi_ai/features/reports/domain/repositories/reports_repository.dart';
import 'package:medi_ai/features/reports/domain/usecases/get_reports_data.dart';
import 'package:medi_ai/features/reports/presentation/bloc/reports_cubit.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metrics_query.dart';
import 'package:medi_ai/features/health_data/domain/repositories/health_data_repository.dart';
import 'package:medi_ai/features/health_data/domain/usecases/get_health_metrics.dart';

class _FakeSuccessRepository implements ReportsRepository {
  @override
  Future<Either<Failure, ReportsData>> getReportsData(String filterId) async {
    return Right(
      ReportsData(
        filters: const [ReportFilterOption(id: 'all', labelKey: 'all')],
        selectedFilterId: filterId,
        exportOptions: const [
          ReportExportOption(
            id: 'pdf',
            labelKey: 'PDF',
            useLocalization: false,
            iconKey: 'fileDown',
            colorKey: 'primary',
          ),
        ],
        reports: const [
          ReportItem(
            id: 1,
            titleKey: 'weeklyHealthSummary',
            date: 'Dec 8 - Dec 14, 2024',
            type: 'summary',
            status: 'ready',
          ),
        ],
      ),
    );
  }
}

class _FakeFailureRepository implements ReportsRepository {
  @override
  Future<Either<Failure, ReportsData>> getReportsData(String filterId) async {
    return const Left(CacheFailure());
  }
}

class _FakeHealthRepository implements HealthDataRepository {
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
    return const Right([
      HealthDataSource(
        id: 'local',
        name: 'Local',
        description: 'Local',
        type: HealthDataSourceType.local,
        iconKey: 'local',
        supportedMetrics: [HealthMetricType.steps],
        isConnected: true,
        isAvailable: true,
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<HealthMetricSample>>> getMetrics(
    HealthMetricsQuery query,
  ) async {
    return const Right([]);
  }
}

void main() {
  group('ReportsCubit', () {
    test('loads data and emits loaded state', () async {
      final cubit = ReportsCubit(
        getReportsData: GetReportsData(_FakeSuccessRepository()),
        getHealthMetrics: GetHealthMetrics(_FakeHealthRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(loaded: (data) => data.reports.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = ReportsCubit(
        getReportsData: GetReportsData(_FakeFailureRepository()),
        getHealthMetrics: GetHealthMetrics(_FakeHealthRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(error: (message) => message.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });
  });
}
