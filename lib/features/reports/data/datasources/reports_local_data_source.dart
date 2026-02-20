import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/report_export_option_model.dart';
import '../models/report_filter_option_model.dart';
import '../models/report_item_model.dart';
import '../models/reports_data_model.dart';

abstract class ReportsLocalDataSource {
  Future<ReportsDataModel> getReportsData(String filterId);
}

class ReportsLocalDataSourceImpl implements ReportsLocalDataSource {
  static const String _assetPath = 'assets/data/reports.json';

  @override
  Future<ReportsDataModel> getReportsData(String filterId) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final filters = (decoded['filters'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ReportFilterOptionModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    final exportOptions =
        (decoded['exportOptions'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => ReportExportOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList();

    final reports = (decoded['reports'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ReportItemModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();

    final normalized = filters.any((f) => f.id == filterId) ? filterId : 'all';
    final filtered = _filterReports(normalized, reports);

    return ReportsDataModel(
      filters: filters,
      selectedFilterId: normalized,
      exportOptions: exportOptions,
      reports: filtered,
    );
  }

  List<ReportItemModel> _filterReports(
    String filterId,
    List<ReportItemModel> reports,
  ) {
    switch (filterId) {
      case 'summary':
        return reports.where((report) => report.type == 'summary').toList();
      case 'aiReports':
        return reports
            .where((report) => report.type == 'diagnostics')
            .toList();
      case 'trends':
        return reports.where((report) => report.type == 'trends').toList();
      default:
        return reports;
    }
  }
}
