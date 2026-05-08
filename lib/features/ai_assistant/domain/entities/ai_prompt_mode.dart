enum AiPromptMode {
  shortAnalysis,
  detailedAnalysis,
  dailyRecommendations,
  healthScoreExplanation,
  doctorSummary,
  warningSignals,
  baselineComparison,
}

extension AiPromptModeX on AiPromptMode {
  String get labelKey => switch (this) {
    AiPromptMode.shortAnalysis => 'aiPromptModeShortAnalysis',
    AiPromptMode.detailedAnalysis => 'aiPromptModeDetailedAnalysis',
    AiPromptMode.dailyRecommendations =>
      'aiPromptModeDailyRecommendations',
    AiPromptMode.healthScoreExplanation =>
      'aiPromptModeHealthScoreExplanation',
    AiPromptMode.doctorSummary => 'aiPromptModeDoctorSummary',
    AiPromptMode.warningSignals => 'aiPromptModeWarningSignals',
    AiPromptMode.baselineComparison => 'aiPromptModeBaselineComparison',
  };

  String get goalText => switch (this) {
    AiPromptMode.shortAnalysis => 'Краткий анализ',
    AiPromptMode.detailedAnalysis => 'Подробный анализ',
    AiPromptMode.dailyRecommendations => 'Рекомендации на день',
    AiPromptMode.healthScoreExplanation =>
      'Объяснение причин изменения HealthScore',
    AiPromptMode.doctorSummary => 'Подготовить summary для врача',
    AiPromptMode.warningSignals => 'Найти возможные тревожные сигналы',
    AiPromptMode.baselineComparison =>
      'Сравнить с обычной базовой линией пользователя',
  };
}
