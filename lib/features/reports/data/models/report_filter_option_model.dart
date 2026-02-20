import '../../domain/entities/report_filter_option.dart';

class ReportFilterOptionModel extends ReportFilterOption {
  const ReportFilterOptionModel({
    required super.id,
    required super.labelKey,
  });

  factory ReportFilterOptionModel.fromJson(Map<String, dynamic> json) {
    return ReportFilterOptionModel(
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
