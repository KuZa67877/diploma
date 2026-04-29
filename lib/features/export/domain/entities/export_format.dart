enum ExportFormat {
  ai,
  doctor,
  markdown,
  json,
  csv,
  shortSummary,
  detailedReport;

  String get labelKey => switch (this) {
    ExportFormat.ai => 'exportFormatAi',
    ExportFormat.doctor => 'exportFormatDoctor',
    ExportFormat.markdown => 'exportFormatMarkdown',
    ExportFormat.json => 'exportFormatJson',
    ExportFormat.csv => 'exportFormatCsv',
    ExportFormat.shortSummary => 'exportFormatShort',
    ExportFormat.detailedReport => 'exportFormatDetailed',
  };
}
