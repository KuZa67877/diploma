import 'dart:io';

import '../../domain/entities/export_data_range.dart';
import '../../domain/entities/export_format.dart';

class ExportedFile {
  final String path;
  final String fileName;
  final String mimeType;

  const ExportedFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
  });
}

class ExportFileService {
  const ExportFileService();

  Future<ExportedFile> saveExport({
    required String content,
    required ExportFormat format,
    required ExportDataRange range,
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final period = '${_datePart(range.start)}_${_datePart(range.end)}';
    final extension = _extension(format);
    final fileName = 'medi_ai_export_${period}_$timestamp.$extension';
    return saveTextFile(
      content: content,
      fileName: fileName,
      mimeType: _mimeType(format),
    );
  }

  Future<ExportedFile> saveTextFile({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    final directory = Directory('${Directory.systemTemp.path}/medi_ai_exports');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content, flush: true);

    return ExportedFile(
      path: file.path,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<ExportedFile> saveDebugJson({
    required String content,
    String fileNamePrefix = 'medi_ai_perf_report',
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return saveTextFile(
      content: content,
      fileName: '${fileNamePrefix}_$timestamp.json',
      mimeType: 'application/json',
    );
  }

  String _extension(ExportFormat format) {
    return switch (format) {
      ExportFormat.json => 'json',
      ExportFormat.csv => 'csv',
      ExportFormat.markdown => 'md',
      _ => 'txt',
    };
  }

  String _mimeType(ExportFormat format) {
    return switch (format) {
      ExportFormat.json => 'application/json',
      ExportFormat.csv => 'text/csv',
      ExportFormat.markdown => 'text/markdown',
      _ => 'text/plain',
    };
  }

  String _datePart(DateTime value) {
    final local = value.toLocal();
    return '${local.year}${local.month.toString().padLeft(2, '0')}${local.day.toString().padLeft(2, '0')}';
  }
}
