/// Диапазон дат для выборки метрик здоровья.
class HealthDateRange {
  /// Начало диапазона (включительно).
  final DateTime start;

  /// Конец диапазона (включительно).
  final DateTime end;

  /// Создает диапазон дат.
  const HealthDateRange({
    required this.start,
    required this.end,
  });

  /// Проверяет, что дата входит в диапазон.
  bool contains(DateTime value) {
    final isAfterOrEqual = value.isAtSameMomentAs(start) || value.isAfter(start);
    final isBeforeOrEqual = value.isAtSameMomentAs(end) || value.isBefore(end);
    return isAfterOrEqual && isBeforeOrEqual;
  }
}
