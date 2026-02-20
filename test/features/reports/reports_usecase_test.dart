import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/reports/domain/entities/report_export_option.dart';
import 'package:medi_ai/features/reports/domain/entities/report_filter_option.dart';
import 'package:medi_ai/features/reports/domain/entities/report_item.dart';
import 'package:medi_ai/features/reports/domain/entities/reports_data.dart';
import 'package:medi_ai/features/reports/domain/repositories/reports_repository.dart';
import 'package:medi_ai/features/reports/domain/usecases/get_reports_data.dart';

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

void main() {
  group('GetReportsData', () {
    test('returns data on success', () async {
      final useCase = GetReportsData(_FakeSuccessRepository());

      final result = await useCase(const ReportsParams(filterId: 'all'));

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (data) => data.reports.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetReportsData(_FakeFailureRepository());

      final result = await useCase(const ReportsParams(filterId: 'all'));

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
