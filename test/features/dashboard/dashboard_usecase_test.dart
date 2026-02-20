import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_insight.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_metric.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:medi_ai/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:medi_ai/core/usecases/usecase.dart';

class _FakeSuccessRepository implements DashboardRepository {
  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    return Right(
      DashboardSummary(
        greetingKey: 'goodMorning',
        userName: 'Alex',
        healthScore: 90,
        status: 'stable',
        insight: const DashboardInsight(
          titleKey: 'aiInsight',
          descKey: 'sleepImproved',
        ),
        metrics: const [
          DashboardMetric(
            id: 'heart',
            labelKey: 'heartRate',
            value: '72',
            unit: 'bpm',
            trend: 'stable',
            data: [70, 72],
          ),
        ],
      ),
    );
  }
}

class _FakeFailureRepository implements DashboardRepository {
  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('GetDashboardSummary', () {
    test('returns summary on success', () async {
      final useCase = GetDashboardSummary(_FakeSuccessRepository());

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (summary) => summary.metrics.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetDashboardSummary(_FakeFailureRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
