import 'package:equatable/equatable.dart';

import '../../../health_data/domain/entities/health_date_range.dart';

enum AiDateRangePreset { today, last3Days, last7Days, last14Days, custom }

class AiDateRangeSelection extends Equatable {
  final AiDateRangePreset preset;
  final DateTime start;
  final DateTime end;

  const AiDateRangeSelection({
    required this.preset,
    required this.start,
    required this.end,
  });

  factory AiDateRangeSelection.today({DateTime? now}) {
    final current = now ?? DateTime.now();
    return AiDateRangeSelection(
      preset: AiDateRangePreset.today,
      start: _startOfDay(current),
      end: current,
    );
  }

  factory AiDateRangeSelection.last3Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    return AiDateRangeSelection(
      preset: AiDateRangePreset.last3Days,
      start: _startOfDay(current.subtract(const Duration(days: 2))),
      end: current,
    );
  }

  factory AiDateRangeSelection.last7Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    return AiDateRangeSelection(
      preset: AiDateRangePreset.last7Days,
      start: _startOfDay(current.subtract(const Duration(days: 6))),
      end: current,
    );
  }

  factory AiDateRangeSelection.last14Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    return AiDateRangeSelection(
      preset: AiDateRangePreset.last14Days,
      start: _startOfDay(current.subtract(const Duration(days: 13))),
      end: current,
    );
  }

  factory AiDateRangeSelection.custom({
    required DateTime start,
    required DateTime end,
  }) {
    return AiDateRangeSelection(
      preset: AiDateRangePreset.custom,
      start: _startOfDay(start),
      end: _endOfDay(end),
    );
  }

  HealthDateRange toHealthDateRange() => HealthDateRange(start: start, end: end);

  bool get isCustom => preset == AiDateRangePreset.custom;

  AiDateRangeSelection copyWith({
    AiDateRangePreset? preset,
    DateTime? start,
    DateTime? end,
  }) {
    return AiDateRangeSelection(
      preset: preset ?? this.preset,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  @override
  List<Object?> get props => [preset, start, end];
}
