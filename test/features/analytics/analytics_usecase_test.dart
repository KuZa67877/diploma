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
  group('GetAnalyticsData', () {
    test('returns data on success', () async {
      final useCase = GetAnalyticsData(_FakeSuccessRepository());

      final result = await useCase(const AnalyticsParams(filterId: 'week'));

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (data) => data.filters.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetAnalyticsData(_FakeFailureRepository());

      final result = await useCase(const AnalyticsParams(filterId: 'week'));

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });
}
