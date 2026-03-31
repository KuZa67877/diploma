import 'package:equatable/equatable.dart';

class WearableAggregates extends Equatable {
  final double? heartRate;
  final int? steps;
  final double? sleepHours;
  final double? bloodOxygen;
  final double? heartRateTrendDelta;
  final int? stepsTrendDelta;
  final double? sleepTrendDelta;

  const WearableAggregates({
    this.heartRate,
    this.steps,
    this.sleepHours,
    this.bloodOxygen,
    this.heartRateTrendDelta,
    this.stepsTrendDelta,
    this.sleepTrendDelta,
  });

  @override
  List<Object?> get props => [
    heartRate,
    steps,
    sleepHours,
    bloodOxygen,
    heartRateTrendDelta,
    stepsTrendDelta,
    sleepTrendDelta,
  ];
}
