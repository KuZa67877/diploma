import 'package:equatable/equatable.dart';

class DashboardMetric extends Equatable {
  final String id;
  final String labelKey;
  final String value;
  final String unit;
  final String trend;
  final List<double> data;

  const DashboardMetric({
    required this.id,
    required this.labelKey,
    required this.value,
    required this.unit,
    required this.trend,
    required this.data,
  });

  @override
  List<Object> get props => [id, labelKey, value, unit, trend, data];
}
