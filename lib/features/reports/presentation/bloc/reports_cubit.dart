import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../health_data/domain/entities/health_date_range.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/usecases/get_health_metrics.dart';
import '../../domain/entities/report_export_option.dart';
import '../../domain/entities/report_filter_option.dart';
import '../../domain/entities/report_item.dart';
import '../../domain/entities/reports_data.dart';
import '../../domain/usecases/get_reports_data.dart';
import '../models/reports_ui_models.dart';

part 'reports_cubit.freezed.dart';
part 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final GetReportsData getReportsData;
  final GetHealthMetrics getHealthMetrics;

  ReportsCubit({
    required this.getReportsData,
    required this.getHealthMetrics,
  }) : super(const ReportsState.initial());

  Future<void> load({String? filterId}) async {
    emit(const ReportsState.loading());

    final result = await getReportsData(
      ReportsParams(filterId: filterId ?? 'all'),
    );

    result.fold(
      (failure) => emit(ReportsState.error(message: _mapFailureMessage(failure))),
      (data) => emit(ReportsState.loaded(data: _mapToViewData(data))),
    );
  }

  Future<void> selectFilter(String filterId) async {
    await load(filterId: filterId);
  }

  /// Выполняет экспорт данных по выбранному источнику.
  Future<void> exportOption(String optionId) async {
    final current = state.whenOrNull(
      loaded: (data) => data,
      exportReady: (data, _, __) => data,
      exportFailed: (data, _) => data,
    );

    if (current == null) {
      return;
    }

    final range = _rangeForFilter(current.selectedFilterId);
    final result = await getHealthMetrics(
      HealthMetricsQuery(range: range),
    );

    result.fold(
      (failure) => _emitExportFailed(current, _mapFailureMessage(failure)),
      (metrics) {
        final sources = metrics.map((item) => item.sourceId).toSet();
        emit(
          ReportsState.exportReady(
            data: current,
            itemsCount: metrics.length,
            sourcesCount: sources.length,
          ),
        );
        emit(ReportsState.loaded(data: current));
      },
    );
  }

  ReportsViewData _mapToViewData(ReportsData data) {
    return ReportsViewData(
      filters: _mapFilters(data.filters),
      selectedFilterId: data.selectedFilterId,
      exportOptions: _mapExportOptions(data.exportOptions),
      reports: _mapReports(data.reports),
    );
  }

  List<ReportFilterUiModel> _mapFilters(List<ReportFilterOption> filters) {
    return filters
        .map(
          (filter) => ReportFilterUiModel(
            id: filter.id,
            labelKey: filter.labelKey,
          ),
        )
        .toList(growable: false);
  }

  List<ReportExportUiModel> _mapExportOptions(
    List<ReportExportOption> options,
  ) {
    return options
        .map(
          (option) => ReportExportUiModel(
            id: option.id,
            labelKey: option.labelKey,
            useLocalization: option.useLocalization,
            icon: _iconForKey(option.iconKey),
            color: _colorForKey(option.colorKey),
          ),
        )
        .toList(growable: false);
  }

  List<ReportItemUiModel> _mapReports(List<ReportItem> reports) {
    return reports
        .map(
          (report) => ReportItemUiModel(
            id: report.id,
            titleKey: report.titleKey,
            date: report.date,
            type: report.type,
            status: report.status,
          ),
        )
        .toList(growable: false);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'fileDown':
        return LucideIcons.fileDown;
      case 'fileText':
        return LucideIcons.fileText;
      case 'share2':
        return LucideIcons.share2;
      default:
        return LucideIcons.file;
    }
  }

  Color _colorForKey(String key) {
    switch (key) {
      case 'secondary':
        return AppColors.secondary;
      case 'accent':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }

  HealthDateRange _rangeForFilter(String filterId) {
    final now = DateTime.now();
    final start = switch (filterId) {
      'day' => now.subtract(const Duration(days: 1)),
      'week' => now.subtract(const Duration(days: 7)),
      'month' => now.subtract(const Duration(days: 30)),
      'year' => now.subtract(const Duration(days: 365)),
      _ => now.subtract(const Duration(days: 30)),
    };
    return HealthDateRange(start: start, end: now);
  }

  void _emitExportFailed(ReportsViewData current, String message) {
    emit(
      ReportsState.exportFailed(
        data: current,
        message: message,
      ),
    );
    emit(ReportsState.loaded(data: current));
  }
}
