enum AiPromptTemplate {
  assessState,
  findAnomalies,
  dayRecommendations,
  doctorQuestions,
  explainSimply,
  custom;

  String get labelKey => switch (this) {
    AiPromptTemplate.assessState => 'exportPromptAssess',
    AiPromptTemplate.findAnomalies => 'exportPromptAnomalies',
    AiPromptTemplate.dayRecommendations => 'exportPromptRecommendations',
    AiPromptTemplate.doctorQuestions => 'exportPromptDoctorQuestions',
    AiPromptTemplate.explainSimply => 'exportPromptSimple',
    AiPromptTemplate.custom => 'exportPromptCustom',
  };
}
