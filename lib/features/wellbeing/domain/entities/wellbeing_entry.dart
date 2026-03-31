import 'wellbeing_mood.dart';

class WellbeingEntry {
  final DateTime date;
  final WellbeingMood mood;
  final List<String> tags;
  final String? note;

  const WellbeingEntry({
    required this.date,
    required this.mood,
    required this.tags,
    required this.note,
  });

  WellbeingEntry copyWith({
    DateTime? date,
    WellbeingMood? mood,
    List<String>? tags,
    String? note,
    bool clearNote = false,
  }) {
    return WellbeingEntry(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      note: clearNote ? null : note ?? this.note,
    );
  }
}
