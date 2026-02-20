import '../../domain/entities/health_data_source.dart';
import '../../domain/entities/health_data_source_type.dart';
import '../../domain/entities/health_metric_type.dart';

/// Модель источника данных для слоя Data.
class HealthDataSourceModel extends HealthDataSource {
  /// Создает модель источника данных.
  const HealthDataSourceModel({
    required super.id,
    required super.name,
    required super.description,
    required super.type,
    required super.iconKey,
    required super.supportedMetrics,
    required super.isConnected,
    required super.isAvailable,
  });

  /// Создает модель из JSON.
  factory HealthDataSourceModel.fromJson(Map<String, dynamic> json) {
    final metrics = (json['supportedMetrics'] as List<dynamic>? ?? const [])
        .map((item) => HealthMetricTypeX.fromKey(item as String?))
        .where((type) => type != HealthMetricType.unknown)
        .toList();

    return HealthDataSourceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: HealthDataSourceTypeX.fromKey(json['type'] as String?),
      iconKey: json['iconKey'] as String? ?? '',
      supportedMetrics: metrics,
      isConnected: json['isConnected'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  /// Преобразует модель в JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.key,
      'iconKey': iconKey,
      'supportedMetrics': supportedMetrics.map((item) => item.key).toList(),
      'isConnected': isConnected,
      'isAvailable': isAvailable,
    };
  }
}
