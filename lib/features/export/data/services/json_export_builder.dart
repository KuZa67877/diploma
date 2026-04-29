import 'dart:convert';
import '../../domain/entities/export_payload.dart';

class JsonExportBuilder {
  const JsonExportBuilder();

  String build(ExportPayload payload) {
    return const JsonEncoder.withIndent('  ').convert(payload.toJson());
  }
}
