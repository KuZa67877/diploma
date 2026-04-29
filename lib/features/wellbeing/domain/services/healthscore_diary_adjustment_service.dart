import '../entities/diary_health_adjustment.dart';
import '../entities/wellbeing_entry.dart';
import '../entities/wellbeing_mood.dart';

double clampDouble(double value, double min, double max) {
  if (!value.isFinite) {
    return min;
  }
  return value.clamp(min, max).toDouble();
}

double? weightedMeanAvailable(List<double?> values, List<double> weights) {
  if (values.length != weights.length) {
    return null;
  }

  var weightedSum = 0.0;
  var totalWeight = 0.0;

  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    final weight = weights[index];
    if (value == null || !value.isFinite || !weight.isFinite || weight <= 0) {
      continue;
    }
    weightedSum += value * weight;
    totalWeight += weight;
  }

  if (totalWeight <= 0 || !weightedSum.isFinite) {
    return null;
  }

  return clampDouble(weightedSum / totalWeight, 0, 100);
}

double? moodToScore(WellbeingMood? mood) {
  return switch (mood) {
    WellbeingMood.veryLow => 20,
    WellbeingMood.low => 40,
    WellbeingMood.neutral => 60,
    WellbeingMood.good => 80,
    WellbeingMood.great => 95,
    null => null,
  };
}

double? numericScaleToStressScore(int? value) {
  if (value == null) return null;
  final normalized = value.clamp(1, 5);
  return clampDouble(100 - 25.0 * (normalized - 1), 0, 100);
}

double? numericScaleToFatigueScore(int? value) {
  if (value == null) return null;
  final normalized = value.clamp(1, 5);
  return clampDouble(100 - 25.0 * (normalized - 1), 0, 100);
}

double? numericScaleToWellnessScore(int? value) {
  if (value == null) return null;
  final normalized = value.clamp(1, 5);
  return clampDouble(25.0 * (normalized - 1), 0, 100);
}

double calculateRecency({required DateTime? entryDate, required DateTime now}) {
  if (entryDate == null) {
    return 0;
  }

  final localEntry = DateTime(
    entryDate.toLocal().year,
    entryDate.toLocal().month,
    entryDate.toLocal().day,
  );
  final localNow = DateTime(
    now.toLocal().year,
    now.toLocal().month,
    now.toLocal().day,
  );
  final dayDifference = localNow.difference(localEntry).inDays;

  if (dayDifference < 0) {
    return 0;
  }
  if (dayDifference == 0) {
    return 1.0;
  }
  if (dayDifference == 1) {
    return 0.6;
  }
  if (dayDifference == 2) {
    return 0.3;
  }
  return 0.0;
}

class HealthScoreDiaryAdjustmentService {
  static const List<String> _negativeTags = <String>[
    'illness',
    'pain',
    'fever',
    'headache',
    'insomnia',
    'alcohol',
    'anxiety',
    'sick',
    'bad_sleep',
    'high_stress',
  ];
  static const List<String> _positiveTags = <String>[
    'workout',
    'walk',
    'meditation',
    'good_sleep',
    'rest',
    'recovery',
    'relax',
  ];

  const HealthScoreDiaryAdjustmentService();

  DiaryHealthAdjustment calculate({
    required WellbeingEntry? entry,
    required DateTime now,
  }) {
    if (entry == null) {
      return const DiaryHealthAdjustment.none(
        reasons: <String>[
          'Дневник не повлиял на оценку: нет актуальной записи за последние два дня.',
        ],
      );
    }

    final moodScore = moodToScore(entry.mood);
    final stressScore = numericScaleToStressScore(entry.stressNow);
    final fatigueScore = numericScaleToFatigueScore(entry.fatigue);
    final wellnessScore = numericScaleToWellnessScore(entry.wellness);
    final diaryScore = weightedMeanAvailable(
      <double?>[moodScore, wellnessScore, stressScore, fatigueScore],
      const <double>[0.35, 0.25, 0.20, 0.20],
    );

    final availableFields = <Object?>[
      moodScore,
      stressScore,
      fatigueScore,
      wellnessScore,
    ].where((value) => value != null).length;
    final diaryCompleteness = clampDouble(availableFields / 4.0, 0, 1);
    final recency = calculateRecency(entryDate: entry.date, now: now);
    final diaryConfidence = clampDouble(diaryCompleteness * recency, 0, 1);
    final tagDelta = _calculateTagDelta(entry.tags);
    final adjustedDiaryScore = diaryScore == null
        ? null
        : clampDouble(diaryScore + (tagDelta ?? 0), 0, 100);

    if (diaryScore == null) {
      return const DiaryHealthAdjustment.none(
        reasons: <String>[
          'Дневник не повлиял на оценку: в записи нет структурированных полей.',
        ],
      );
    }

    if (diaryConfidence == 0) {
      return DiaryHealthAdjustment(
        diaryScore: adjustedDiaryScore,
        confidence: 0,
        delta: 0,
        tagDelta: tagDelta,
        reasons: List.unmodifiable(
          _buildZeroConfidenceReasons(entry: entry, recency: recency),
        ),
      );
    }

    // Diary data is a subjective correction layer over the already computed
    // objective health score. It never replaces physiology-driven components
    // and its effect is intentionally capped to the range [-10; +6].
    final diaryDeviation = adjustedDiaryScore! - 60.0;
    final rawDelta = (diaryDeviation / 40.0) * 10.0;
    final boundedDelta = clampDouble(rawDelta, -10, 6);
    final delta = boundedDelta * diaryConfidence;

    return DiaryHealthAdjustment(
      diaryScore: adjustedDiaryScore,
      confidence: diaryConfidence,
      delta: delta,
      tagDelta: tagDelta,
      reasons: List.unmodifiable(
        _buildReasons(
          entry: entry,
          diaryScore: adjustedDiaryScore,
          tagDelta: tagDelta,
        ),
      ),
    );
  }

  double? _calculateTagDelta(List<String> tags) {
    if (tags.isEmpty) {
      return null;
    }

    var negativeCount = 0;
    var positiveCount = 0;
    for (final tag in tags.map(_normalizeTag)) {
      if (_negativeTags.contains(tag)) {
        negativeCount++;
      }
      if (_positiveTags.contains(tag)) {
        positiveCount++;
      }
    }

    if (negativeCount == 0 && positiveCount == 0) {
      return 0;
    }

    return clampDouble(-3.0 * negativeCount + 1.5 * positiveCount, -6, 3);
  }

  List<String> _buildZeroConfidenceReasons({
    required WellbeingEntry entry,
    required double recency,
  }) {
    if (recency == 0) {
      return const <String>[
        'Дневник не повлиял на оценку: запись старше двух дней.',
      ];
    }

    return const <String>[
      'Дневник не повлиял на оценку: запись слишком неполная для надежной корректировки.',
    ];
  }

  List<String> _buildReasons({
    required WellbeingEntry entry,
    required double diaryScore,
    required double? tagDelta,
  }) {
    final reasons = <String>{};

    switch (entry.mood) {
      case WellbeingMood.veryLow:
      case WellbeingMood.low:
        reasons.add('низкое настроение');
      case WellbeingMood.neutral:
        break;
      case WellbeingMood.good:
      case WellbeingMood.great:
        reasons.add('хорошее настроение');
    }

    final stress = entry.stressNow;
    if (stress != null) {
      if (stress >= 4) {
        reasons.add('высокий стресс');
      } else if (stress <= 2) {
        reasons.add('низкий стресс');
      }
    }

    final fatigue = entry.fatigue;
    if (fatigue != null) {
      if (fatigue >= 4) {
        reasons.add('высокая усталость');
      } else if (fatigue <= 2) {
        reasons.add('низкая усталость');
      }
    }

    final wellness = entry.wellness;
    if (wellness != null) {
      if (wellness <= 2) {
        reasons.add('плохое самочувствие');
      } else if (wellness >= 4) {
        reasons.add('хорошее самочувствие');
      }
    }

    final negativeTags = entry.tags
        .map(_normalizeTag)
        .where(_negativeTags.contains)
        .map(_tagReasonLabel)
        .toSet()
        .toList(growable: false);
    if (negativeTags.isNotEmpty) {
      reasons.add('теги риска: ${negativeTags.join(', ')}');
    }

    final positiveTags = entry.tags
        .map(_normalizeTag)
        .where(_positiveTags.contains)
        .map(_tagReasonLabel)
        .toSet()
        .toList(growable: false);
    if (positiveTags.isNotEmpty) {
      reasons.add('поддерживающие теги: ${positiveTags.join(', ')}');
    }

    if (reasons.isEmpty) {
      if (diaryScore >= 70) {
        reasons.add('дневник отражает хорошее текущее состояние');
      } else if (diaryScore <= 45) {
        reasons.add('дневник отражает сниженное текущее состояние');
      } else {
        reasons.add('дневник близок к нейтральному состоянию');
      }
    }

    if (tagDelta != null &&
        tagDelta.abs() >= 0.1 &&
        negativeTags.isEmpty &&
        positiveTags.isEmpty) {
      reasons.add(
        tagDelta < 0
            ? 'негативные теги усилили снижение оценки'
            : 'позитивные теги слегка поддержали оценку',
      );
    }

    return reasons.toList(growable: false);
  }

  String _normalizeTag(String tag) {
    return tag.trim().toLowerCase();
  }

  String _tagReasonLabel(String tag) {
    return switch (tag) {
      'illness' => 'болезнь',
      'pain' => 'боль',
      'fever' => 'температура',
      'headache' => 'головная боль',
      'insomnia' => 'бессонница',
      'alcohol' => 'алкоголь',
      'anxiety' => 'тревога',
      'sick' => 'недомогание',
      'bad_sleep' => 'плохой сон',
      'high_stress' => 'сильный стресс',
      'workout' => 'тренировка',
      'walk' => 'прогулка',
      'meditation' => 'медитация',
      'good_sleep' => 'хороший сон',
      'rest' => 'отдых',
      'recovery' => 'восстановление',
      'relax' => 'расслабление',
      _ => tag,
    };
  }
}
