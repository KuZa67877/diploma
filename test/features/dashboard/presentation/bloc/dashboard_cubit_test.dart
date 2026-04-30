import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_insight.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_metric.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:medi_ai/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:medi_ai/features/dashboard/presentation/models/dashboard_ui_models.dart';

void main() {
  group('DashboardCubit', () {
    test('uses temporary score when canonical score is unavailable', () async {
      final repository = _FakeDashboardRepository(
        result: Right(
          DashboardSummary(
            greetingKey: 'goodMorning',
            userName: 'Alex',
            healthScore: 0,
            status: 'computed_from_models',
            insight: const DashboardInsight(
              titleKey: 'aiInsight',
              descKey: 'sleepImproved',
            ),
            metrics: const <DashboardMetric>[
              DashboardMetric(
                id: 'heart',
                labelKey: 'heartRate',
                value: '72',
                unit: 'bpm',
                trend: 'stable',
                data: <double>[71, 72],
              ),
            ],
            dataSnapshot: DashboardDataSnapshot(
              connectedSources: 2,
              wearableSampleCount: 24,
              latestWearableSampleAt: DateTime.now().toUtc(),
            ),
            modelResults: const DashboardModelResults(
              activity: DashboardActivityModelResult(
                activityClass: 'running_7_met',
                confidence: 0.92,
                insufficientData: false,
                recommendationKeys: <String>['modelRec1'],
                modelVersion: 'v1',
              ),
              sleep: DashboardSleepModelResult(
                score: 80,
                confidence: 0.8,
                insufficientData: false,
                status: 'good',
                reason: 'ok',
                sleepMinutes: 450,
                sleepDurationDeviationMinutes: 30,
              ),
              stress: DashboardStressModelResult(
                score: 20,
                confidence: 0.7,
                insufficientData: false,
                status: 'stable',
                reason: 'ok',
                heartRate: 72,
                hrvSdnn: 48,
                hrvRmssd: 42,
                sleepHoursDelta: 0,
                activitySteps1h: 1200,
                reasons: <DashboardModelReason>[],
              ),
              baseline: DashboardBaselineModelResult(
                score: 30,
                confidence: 0.65,
                insufficientData: false,
                status: 'stable',
                reason: 'ok',
                mainReasons: <String>['within_expected_range'],
                deviations: <DashboardBaselineDeviation>[],
              ),
              recovery: DashboardRecoveryModelResult(
                score: 10,
                confidence: 0.72,
                insufficientData: false,
                status: 'stable',
                reason: 'ok',
                reasons: <DashboardModelReason>[],
                groups: <DashboardModelGroupScore>[],
              ),
            ),
          ),
        ),
      );
      final cubit = DashboardCubit(
        getDashboardSummary: GetDashboardSummary(repository),
      );

      await cubit.load();

      final data = cubit.state.whenOrNull(loaded: (value) => value);
      expect(data, isNotNull);
      expect(data!.healthScore, 81);
      expect(data.healthScoreIsTemporary, isTrue);
      expect(data.dataStatus, DashboardDataStatusState.upToDate);
      expect(data.scoreState, DashboardScoreState.stable);
      expect(data.showNoDataState, isFalse);
      expect(data.modelCards, hasLength(5));
    });

    test('shows no-data state when there are no connected sources or samples', () async {
      final repository = _FakeDashboardRepository(
        result: Right(
          const DashboardSummary(
            greetingKey: 'goodMorning',
            userName: 'Alex',
            healthScore: 0,
            status: 'no_access',
            insight: DashboardInsight(
              titleKey: 'aiInsight',
              descKey: 'sleepImproved',
            ),
            metrics: <DashboardMetric>[],
          ),
        ),
      );
      final cubit = DashboardCubit(
        getDashboardSummary: GetDashboardSummary(repository),
      );

      await cubit.load();

      final data = cubit.state.whenOrNull(loaded: (value) => value);
      expect(data, isNotNull);
      expect(data!.dataStatus, DashboardDataStatusState.syncRequired);
      expect(data.scoreState, DashboardScoreState.noAccess);
      expect(data.showNoDataState, isTrue);
      expect(data.showInsufficientDataBanner, isTrue);
      expect(data.modelCards, isEmpty);
    });
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  final Either<Failure, DashboardSummary> result;

  _FakeDashboardRepository({required this.result});

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    return result;
  }
}
