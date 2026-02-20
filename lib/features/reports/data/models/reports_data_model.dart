import '../../domain/entities/reports_data.dart';
import 'report_export_option_model.dart';
import 'report_filter_option_model.dart';
import 'report_item_model.dart';

class ReportsDataModel extends ReportsData {
  const ReportsDataModel({
    required super.filters,
    required super.selectedFilterId,
    required super.exportOptions,
    required super.reports,
  });

  factory ReportsDataModel.fromJson(Map<String, dynamic> json) {
    final filters = (json['filters'] as List<dynamic>?)
            ?.map((item) => ReportFilterOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <ReportFilterOptionModel>[];

    final exportOptions = (json['exportOptions'] as List<dynamic>?)
            ?.map((item) => ReportExportOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <ReportExportOptionModel>[];

    final reports = (json['reports'] as List<dynamic>?)
            ?.map((item) => ReportItemModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <ReportItemModel>[];

    return ReportsDataModel(
      filters: filters,
      selectedFilterId: json['selectedFilterId']?.toString() ?? '',
      exportOptions: exportOptions,
      reports: reports,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filters': filters
          .map((item) => (item as ReportFilterOptionModel).toJson())
          .toList(),
      'selectedFilterId': selectedFilterId,
      'exportOptions': exportOptions
          .map((item) => (item as ReportExportOptionModel).toJson())
          .toList(),
      'reports': reports
          .map((item) => (item as ReportItemModel).toJson())
          .toList(),
    };
  }
}
