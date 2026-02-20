import '../../domain/entities/dashboard_metric.dart';

class DashboardMetricModel extends DashboardMetric {
  const DashboardMetricModel({
    required super.id,
    required super.labelKey,
    required super.value,
    required super.unit,
    required super.trend,
    required super.data,
  });

  factory DashboardMetricModel.fromJson(Map<String, dynamic> json) {
    return DashboardMetricModel(
      id: json['id']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      trend: json['trend']?.toString() ?? 'stable',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => double.tryParse('$item') ?? 0)
              .toList() ??
          const <double>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labelKey': labelKey,
      'value': value,
      'unit': unit,
      'trend': trend,
      'data': data,
    };
  }
}
