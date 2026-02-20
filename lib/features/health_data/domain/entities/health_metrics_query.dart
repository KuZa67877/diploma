import 'health_date_range.dart';
import 'health_metric_type.dart';

/// Параметры выборки метрик здоровья.
class HealthMetricsQuery {
  /// Диапазон дат.
  final HealthDateRange range;

  /// Фильтр по типам метрик. Пустой список означает все типы.
  final List<HealthMetricType> types;

  /// Фильтр по источнику. Если `null`, используются все источники.
  final String? sourceId;

  /// Учитывать только подключенные источники.
  final bool onlyConnectedSources;

  /// Создает параметры выборки метрик.
  const HealthMetricsQuery({
    required this.range,
    this.types = const [],
    this.sourceId,
    this.onlyConnectedSources = true,
  });
}
