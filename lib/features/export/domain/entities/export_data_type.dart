enum ExportDataType {
  everything,
  pulse,
  hrv,
  sleep,
  activity,
  stress,
  recovery,
  modelResults,
  recommendations,
  rawMetrics,
  anomaliesOnly;

  String get labelKey => switch (this) {
    ExportDataType.everything => 'all',
    ExportDataType.pulse => 'exportPulse',
    ExportDataType.hrv => 'hrv',
    ExportDataType.sleep => 'sleep',
    ExportDataType.activity => 'activity',
    ExportDataType.stress => 'stress',
    ExportDataType.recovery => 'recovery',
    ExportDataType.modelResults => 'modelResults',
    ExportDataType.recommendations => 'exportRecommendations',
    ExportDataType.rawMetrics => 'exportRawMetrics',
    ExportDataType.anomaliesOnly => 'exportOnlyAnomalies',
  };
}
