import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/wellbeing_entry.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/wellbeing_mood.dart';
import 'package:medi_ai/features/wellbeing/domain/services/healthscore_diary_adjustment_service.dart';

void main() {
  group('HealthScoreDiaryAdjustmentService', () {
    const service = HealthScoreDiaryAdjustmentService();
    final now = DateTime(2026, 4, 29, 12);

    test(
      'returns zero delta and zero confidence when there is no diary entry',
      () {
        final result = service.calculate(entry: null, now: now);

        expect(result.delta, 0);
        expect(result.confidence, 0);
        expect(result.diaryScore, isNull);
      },
    );

    test('produces a strong negative modifier for a bad entry today', () {
      final result = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.low,
          tags: const <String>[],
          note: null,
          stressNow: 5,
          fatigue: 5,
          wellness: 1,
        ),
        now: now,
      );

      expect(result.diaryScore, closeTo(14, 1e-9));
      expect(result.confidence, 1);
      expect(result.delta, -10);
      expect(result.delta, greaterThanOrEqualTo(-10));
    });

    test('produces a capped positive modifier for a good entry today', () {
      final result = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.great,
          tags: const <String>[],
          note: null,
          stressNow: 1,
          fatigue: 1,
          wellness: 5,
        ),
        now: now,
      );

      expect(result.diaryScore, closeTo(98.25, 1e-9));
      expect(result.confidence, 1);
      expect(result.delta, 6);
      expect(result.delta, lessThanOrEqualTo(6));
    });

    test('reduces confidence for yesterday entry and weakens delta', () {
      final todayResult = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.low,
          tags: const <String>[],
          note: null,
          stressNow: 5,
          fatigue: 5,
          wellness: 1,
        ),
        now: now,
      );
      final yesterdayResult = service.calculate(
        entry: WellbeingEntry(
          date: now.subtract(const Duration(days: 1)),
          mood: WellbeingMood.low,
          tags: const <String>[],
          note: null,
          stressNow: 5,
          fatigue: 5,
          wellness: 1,
        ),
        now: now,
      );

      expect(yesterdayResult.confidence, lessThan(todayResult.confidence));
      expect(yesterdayResult.delta.abs(), lessThan(todayResult.delta.abs()));
      expect(yesterdayResult.delta, closeTo(-6, 1e-9));
    });

    test('does not affect score when entry is older than two days', () {
      final result = service.calculate(
        entry: WellbeingEntry(
          date: now.subtract(const Duration(days: 3)),
          mood: WellbeingMood.good,
          tags: const <String>[],
          note: null,
          stressNow: 2,
          fatigue: 2,
          wellness: 4,
        ),
        now: now,
      );

      expect(result.confidence, 0);
      expect(result.delta, 0);
      expect(result.diaryScore, isNotNull);
    });

    test('handles partial entries without division by zero', () {
      final result = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.good,
          tags: const <String>[],
          note: null,
        ),
        now: now,
      );

      expect(result.diaryScore, 80);
      expect(result.confidence, 0.25);
      expect(result.delta, closeTo(1.25, 1e-9));
    });

    test('clamps negative and positive tag deltas', () {
      final negative = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.neutral,
          tags: const <String>[
            'illness',
            'pain',
            'fever',
            'headache',
            'insomnia',
          ],
          note: null,
        ),
        now: now,
      );
      final positive = service.calculate(
        entry: WellbeingEntry(
          date: now,
          mood: WellbeingMood.neutral,
          tags: const <String>[
            'workout',
            'walk',
            'meditation',
            'good_sleep',
            'rest',
          ],
          note: null,
        ),
        now: now,
      );

      expect(negative.tagDelta, -6);
      expect(positive.tagDelta, 3);
    });
  });
}
