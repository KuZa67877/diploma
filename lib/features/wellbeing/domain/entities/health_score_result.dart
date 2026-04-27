import 'package:equatable/equatable.dart';

import 'health_score_alert.dart';
import 'health_score_band.dart';
import 'health_score_driver.dart';

class HealthScoreResult extends Equatable {
  static const String versionId = 'healthscore-v1';

  final int? score;
  final HealthScoreBand band;
  final double confidence;
  final List<HealthScoreDriver> drivers;
  final List<HealthScoreAlert> alerts;
  final String version;
  final DateTime computedAt;
  final Map<String, dynamic> inputQuality;

  const HealthScoreResult({
    required this.score,
    required this.band,
    required this.confidence,
    required this.drivers,
    required this.alerts,
    required this.version,
    required this.computedAt,
    required this.inputQuality,
  });

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'band': band.code,
      'confidence': confidence,
      'drivers': drivers
          .map((driver) => driver.toJson())
          .toList(growable: false),
      'alerts': alerts.map((alert) => alert.toJson()).toList(growable: false),
      'version': version,
      'computed_at': computedAt.toUtc().toIso8601String(),
      'input_quality': inputQuality,
    };
  }

  @override
  List<Object?> get props => [
    score,
    band,
    confidence,
    drivers,
    alerts,
    version,
    computedAt,
    inputQuality,
  ];
}
