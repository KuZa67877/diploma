import '../../domain/entities/analytics_filter_option.dart';

class AnalyticsFilterOptionModel extends AnalyticsFilterOption {
  const AnalyticsFilterOptionModel({
    required super.id,
    required super.labelKey,
  });

  factory AnalyticsFilterOptionModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsFilterOptionModel(
      id: json['id']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labelKey': labelKey,
    };
  }
}
