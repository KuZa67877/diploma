import 'wellbeing_mood.dart';

class WellbeingEntry {
  final DateTime date;
  final WellbeingMood mood;
  final List<String> tags;
  final String? note;
  final int? stressNow;
  final int? fatigue;
  final int? wellness;

  const WellbeingEntry({
    required this.date,
    required this.mood,
    required this.tags,
    required this.note,
    this.stressNow,
    this.fatigue,
    this.wellness,
  });

  WellbeingEntry copyWith({
    DateTime? date,
    WellbeingMood? mood,
    List<String>? tags,
    String? note,
    bool clearNote = false,
    int? stressNow,
    bool clearStressNow = false,
    int? fatigue,
    bool clearFatigue = false,
    int? wellness,
    bool clearWellness = false,
  }) {
    return WellbeingEntry(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      note: clearNote ? null : note ?? this.note,
      stressNow: clearStressNow ? null : stressNow ?? this.stressNow,
      fatigue: clearFatigue ? null : fatigue ?? this.fatigue,
      wellness: clearWellness ? null : wellness ?? this.wellness,
    );
  }
}
