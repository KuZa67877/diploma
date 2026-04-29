import 'package:equatable/equatable.dart';
import 'export_data_range.dart';

class ExportField extends Equatable {
  final String code;
  final String label;
  final String? displayValue;
  final double? numericValue;
  final String? unit;
  final String? source;
  final String? status;
  final String? deviation;
  final String? comment;
  final DateTime? effectiveDateTime;
  final bool isDerived;

  const ExportField({
    required this.code,
    required this.label,
    this.displayValue,
    this.numericValue,
    this.unit,
    this.source,
    this.status,
    this.deviation,
    this.comment,
    this.effectiveDateTime,
    this.isDerived = false,
  });

  bool get hasValue =>
      (displayValue != null && displayValue!.trim().isNotEmpty) ||
      numericValue != null;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'displayValue': displayValue,
      'numericValue': numericValue,
      'unit': unit,
      'source': source,
      'status': status,
      'deviation': deviation,
      'comment': comment,
      'effectiveDateTime': effectiveDateTime?.toIso8601String(),
      'isDerived': isDerived,
    };
  }

  @override
  List<Object?> get props => [
    code,
    label,
    displayValue,
    numericValue,
    unit,
    source,
    status,
    deviation,
    comment,
    effectiveDateTime,
    isDerived,
  ];
}

class ExportSection extends Equatable {
  final String id;
  final String title;
  final List<ExportField> fields;
  final String? note;

  const ExportSection({
    required this.id,
    required this.title,
    required this.fields,
    this.note,
  });

  bool get hasData => fields.any((field) => field.hasValue);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'fields': fields.map((field) => field.toJson()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [id, title, fields, note];
}

class ExportObservation extends Equatable {
  final DateTime effectiveDateTime;
  final String metricType;
  final String metricLabel;
  final double value;
  final String unit;
  final String source;
  final String? status;
  final String? comment;
  final String? deviation;
  final bool isDerived;

  const ExportObservation({
    required this.effectiveDateTime,
    required this.metricType,
    required this.metricLabel,
    required this.value,
    required this.unit,
    required this.source,
    this.status,
    this.comment,
    this.deviation,
    this.isDerived = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'effectiveDateTime': effectiveDateTime.toIso8601String(),
      'metricType': metricType,
      'metricLabel': metricLabel,
      'value': value,
      'unit': unit,
      'source': source,
      'status': status,
      'comment': comment,
      'deviation': deviation,
      'isDerived': isDerived,
    };
  }

  @override
  List<Object?> get props => [
    effectiveDateTime,
    metricType,
    metricLabel,
    value,
    unit,
    source,
    status,
    comment,
    deviation,
    isDerived,
  ];
}

class ExportPayload extends Equatable {
  final ExportDataRange range;
  final Map<String, String> personalData;
  final List<ExportSection> sections;
  final List<ExportObservation> observations;
  final List<String> recommendations;
  final List<String> warnings;
  final List<String> missingSections;
  final int sourceCount;
  final int recordCount;
  final bool hasAnyData;
  final bool isPartialData;

  const ExportPayload({
    required this.range,
    required this.personalData,
    required this.sections,
    required this.observations,
    required this.recommendations,
    required this.warnings,
    required this.missingSections,
    required this.sourceCount,
    required this.recordCount,
    required this.hasAnyData,
    required this.isPartialData,
  });

  Map<String, dynamic> toJson() {
    return {
      'period': {
        'preset': range.preset.name,
        'start': range.start.toIso8601String(),
        'end': range.end.toIso8601String(),
      },
      'personalData': personalData,
      'sections': sections
          .map((section) => section.toJson())
          .toList(growable: false),
      'observations': observations
          .map((observation) => observation.toJson())
          .toList(growable: false),
      'recommendations': recommendations,
      'warnings': warnings,
      'missingSections': missingSections,
      'sourceCount': sourceCount,
      'recordCount': recordCount,
      'hasAnyData': hasAnyData,
      'isPartialData': isPartialData,
    };
  }

  @override
  List<Object?> get props => [
    range,
    personalData,
    sections,
    observations,
    recommendations,
    warnings,
    missingSections,
    sourceCount,
    recordCount,
    hasAnyData,
    isPartialData,
  ];
}
