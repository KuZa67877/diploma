import '../../domain/entities/report_export_option.dart';

class ReportExportOptionModel extends ReportExportOption {
  const ReportExportOptionModel({
    required super.id,
    required super.labelKey,
    required super.useLocalization,
    required super.iconKey,
    required super.colorKey,
  });

  factory ReportExportOptionModel.fromJson(Map<String, dynamic> json) {
    return ReportExportOptionModel(
      id: json['id']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
      useLocalization: json['useLocalization'] == true,
      iconKey: json['iconKey']?.toString() ?? '',
      colorKey: json['colorKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labelKey': labelKey,
      'useLocalization': useLocalization,
      'iconKey': iconKey,
      'colorKey': colorKey,
    };
  }
}
