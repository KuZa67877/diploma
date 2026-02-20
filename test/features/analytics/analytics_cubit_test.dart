import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/analytics/domain/entities/activity_sample.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_data.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_filter_option.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_insight.dart';
import 'package:medi_ai/features/analytics/domain/entities/heart_rate_sample.dart';
import 'package:medi_ai/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:medi_ai/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:medi_ai/features/analytics/presentation/bloc/analytics_cubit.dart';

class _FakeSuccessRepository implements AnalyticsRepository {
  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(String filterId) async {
    return Right(
      AnalyticsData(
        filters: const [
          AnalyticsFilterOption(id: 'week', labelKey: 'week'),
        ],
        selectedFilterId: filterId,
        heartRate: const [HeartRateSample(hour: 0, bpm: 60)],
        activity: const [ActivitySample(label: 'Mon', steps: 1000)],
        insights: const [
          AnalyticsInsight(
            type: 'info',
            titleKey: 'insight',
            descKey: 'insightDesc',
            severity: 'info',
          ),
        ],
      ),
    );
  }
}

class _FakeFailureRepository implements AnalyticsRepository {
  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(String filterId) async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('AnalyticsCubit', () {
    test('loads data and emits loaded state', () async {
      final cubit = AnalyticsCubit(
        getAnalyticsData: GetAnalyticsData(_FakeSuccessRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(
          loaded: (data) => data.filters.isNotEmpty,
          orElse: () => false,
        ),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = AnalyticsCubit(
        getAnalyticsData: GetAnalyticsData(_FakeFailureRepository()),
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
