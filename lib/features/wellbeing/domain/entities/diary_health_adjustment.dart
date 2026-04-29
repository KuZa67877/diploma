import 'package:equatable/equatable.dart';

class DiaryHealthAdjustment extends Equatable {
  final double? diaryScore;
  final double confidence;
  final double delta;
  final double? tagDelta;
  final List<String> reasons;

  const DiaryHealthAdjustment({
    required this.diaryScore,
    required this.confidence,
    required this.delta,
    required this.tagDelta,
    required this.reasons,
  });

  const DiaryHealthAdjustment.none({
    this.diaryScore,
    this.confidence = 0,
    this.delta = 0,
    this.tagDelta,
    this.reasons = const <String>[],
  });

  bool get hasEffect => delta.abs() > 1e-6;

  Map<String, dynamic> toJson() {
    return {
      'diary_score': diaryScore,
      'confidence': confidence,
      'delta': delta,
      'tag_delta': tagDelta,
      'reasons': List.unmodifiable(reasons),
    };
  }

  @override
  List<Object?> get props => [diaryScore, confidence, delta, tagDelta, reasons];
}
