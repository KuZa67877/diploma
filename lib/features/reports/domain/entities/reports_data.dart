import 'package:equatable/equatable.dart';
import 'report_export_option.dart';
import 'report_filter_option.dart';
import 'report_item.dart';

class ReportsData extends Equatable {
  final List<ReportFilterOption> filters;
  final String selectedFilterId;
  final List<ReportExportOption> exportOptions;
  final List<ReportItem> reports;

  const ReportsData({
    required this.filters,
    required this.selectedFilterId,
    required this.exportOptions,
    required this.reports,
  });

  @override
  List<Object> get props => [filters, selectedFilterId, exportOptions, reports];
}
