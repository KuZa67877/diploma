import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../health_data/domain/entities/health_metric_sample.dart';
import '../../../health_data/domain/entities/health_metrics_query.dart';
import '../../../health_data/domain/usecases/get_health_metrics.dart';
import '../../../profile/domain/entities/profile_data.dart';
import '../../../profile/domain/usecases/get_profile_data.dart';
import '../../data/services/ai_prompt_export_builder.dart';
import '../../data/services/csv_export_builder.dart';
import '../../data/services/health_data_export_mapper.dart';
import '../../data/services/historical_model_output_service.dart';
import '../../data/services/json_export_builder.dart';
import '../../data/services/markdown_export_builder.dart';
import '../../data/services/medical_export_builder.dart';
import '../../domain/entities/ai_prompt_template.dart';
import '../../domain/entities/export_data_range.dart';
import '../../domain/entities/export_data_type.dart';
import '../../domain/entities/export_format.dart';
import '../../domain/entities/export_payload.dart';

enum ExportDataStatus { initial, loading, ready, partial, empty, error }

class ExportDataState extends Equatable {
  final ExportDataStatus status;
  final ExportDataRange range;
  final Set<ExportDataType> selectedTypes;
  final ExportFormat format;
  final AiPromptTemplate promptTemplate;
  final String customPrompt;
  final bool includePersonalData;
  final String previewText;
  final String? errorMessage;
  final int recordCount;
  final int sourceCount;
  final List<String> missingSections;

  const ExportDataState({
    required this.status,
    required this.range,
    required this.selectedTypes,
    required this.format,
    required this.promptTemplate,
    required this.customPrompt,
    required this.includePersonalData,
    required this.previewText,
    this.errorMessage,
    this.recordCount = 0,
    this.sourceCount = 0,
    this.missingSections = const <String>[],
  });

  factory ExportDataState.initial() {
    return ExportDataState(
      status: ExportDataStatus.initial,
      range: ExportDataRange.last7Days(),
      selectedTypes: const {ExportDataType.everything},
      format: ExportFormat.ai,
      promptTemplate: AiPromptTemplate.assessState,
      customPrompt: '',
      includePersonalData: false,
      previewText: '',
    );
  }

  ExportDataState copyWith({
    ExportDataStatus? status,
    ExportDataRange? range,
    Set<ExportDataType>? selectedTypes,
    ExportFormat? format,
    AiPromptTemplate? promptTemplate,
    String? customPrompt,
    bool? includePersonalData,
    String? previewText,
    String? errorMessage,
    bool clearError = false,
    int? recordCount,
    int? sourceCount,
    List<String>? missingSections,
  }) {
    return ExportDataState(
      status: status ?? this.status,
      range: range ?? this.range,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      format: format ?? this.format,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      customPrompt: customPrompt ?? this.customPrompt,
      includePersonalData: includePersonalData ?? this.includePersonalData,
      previewText: previewText ?? this.previewText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recordCount: recordCount ?? this.recordCount,
      sourceCount: sourceCount ?? this.sourceCount,
      missingSections: missingSections ?? this.missingSections,
    );
  }

  @override
  List<Object?> get props => [
    status,
    range,
    selectedTypes,
    format,
    promptTemplate,
    customPrompt,
    includePersonalData,
    previewText,
    errorMessage,
    recordCount,
    sourceCount,
    missingSections,
  ];
}

class ExportDataCubit extends Cubit<ExportDataState> {
  final GetHealthMetrics getHealthMetrics;
  final GetProfileData getProfileData;
  final HistoricalModelOutputService historicalModelOutputService;
  final HealthDataExportMapper exportMapper;
  final AiPromptExportBuilder aiPromptExportBuilder;
  final MedicalExportBuilder medicalExportBuilder;
  final MarkdownExportBuilder markdownExportBuilder;
  final JsonExportBuilder jsonExportBuilder;
  final CsvExportBuilder csvExportBuilder;

  ExportDataCubit({
    required this.getHealthMetrics,
    required this.getProfileData,
    required this.historicalModelOutputService,
    required this.exportMapper,
    required this.aiPromptExportBuilder,
    required this.medicalExportBuilder,
    required this.markdownExportBuilder,
    required this.jsonExportBuilder,
    required this.csvExportBuilder,
  }) : super(ExportDataState.initial());

  List<HealthMetricSample> _metrics = const <HealthMetricSample>[];
  ProfileData? _profileData;
  ExportModelOutputSnapshot _modelOutputs = ExportModelOutputSnapshot.empty;
  ExportPayload? _payload;

  Future<void> load() async {
    emit(state.copyWith(status: ExportDataStatus.loading, clearError: true));
    final metricsFuture = getHealthMetrics(
      HealthMetricsQuery(range: state.range.toHealthDateRange()),
    );
    final modelOutputsFuture = historicalModelOutputService.loadForRange(
      state.range,
    );

    final metricsResult = await metricsFuture;
    try {
      _modelOutputs = await modelOutputsFuture;
    } catch (_) {
      _modelOutputs = ExportModelOutputSnapshot.empty;
    }

    metricsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: ExportDataStatus.error,
          errorMessage: _mapFailureMessage(failure),
        ),
      ),
      (metrics) {
        _metrics = metrics;
        _rebuild();
        if (state.includePersonalData && _profileData == null) {
          unawaited(_loadProfileData());
        }
      },
    );
  }

  Future<void> selectPreset(ExportRangePreset preset) async {
    final nextRange = switch (preset) {
      ExportRangePreset.today => ExportDataRange.today(),
      ExportRangePreset.yesterday => ExportDataRange.yesterday(),
      ExportRangePreset.last7Days => ExportDataRange.last7Days(),
      ExportRangePreset.last30Days => ExportDataRange.last30Days(),
      ExportRangePreset.custom => state.range,
    };
    emit(state.copyWith(range: nextRange));
    if (preset != ExportRangePreset.custom) {
      await load();
    }
  }

  Future<void> setCustomRange(DateTime start, DateTime end) async {
    emit(
      state.copyWith(
        range: ExportDataRange.custom(start: start, end: end),
      ),
    );
    await load();
  }

  void toggleDataType(ExportDataType type) {
    final next = {...state.selectedTypes};
    if (type == ExportDataType.everything) {
      emit(state.copyWith(selectedTypes: {ExportDataType.everything}));
      _rebuild();
      return;
    }

    next.remove(ExportDataType.everything);
    if (!next.add(type)) {
      next.remove(type);
    }

    if (next.isEmpty) {
      next.add(ExportDataType.everything);
    }

    emit(state.copyWith(selectedTypes: next));
    _rebuild();
  }

  void selectFormat(ExportFormat format) {
    emit(state.copyWith(format: format));
    _rebuild();
  }

  void selectPromptTemplate(AiPromptTemplate template) {
    emit(state.copyWith(promptTemplate: template));
    _rebuild();
  }

  void updateCustomPrompt(String value) {
    emit(state.copyWith(customPrompt: value));
    if (state.promptTemplate == AiPromptTemplate.custom) {
      _rebuild();
    }
  }

  Future<void> toggleIncludePersonalData(bool value) async {
    emit(state.copyWith(includePersonalData: value));
    if (value && _profileData == null) {
      await _loadProfileData();
      return;
    }
    _rebuild();
  }

  String buildExportText({ExportFormat? formatOverride}) {
    final payload = _payload;
    if (payload == null) {
      return '';
    }
    final format = formatOverride ?? state.format;
    return switch (format) {
      ExportFormat.ai => aiPromptExportBuilder.build(
        payload: payload,
        template: state.promptTemplate,
        customPrompt: state.customPrompt,
      ),
      ExportFormat.doctor => medicalExportBuilder.build(payload),
      ExportFormat.markdown => markdownExportBuilder.build(payload),
      ExportFormat.json => jsonExportBuilder.build(payload),
      ExportFormat.csv => csvExportBuilder.build(payload),
      ExportFormat.shortSummary => _buildSummary(payload, short: true),
      ExportFormat.detailedReport => _buildSummary(payload, short: false),
    };
  }

  void _rebuild() {
    _payload = exportMapper.map(
      range: state.range,
      selectedTypes: state.selectedTypes,
      includePersonalData: state.includePersonalData,
      metrics: _metrics,
      latestModelOutputs: _modelOutputs.latestByModel,
      modelOutputHistory: _modelOutputs.records,
      profileData: _profileData,
    );
    final preview = buildExportText();
    final payload = _payload!;
    final status = !payload.hasAnyData
        ? ExportDataStatus.empty
        : payload.isPartialData
        ? ExportDataStatus.partial
        : ExportDataStatus.ready;
    emit(
      state.copyWith(
        status: status,
        previewText: preview,
        recordCount: payload.recordCount,
        sourceCount: payload.sourceCount,
        missingSections: payload.missingSections,
        clearError: true,
      ),
    );
  }

  Future<void> _loadProfileData() async {
    final profileResult = await getProfileData(const NoParams());
    profileResult.fold((_) {}, (value) {
      _profileData = value;
      if (state.includePersonalData) {
        _rebuild();
      }
    });
  }

  String _buildSummary(ExportPayload payload, {required bool short}) {
    final buffer = StringBuffer();
    buffer.writeln('Экспорт данных MediAI');
    buffer.writeln(
      'Период: ${_formatDate(payload.range.start)} — ${_formatDate(payload.range.end)}',
    );
    for (final section in payload.sections) {
      if (!section.hasData) {
        continue;
      }
      buffer.writeln();
      buffer.writeln('${section.title}:');
      final fields = short ? section.fields.take(3) : section.fields;
      for (final field in fields) {
        if (!field.hasValue) {
          continue;
        }
        final value = field.unit == null || field.unit!.isEmpty
            ? field.displayValue
            : '${field.displayValue} ${field.unit}';
        buffer.writeln('- ${field.label}: $value');
      }
    }
    if (!short && payload.warnings.isNotEmpty) {
      buffer.writeln();
      for (final warning in payload.warnings) {
        buffer.writeln('- $warning');
      }
    }
    return buffer.toString().trimRight();
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message.isEmpty
        ? 'Не удалось подготовить экспорт.'
        : failure.message;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
  }
}
