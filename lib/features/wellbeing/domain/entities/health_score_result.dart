import 'package:equatable/equatable.dart';

import 'diary_health_adjustment.dart';
import 'health_score_alert.dart';
import 'health_score_band.dart';
import 'health_score_driver.dart';

class HealthScoreResult extends Equatable {
  static const String versionId = 'healthscore-v1';

  final int? score;
  final int? objectiveScore;
  final HealthScoreBand band;
  final double confidence;
  final List<HealthScoreDriver> drivers;
  final List<HealthScoreAlert> alerts;
  final String version;
  final DateTime computedAt;
  final Map<String, dynamic> inputQuality;
  final DiaryHealthAdjustment diaryAdjustment;

  const HealthScoreResult({
    required this.score,
    required this.objectiveScore,
    required this.band,
    required this.confidence,
    required this.drivers,
    required this.alerts,
    required this.version,
    required this.computedAt,
    required this.inputQuality,
    this.diaryAdjustment = const DiaryHealthAdjustment.none(),
  });

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'objective_score': objectiveScore,
      'band': band.code,
      'confidence': confidence,
      'drivers': drivers
          .map((driver) => driver.toJson())
          .toList(growable: false),
      'alerts': alerts.map((alert) => alert.toJson()).toList(growable: false),
      'version': version,
      'computed_at': computedAt.toUtc().toIso8601String(),
      'input_quality': inputQuality,
      'diary_adjustment': diaryAdjustment.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    score,
    objectiveScore,
    band,
    confidence,
    drivers,
    alerts,
    version,
    computedAt,
    inputQuality,
    diaryAdjustment,
  ];
}
