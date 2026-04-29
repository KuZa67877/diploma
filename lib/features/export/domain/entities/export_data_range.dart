import 'package:equatable/equatable.dart';
import '../../../health_data/domain/entities/health_date_range.dart';

enum ExportRangePreset { today, yesterday, last7Days, last30Days, custom }

class ExportDataRange extends Equatable {
  final ExportRangePreset preset;
  final DateTime start;
  final DateTime end;

  const ExportDataRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  factory ExportDataRange.today({DateTime? now}) {
    final current = now ?? DateTime.now();
    return ExportDataRange(
      preset: ExportRangePreset.today,
      start: _startOfDay(current),
      end: current,
    );
  }

  factory ExportDataRange.yesterday({DateTime? now}) {
    final current = now ?? DateTime.now();
    final yesterday = current.subtract(const Duration(days: 1));
    return ExportDataRange(
      preset: ExportRangePreset.yesterday,
      start: _startOfDay(yesterday),
      end: _endOfDay(yesterday),
    );
  }

  factory ExportDataRange.last7Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    return ExportDataRange(
      preset: ExportRangePreset.last7Days,
      start: _startOfDay(current.subtract(const Duration(days: 6))),
      end: current,
    );
  }

  factory ExportDataRange.last30Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    return ExportDataRange(
      preset: ExportRangePreset.last30Days,
      start: _startOfDay(current.subtract(const Duration(days: 29))),
      end: current,
    );
  }

  factory ExportDataRange.custom({
    required DateTime start,
    required DateTime end,
  }) {
    return ExportDataRange(
      preset: ExportRangePreset.custom,
      start: _startOfDay(start),
      end: _endOfDay(end),
    );
  }

  HealthDateRange toHealthDateRange() =>
      HealthDateRange(start: start, end: end);

  bool get isCustom => preset == ExportRangePreset.custom;

  ExportDataRange copyWith({
    ExportRangePreset? preset,
    DateTime? start,
    DateTime? end,
  }) {
    return ExportDataRange(
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
  List<Object> get props => [preset, start, end];
}
