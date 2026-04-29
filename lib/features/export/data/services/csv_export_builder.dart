import '../../domain/entities/export_payload.dart';

class CsvExportBuilder {
  const CsvExportBuilder();

  String build(ExportPayload payload) {
    final buffer = StringBuffer();
    buffer.writeln(
      'date,metric_type,metric_label,value,unit,source,status,comment,deviation,derived',
    );
    for (final item in payload.observations) {
      buffer.writeln(
        [
          item.effectiveDateTime.toIso8601String(),
          item.metricType,
          item.metricLabel,
          item.value.toString(),
          item.unit,
          item.source,
          item.status ?? '',
          item.comment ?? '',
          item.deviation ?? '',
          item.isDerived ? 'true' : 'false',
        ].map(_escape).join(','),
      );
    }
    return buffer.toString().trimRight();
  }

  String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
