import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_insight.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_metric.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:medi_ai/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/presentation/bloc/dashboard_cubit.dart';

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
  group('DashboardCubit', () {
    test('loads data and emits loaded state', () async {
      final cubit = DashboardCubit(
        getDashboardSummary: GetDashboardSummary(_FakeSuccessRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(loaded: (data) => data.metrics.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = DashboardCubit(
        getDashboardSummary: GetDashboardSummary(_FakeFailureRepository()),
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
