import 'package:flutter/material.dart';

class ReportFilterUiModel {
  final String id;
  final String labelKey;

  const ReportFilterUiModel({
    required this.id,
    required this.labelKey,
  });
}

class ReportExportUiModel {
  final String id;
  final String labelKey;
  final bool useLocalization;
  final IconData icon;
  final Color color;

  const ReportExportUiModel({
    required this.id,
    required this.labelKey,
    required this.useLocalization,
    required this.icon,
    required this.color,
  });
}

class ReportItemUiModel {
  final int id;
  final String titleKey;
  final String date;
  final String type;
  final String status;

  const ReportItemUiModel({
    required this.id,
    required this.titleKey,
    required this.date,
    required this.type,
    required this.status,
  });
}

class ReportsViewData {
  final List<ReportFilterUiModel> filters;
  final String selectedFilterId;
  final List<ReportExportUiModel> exportOptions;
  final List<ReportItemUiModel> reports;

  const ReportsViewData({
    required this.filters,
    required this.selectedFilterId,
    required this.exportOptions,
    required this.reports,
  });
}
