import 'package:flutter/material.dart';

enum AppLanguage {
  english('en'),
  russian('ru');

  final String code;
  const AppLanguage(this.code);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ru')];

  String get(String key) {
    return _translations[key]?[language.code] ?? key;
  }

  static String lookup(
    String key, {
    AppLanguage language = AppLanguage.english,
  }) {
    return _translations[key]?[language.code] ?? key;
  }

  String getWithParams(
    String key, [
    Map<String, String> params = const <String, String>{},
  ]) {
    var text = get(key);
    if (params.isEmpty) {
      return text;
    }
    params.forEach((paramKey, value) {
      text = text.replaceAll('{$paramKey}', value);
    });
    return text;
  }

  // Translations map
  static const Map<String, Map<String, String>> _translations = {
    // App name and tagline
    'appName': {'en': 'MediAI', 'ru': 'MediAI'},
    'tagline': {
      'en': 'AI-powered health diagnostics',
      'ru': 'ИИ-диагностика здоровья',
    },

    // Onboarding
    'aiHealthAnalysis': {
      'en': 'AI Health Analysis',
      'ru': 'ИИ-анализ здоровья',
    },
    'aiHealthAnalysisDesc': {
      'en':
          'Advanced neural network analyzes your health metrics to provide personalized insights and early risk detection.',
      'ru':
          'Продвинутая нейросеть анализирует ваши показатели здоровья для персонализированных рекомендаций и раннего выявления рисков.',
    },
    'smartDataSync': {'en': 'Smart Data Sync', 'ru': 'Умная синхронизация'},
    'smartDataSyncDesc': {
      'en':
          'Seamlessly connect with Apple Health and Google Health Connect to automatically track your wellness journey.',
      'ru':
          'Синхронизируйтесь с Apple Health и Google Health Connect для автоматического отслеживания вашего здоровья.',
    },
    'secureReports': {'en': 'Secure Reports', 'ru': 'Безопасные отчёты'},
    'secureReportsDesc': {
      'en':
          'Your medical data is encrypted and protected. Export detailed health reports to share with your healthcare provider.',
      'ru':
          'Ваши медицинские данные зашифрованы и защищены. Экспортируйте подробные отчёты для вашего врача.',
    },
    'getStarted': {'en': 'Get Started', 'ru': 'Начать'},
    'alreadyHaveAccount': {
      'en': 'Already have an account? Sign in',
      'ru': 'Уже есть аккаунт? Войти',
    },

    // Permissions
    'connectHealthData': {
      'en': 'Connect Health Data',
      'ru': 'Подключить данные',
    },
    'syncYourMetrics': {
      'en': 'Sync your health metrics for comprehensive AI analysis',
      'ru': 'Синхронизируйте метрики для комплексного ИИ-анализа',
    },
    'iosDevices': {'en': 'iOS devices', 'ru': 'Устройства iOS'},
    'androidDevices': {'en': 'Android devices', 'ru': 'Устройства Android'},
    'selectDataToSync': {
      'en': 'Select data to sync',
      'ru': 'Выберите данные для синхронизации',
    },
    'heartRateDesc': {'en': 'BPM & HRV data', 'ru': 'Данные ЧСС и ВСР'},
    'stepsDesc': {
      'en': 'Daily activity tracking',
      'ru': 'Ежедневная активность',
    },
    'sleepDesc': {'en': 'Sleep cycles & quality', 'ru': 'Циклы и качество сна'},
    'bloodOxygenDesc': {'en': 'SpO2 levels', 'ru': 'Уровень SpO2'},
    'weightDesc': {'en': 'Body measurements', 'ru': 'Измерения тела'},
    'syncHealthData': {'en': 'Sync Health Data', 'ru': 'Синхронизировать'},
    'skipForNow': {'en': 'Skip for now', 'ru': 'Пропустить'},
    'bloodOxygen': {'en': 'Blood Oxygen', 'ru': 'Кислород в крови'},
    'steps': {'en': 'Steps', 'ru': 'Шаги'},
    'weight': {'en': 'Weight', 'ru': 'Вес'},
    'bloodPressureSystolic': {
      'en': 'Systolic pressure',
      'ru': 'Систолическое давление',
    },
    'bloodPressureDiastolic': {
      'en': 'Diastolic pressure',
      'ru': 'Диастолическое давление',
    },
    'activeEnergyBurned': {'en': 'Active energy', 'ru': 'Активная энергия'},
    'distanceWalkingRunning': {
      'en': 'Walking/running distance',
      'ru': 'Дистанция ходьбы/бега',
    },
    'respiratoryRate': {'en': 'Respiratory rate', 'ru': 'Частота дыхания'},
    'bodyTemperature': {'en': 'Body temperature', 'ru': 'Температура тела'},
    'mvpMetrics': {'en': 'MVP metrics', 'ru': 'MVP-метрики'},
    'previewImportedData': {
      'en': 'Preview imported data',
      'ru': 'Просмотр импортированных данных',
    },
    'continue': {'en': 'Continue', 'ru': 'Продолжить'},
    'retry': {'en': 'Retry', 'ru': 'Повторить'},
    'reload': {'en': 'Reload', 'ru': 'Обновить'},
    'back': {'en': 'Back', 'ru': 'Назад'},
    'more': {'en': 'more', 'ru': 'ещё'},

    // Health sources
    'healthDataSources': {
      'en': 'Health Data Sources',
      'ru': 'Источники данных',
    },
    'healthSourcesSubtitle': {
      'en': 'Connect and manage your health data providers',
      'ru': 'Подключите и управляйте источниками данных',
    },
    'supportedMetrics': {
      'en': 'Supported metrics',
      'ru': 'Поддерживаемые метрики',
    },
    'connected': {'en': 'Connected', 'ru': 'Подключено'},
    'notConnected': {'en': 'Not connected', 'ru': 'Не подключено'},
    'notAvailable': {'en': 'Not available', 'ru': 'Недоступно'},

    // Auth
    'welcomeBack': {'en': 'Welcome Back', 'ru': 'С возвращением'},
    'createAccount': {'en': 'Create Account', 'ru': 'Создать аккаунт'},
    'signInToContinue': {
      'en': 'Sign in to continue your health journey',
      'ru': 'Войдите, чтобы продолжить',
    },
    'startYourAIHealth': {
      'en': 'Start your AI health analysis today',
      'ru': 'Начните ИИ-анализ здоровья сегодня',
    },
    'email': {'en': 'Email', 'ru': 'Эл. почта'},
    'password': {'en': 'Password', 'ru': 'Пароль'},
    'forgotPassword': {'en': 'Forgot password?', 'ru': 'Забыли пароль?'},
    'signIn': {'en': 'Sign In', 'ru': 'Войти'},
    'signUp': {'en': 'Sign Up', 'ru': 'Регистрация'},
    'orContinueWith': {'en': 'or continue with', 'ru': 'или войти через'},
    'dontHaveAccount': {
      'en': "Don't have an account? ",
      'ru': 'Нет аккаунта? ',
    },
    'alreadyHaveAccountShort': {
      'en': 'Already have an account? ',
      'ru': 'Уже есть аккаунт? ',
    },
    'privacyNote': {
      'en':
          'Your health data is protected with end-to-end encryption. We comply with HIPAA and GDPR regulations to ensure your medical privacy.',
      'ru':
          'Ваши данные защищены сквозным шифрованием. Мы соблюдаем требования HIPAA и GDPR для обеспечения конфиденциальности.',
    },

    // Dashboard
    'goodMorning': {'en': 'Good morning', 'ru': 'Доброе утро'},
    'goodAfternoon': {'en': 'Good afternoon', 'ru': 'Добрый день'},
    'goodEvening': {'en': 'Good evening', 'ru': 'Добрый вечер'},
    'healthScore': {'en': 'Health Score', 'ru': 'Индекс здоровья'},
    'recommendedToday': {
      'en': 'Recommended today',
      'ru': 'Рекомендовано сегодня',
    },
    'insufficientDataBanner': {
      'en': 'Insufficient data for model recommendations.',
      'ru': 'Данных недостаточно',
    },
    'aiHealthScore': {'en': 'AI Health Score', 'ru': 'ИИ-оценка здоровья'},
    'noAccess': {'en': 'No access', 'ru': 'Нет доступа'},
    'calculating': {'en': 'Calculating', 'ru': 'Расчёт'},
    'stable': {'en': 'Stable', 'ru': 'Стабильно'},
    'attentionNeeded': {'en': 'Attention Needed', 'ru': 'Требует внимания'},
    'riskDetected': {'en': 'Risk Detected', 'ru': 'Обнаружен риск'},
    'aiInsight': {'en': 'AI Insight', 'ru': 'ИИ-аналитика'},
    'sleepImproved': {
      'en': 'Your sleep quality improved 12% this week',
      'ru': 'Качество сна улучшилось на 12% за неделю',
    },
    'healthMetrics': {'en': 'Health Metrics', 'ru': 'Показатели здоровья'},
    'modelResults': {'en': 'Model results', 'ru': 'Результаты моделей'},
    'aiRecommendationsToday': {
      'en': 'AI recommendations for today',
      'ru': 'AI-рекомендации на сегодня',
    },
    'todayMetrics': {'en': 'Today metrics', 'ru': 'Показатели сегодня'},
    'dashboardDisclaimer': {
      'en':
          'This assessment is advisory and does not replace consultation with a doctor.',
      'ru':
          'Оценка носит рекомендательный характер и не заменяет консультацию врача.',
    },
    'viewAll': {'en': 'View All', 'ru': 'Все'},
    'heartRate': {'en': 'Heart Rate', 'ru': 'Пульс'},
    'hrv': {'en': 'HRV', 'ru': 'HRV'},
    'sleep': {'en': 'Sleep', 'ru': 'Сон'},
    'stress': {'en': 'Stress', 'ru': 'Стресс'},
    'recovery': {'en': 'Recovery', 'ru': 'Восстановление'},
    'activeMinutes': {'en': 'Active minutes', 'ru': 'Активные минуты'},
    'sleepAiScore': {'en': 'Sleep AI Score', 'ru': 'ИИ-оценка сна'},
    'stressAiScore': {'en': 'Stress Load', 'ru': 'Напряжение'},
    'physiologyAnomalyScore': {
      'en': 'Physiology anomaly',
      'ru': 'Физиологическая аномалия',
    },
    'baselineDeviationScore': {
      'en': 'Baseline deviation',
      'ru': 'Отклонение от нормы',
    },
    'sleepAiConfidence': {'en': 'Confidence', 'ru': 'Уверенность'},
    'sleepAiReason': {'en': 'Reason', 'ru': 'Причина'},
    'sleepAiNoScore': {'en': 'No score yet', 'ru': 'Оценка пока недоступна'},
    'sleepAiStatusOk': {'en': 'Ready', 'ru': 'Готово'},
    'sleepAiStatusInsufficient': {
      'en': 'Insufficient data',
      'ru': 'Недостаточно данных',
    },
    'sleepAiStatusUnavailable': {'en': 'Unavailable', 'ru': 'Недоступно'},
    'activity': {'en': 'Activity', 'ru': 'Активность'},
    'runAIDiagnostics': {
      'en': 'Run AI Diagnostics',
      'ru': 'Запустить ИИ-диагностику',
    },
    'dashboardDataStatusUpToDate': {
      'en': 'Data is up to date',
      'ru': 'Данные актуальны',
    },
    'dashboardDataStatusInsufficient': {
      'en': 'Insufficient data',
      'ru': 'Данных недостаточно',
    },
    'dashboardDataStatusSyncRequired': {
      'en': 'Sync required',
      'ru': 'Требуется синхронизация',
    },
    'dashboardNoDataMessage': {
      'en': 'Not enough data for analysis',
      'ru': 'Недостаточно данных для анализа',
    },
    'dashboardNoDataHint': {
      'en': 'Connect a source or sync metrics to run model analysis.',
      'ru':
          'Подключите источник данных или синхронизируйте показатели, чтобы запустить анализ моделей.',
    },
    'openHealthSourcesCta': {
      'en': 'Open data sources',
      'ru': 'Открыть источники данных',
    },
    'dashboardTemporaryScoreBadge': {
      'en': 'Temporary score aggregation',
      'ru': 'Временная агрегация score',
    },
    'dashboardOverallSyncRequired': {
      'en': 'Sync required for a reliable health status.',
      'ru': 'Нужна синхронизация для корректной оценки состояния.',
    },
    'dashboardOverallInsufficient': {
      'en': 'Not enough data to compute a stable status.',
      'ru': 'Недостаточно данных для стабильной оценки состояния.',
    },
    'dashboardOverallStable': {
      'en': 'Overall state looks stable.',
      'ru': 'Общее состояние выглядит стабильным.',
    },
    'dashboardOverallAttention': {
      'en': 'There are signals that need attention.',
      'ru': 'Есть сигналы, которым стоит уделить внимание.',
    },
    'dashboardOverallRisk': {
      'en': 'Signs of recovery deviation are detected.',
      'ru': 'Есть признаки отклонения по восстановлению.',
    },
    'dashboardOverallNoAccess': {
      'en': 'Data access is limited for model analysis.',
      'ru': 'Доступ к данным ограничен для модельного анализа.',
    },
    'dashboardOverallTemporary': {
      'en': 'Temporary score built from available model outputs.',
      'ru': 'Временная оценка собрана из доступных результатов моделей.',
    },
    'dashboardOverallFactorsPending': {
      'en': 'Influencing factors are being clarified.',
      'ru': 'Факторы влияния уточняются по мере поступления данных.',
    },
    'dashboardOverallFactors': {
      'en': 'Main factors: {factors}.',
      'ru': 'Основные факторы: {factors}.',
    },
    'dashboardDiaryInfluenceTitle': {
      'en': 'Diary influence',
      'ru': 'Влияние дневника',
    },
    'dashboardDiaryInfluenceConfidence': {
      'en': 'Confidence',
      'ru': 'Уверенность',
    },
    'dashboardBadgeInsufficient': {
      'en': 'Insufficient data',
      'ru': 'Недостаточно данных',
    },
    'dashboardBadgeConfidence': {
      'en': '{value}% confidence',
      'ru': '{value}% уверенность',
    },
    'dashboardBadgeScoreOutOf100': {'en': '{value}/100', 'ru': '{value}/100'},
    'dashboardRecommendationPrefix': {
      'en': 'Recommendation: ',
      'ru': 'Рекомендация: ',
    },
    'dashboardActivitySummaryInsufficient': {
      'en': 'Activity model data is insufficient.',
      'ru': 'Недостаточно данных для оценки активности.',
    },
    'dashboardActivityExplainInsufficient': {
      'en': 'Add more wearable activity samples to detect your activity state.',
      'ru':
          'Добавьте больше данных активности с wearable-источника для распознавания состояния.',
    },
    'dashboardActivityRecInsufficient': {
      'en': 'Sync steps and heart rate during the day.',
      'ru': 'Синхронизируйте шаги и пульс в течение дня.',
    },
    'dashboardActivitySummary': {
      'en': 'Detected activity: {activity}.',
      'ru': 'Последняя активность: {activity}.',
    },
    'dashboardActivitySummaryRunningHigh': {
      'en': 'Detected activity: high-intensity running.',
      'ru': 'Последняя активность: бег высокой интенсивности.',
    },
    'dashboardActivitySummaryRunningModerate': {
      'en': 'Detected activity: moderate-intensity running.',
      'ru': 'Последняя активность: бег умеренной интенсивности.',
    },
    'dashboardActivitySummaryRunningLight': {
      'en': 'Detected activity: light running.',
      'ru': 'Последняя активность: лёгкий бег.',
    },
    'dashboardActivitySummaryWalk': {
      'en': 'Detected activity: walking.',
      'ru': 'Последняя активность: ходьба.',
    },
    'dashboardActivitySummarySitting': {
      'en': 'Detected activity: sitting.',
      'ru': 'Последняя активность: сидячее состояние.',
    },
    'dashboardActivitySummaryRest': {
      'en': 'Detected activity: rest.',
      'ru': 'Последняя активность: покой.',
    },
    'dashboardActivitySummaryUnknown': {
      'en': 'Detected activity: unavailable.',
      'ru': 'Последняя активность: недоступно.',
    },
    'dashboardActivityExplain': {
      'en': 'The model estimated your latest activity context.',
      'ru': 'Модель оценила ваш последний контекст активности.',
    },
    'dashboardActivityRecLow': {
      'en': 'Add a short walk to reduce sedentary load.',
      'ru': 'Добавьте короткую прогулку, чтобы снизить сидячую нагрузку.',
    },
    'dashboardActivityRecWalk': {
      'en': 'Keep a moderate pace and maintain regular movement.',
      'ru': 'Сохраняйте умеренный темп и регулярное движение.',
    },
    'dashboardActivityRecHigh': {
      'en': 'Keep recovery balance after intensive activity.',
      'ru': 'После интенсивной активности уделите внимание восстановлению.',
    },
    'dashboardSleepRecoveryTitle': {
      'en': 'Sleep and recovery',
      'ru': 'Сон и восстановление',
    },
    'dashboardSleepSummaryInsufficient': {
      'en': 'Sleep analysis is not available yet.',
      'ru': 'Анализ сна пока недоступен.',
    },
    'dashboardSleepExplainInsufficient': {
      'en': 'Need more sleep records to estimate recovery quality.',
      'ru': 'Нужно больше записей сна для оценки восстановления.',
    },
    'dashboardSleepRecInsufficient': {
      'en': 'Sync sleep sessions from your wearable source.',
      'ru': 'Синхронизируйте сессии сна из wearable-источника.',
    },
    'dashboardSleepDeviationUnavailable': {
      'en': 'Sleep duration deviation from baseline is unavailable.',
      'ru': 'Отклонение длительности сна от нормы пока недоступно.',
    },
    'dashboardSleepDeviationAbove': {
      'en': 'Sleep duration is above baseline by {minutes} min.',
      'ru': 'Длительность сна выше нормы на {minutes} мин.',
    },
    'dashboardSleepDeviationBelow': {
      'en': 'Sleep duration is below baseline by {minutes} min.',
      'ru': 'Длительность сна ниже нормы на {minutes} мин.',
    },
    'dashboardSleepSummary': {
      'en': 'Sleep score {score}/100, duration {hours} h.',
      'ru': 'Sleep score {score}/100, длительность {hours} ч.',
    },
    'dashboardSleepRecLow': {
      'en': 'Prioritize earlier sleep time and reduce evening load.',
      'ru': 'Сместите отход ко сну раньше и снизьте вечернюю нагрузку.',
    },
    'dashboardSleepRecGood': {
      'en': 'Maintain current sleep routine for stable recovery.',
      'ru': 'Сохраняйте текущий режим сна для стабильного восстановления.',
    },
    'dashboardStressSummaryInsufficient': {
      'en': 'Stress assessment is not available yet.',
      'ru': 'Оценка стресса пока недоступна.',
    },
    'dashboardStressExplainInsufficient': {
      'en': 'Need HR/HRV and sleep context to estimate stress load.',
      'ru': 'Нужны данные HR/HRV и сна для оценки стресс-нагрузки.',
    },
    'dashboardStressRecInsufficient': {
      'en': 'Sync heart and sleep metrics to improve stress estimation.',
      'ru': 'Синхронизируйте пульс и сон для более точной оценки стресса.',
    },
    'dashboardStressFactorsUnavailable': {
      'en': 'Contributing factors are currently unavailable.',
      'ru': 'Факторы влияния сейчас недоступны.',
    },
    'dashboardStressFactors': {
      'en': 'Factors: {factors}.',
      'ru': 'Факторы: {factors}.',
    },
    'dashboardStressSummary': {
      'en': 'Stress level: {level}.',
      'ru': 'Уровень стресса: {level}.',
    },
    'dashboardStressSummaryHigh': {
      'en': 'Stress level: high.',
      'ru': 'Уровень стресса: высокий.',
    },
    'dashboardStressSummaryModerate': {
      'en': 'Stress level: moderate.',
      'ru': 'Уровень стресса: умеренный.',
    },
    'dashboardStressSummaryLow': {
      'en': 'Stress level: low.',
      'ru': 'Уровень стресса: низкий.',
    },
    'dashboardStressRecHigh': {
      'en': 'Take short recovery breaks and lower intensity today.',
      'ru':
          'Сделайте короткие паузы на восстановление и снизьте интенсивность сегодня.',
    },
    'dashboardStressRecModerate': {
      'en': 'Add 3-5 minutes of breathing practice between tasks.',
      'ru': 'Добавьте дыхательную паузу на 3–5 минут между задачами.',
    },
    'dashboardStressRecLow': {
      'en': 'Stress load is low, maintain your current pace.',
      'ru': 'Стресс-нагрузка низкая, поддерживайте текущий темп.',
    },
    'dashboardBaselineTitle': {'en': 'Personal baseline', 'ru': 'Личная норма'},
    'dashboardBaselineSummaryInsufficient': {
      'en': 'Baseline comparison is unavailable.',
      'ru': 'Сравнение с личной нормой недоступно.',
    },
    'dashboardBaselineExplainInsufficient': {
      'en': 'Need more historical samples to form baseline.',
      'ru': 'Нужно больше исторических данных для формирования baseline.',
    },
    'dashboardBaselineRecInsufficient': {
      'en': 'Keep regular sync for at least several days.',
      'ru': 'Поддерживайте регулярную синхронизацию в течение нескольких дней.',
    },
    'dashboardBaselineSummary': {
      'en': 'Baseline deviation score: {score}/100.',
      'ru': 'Оценка отклонений от baseline: {score}/100.',
    },
    'dashboardBaselineExplain': {'en': '{line}', 'ru': '{line}'},
    'dashboardBaselineRecHigh': {
      'en': 'Deviation is moderate, keep the routine stable.',
      'ru': 'Отклонение умеренное, сохраняйте стабильный режим.',
    },
    'dashboardBaselineRecLow': {
      'en': 'Deviation is elevated, reduce load and monitor recovery.',
      'ru':
          'Отклонение повышено, снизьте нагрузку и отслеживайте восстановление.',
    },
    'dashboardRecoveryTitle': {
      'en': 'Recovery and anomalies',
      'ru': 'Recovery / отклонения',
    },
    'dashboardRecoverySummaryInsufficient': {
      'en': 'Recovery analysis is unavailable yet.',
      'ru': 'Анализ восстановления пока недоступен.',
    },
    'dashboardRecoveryExplainInsufficient': {
      'en': 'Need more physiological signals to evaluate recovery.',
      'ru': 'Нужно больше физиологических сигналов для оценки восстановления.',
    },
    'dashboardRecoveryRecInsufficient': {
      'en': 'Continue syncing HR, HRV and sleep data.',
      'ru': 'Продолжайте синхронизировать данные HR, HRV и сна.',
    },
    'dashboardRecoverySummary': {
      'en': 'Recovery score: {score}/100.',
      'ru': 'Recovery score: {score}/100.',
    },
    'dashboardRecoveryExplain': {'en': '{reason}', 'ru': '{reason}'},
    'dashboardRecoveryRecHigh': {
      'en': 'Recovery looks stable, maintain balanced daily load.',
      'ru': 'Восстановление выглядит стабильным, сохраняйте баланс нагрузки.',
    },
    'dashboardRecoveryRecLow': {
      'en': 'Recovery has deviations, choose lighter activity today.',
      'ru':
          'Есть отклонения восстановления, выберите более лёгкую активность сегодня.',
    },
    'dashboardAiSyncText': {
      'en': 'Sync wearable data first',
      'ru': 'Сначала синхронизируйте wearable-данные',
    },
    'dashboardAiSyncReason': {
      'en': 'Without recent samples, model recommendations lose relevance.',
      'ru': 'Без свежих данных рекомендации моделей теряют актуальность.',
    },
    'dashboardAiSleepText': {
      'en': 'Prioritize recovery-focused sleep',
      'ru': 'Сделайте акцент на восстановительном сне',
    },
    'dashboardAiSleepReason': {
      'en': 'Sleep score is below target, so lighter pacing may help.',
      'ru':
          'Sleep score ниже целевого, поэтому сегодня полезен более мягкий темп.',
    },
    'dashboardAiStressText': {
      'en': 'Reduce stress load with short pauses',
      'ru': 'Снизьте стресс-нагрузку короткими паузами',
    },
    'dashboardAiStressReason': {
      'en': 'Stress level is moderate/high based on current signals.',
      'ru': 'Уровень стресса умеренный/высокий по текущим сигналам.',
    },
    'dashboardAiActivityText': {
      'en': 'Add light movement during the day',
      'ru': 'Добавьте лёгкое движение в течение дня',
    },
    'dashboardAiActivityReason': {
      'en': 'Low activity context detected, short walk can improve score.',
      'ru':
          'Обнаружен низкий уровень активности, короткая прогулка может улучшить score.',
    },
    'dashboardAiStableText': {
      'en': 'Keep current routine',
      'ru': 'Сохраняйте текущий режим',
    },
    'dashboardAiStableReason': {
      'en': 'Current model outputs do not show notable recovery risks.',
      'ru': 'Текущие результаты моделей не показывают выраженных рисков.',
    },
    'recNoAccess1': {
      'en': 'Connect a health source for better score accuracy.',
      'ru': 'Подключите источник здоровья для более точной оценки.',
    },
    'recNoAccess2': {
      'en': 'Share at least steps, heart rate, and sleep.',
      'ru': 'Передайте хотя бы шаги, пульс и сон.',
    },
    'recNoAccess3': {
      'en': 'Add manual vitals until wearable data is available.',
      'ru':
          'Добавляйте показатели вручную, пока нет данных с носимых устройств.',
    },
    'recCalculating1': {
      'en': 'We are processing your latest metrics.',
      'ru': 'Мы обрабатываем ваши последние метрики.',
    },
    'recCalculating2': {
      'en': 'Keep syncing steps, sleep and heart rate.',
      'ru': 'Продолжайте синхронизировать шаги, сон и пульс.',
    },
    'recCalculating3': {
      'en': 'Score will update once enough data is collected.',
      'ru': 'Оценка обновится, когда соберется достаточно данных.',
    },
    'recRisk1': {
      'en': 'Sleep before 23:30 and target 7+ hours.',
      'ru': 'Ложитесь до 23:30 и спите не меньше 7 часов.',
    },
    'recRisk2': {
      'en': 'Keep light activity at least 30 min/day.',
      'ru': 'Поддерживайте лёгкую активность минимум 30 минут в день.',
    },
    'recRisk3': {
      'en': 'Track blood pressure and glucose daily.',
      'ru': 'Ежедневно отслеживайте давление и глюкозу.',
    },
    'recAttention1': {
      'en': 'Walk at least 7,000 steps today.',
      'ru': 'Пройдите сегодня не менее 7 000 шагов.',
    },
    'recAttention2': {
      'en': 'Hydrate well and reduce evening sugar.',
      'ru': 'Поддерживайте гидратацию и снизьте сахар вечером.',
    },
    'recAttention3': {
      'en': 'Stabilize bedtime for better recovery.',
      'ru': 'Стабилизируйте время сна для лучшего восстановления.',
    },
    'recStable1': {
      'en': 'Walk at least 7,000 steps.',
      'ru': 'Проходите не менее 7 000 шагов в день.',
    },
    'recStable2': {
      'en': 'Sleep before 23:30 for recovery.',
      'ru': 'Ложитесь до 23:30 для лучшего восстановления.',
    },
    'recStable3': {
      'en': 'Drink 2L water and reduce sugar spikes.',
      'ru': 'Пейте 2 литра воды и избегайте резких скачков сахара.',
    },
    'modelRecInsufficient1': {
      'en':
          'Connect Apple Health or Google Health to unlock AI recommendations.',
      'ru':
          'Подключите Apple Health или Google Health, чтобы включить ИИ-рекомендации.',
    },
    'modelRecInsufficient2': {
      'en': 'Keep syncing at least steps and heart rate for 7 days.',
      'ru': 'Синхронизируйте хотя бы шаги и пульс в течение 7 дней.',
    },
    'modelRecInsufficient3': {
      'en': 'Add profile metrics (height, weight, age) to improve accuracy.',
      'ru': 'Добавьте профильные метрики (рост, вес, возраст) для точности.',
    },
    'modelRecRecovery1': {
      'en': 'Increase daily movement gradually: target +1,500 steps this week.',
      'ru':
          'Постепенно увеличьте движение: цель +1 500 шагов в день на этой неделе.',
    },
    'modelRecRecovery2': {
      'en': 'Prioritize recovery sleep: 7-8 hours with stable bedtime.',
      'ru':
          'Сделайте упор на восстановление: 7-8 часов сна и стабильный режим.',
    },
    'modelRecRecovery3': {
      'en': 'Add two light 20-minute walks to reduce sedentary load.',
      'ru':
          'Добавьте две лёгкие прогулки по 20 минут для снижения малоподвижности.',
    },
    'modelRecBuild1': {
      'en': 'Maintain momentum: keep moderate activity 30-40 min daily.',
      'ru':
          'Сохраняйте темп: поддерживайте умеренную активность 30-40 минут в день.',
    },
    'modelRecBuild2': {
      'en':
          'Combine steps with cardio zones: monitor resting heart rate trend.',
      'ru':
          'Комбинируйте шаги с кардиозонами: отслеживайте тренд пульса покоя.',
    },
    'modelRecBuild3': {
      'en': 'Hydration and post-workout recovery will stabilize performance.',
      'ru':
          'Гидратация и восстановление после нагрузки стабилизируют показатели.',
    },
    'modelRecPerformance1': {
      'en':
          'High activity detected: schedule active recovery days to avoid overtraining.',
      'ru':
          'Обнаружена высокая нагрузка: добавляйте дни активного восстановления.',
    },
    'modelRecPerformance2': {
      'en': 'Track sleep depth and resting HR to keep training quality high.',
      'ru':
          'Контролируйте глубину сна и пульс покоя для сохранения качества тренировок.',
    },
    'modelRecPerformance3': {
      'en': 'Balance intensity with nutrition to maintain stable health score.',
      'ru':
          'Балансируйте интенсивность и питание для стабильного индекса здоровья.',
    },

    // Wellbeing
    'wellbeing': {'en': 'Wellbeing', 'ru': 'Самочувствие'},
    'wellbeingCalendar': {
      'en': 'Wellbeing calendar',
      'ru': 'Календарь самочувствия',
    },
    'trackDailyMoodAndMentalState': {
      'en': 'Track your daily mood and mental state',
      'ru': 'Отслеживайте настроение и ментальное состояние каждый день',
    },
    'march2026': {'en': 'March 2026', 'ru': 'Март 2026'},
    'sun': {'en': 'SU', 'ru': 'ВС'},
    'mon': {'en': 'MO', 'ru': 'ПН'},
    'tue': {'en': 'TU', 'ru': 'ВТ'},
    'wed': {'en': 'WE', 'ru': 'СР'},
    'thu': {'en': 'TH', 'ru': 'ЧТ'},
    'fri': {'en': 'FR', 'ru': 'ПТ'},
    'sat': {'en': 'SA', 'ru': 'СБ'},
    'veryLow': {'en': 'Very low', 'ru': 'Очень низко'},
    'low': {'en': 'Low', 'ru': 'Низко'},
    'neutral': {'en': 'Neutral', 'ru': 'Нейтрально'},
    'good': {'en': 'Good', 'ru': 'Хорошо'},
    'great': {'en': 'Great', 'ru': 'Отлично'},
    'todaysCheckIn': {'en': "Today's check-in", 'ru': 'Запись за сегодня'},
    'howDidYourDayFeelOverall': {
      'en': 'How did your day feel overall?',
      'ru': 'Как в целом прошёл ваш день?',
    },
    'calm': {'en': 'Calm', 'ru': 'Спокойно'},
    'okay': {'en': 'Okay', 'ru': 'Нормально'},
    'tense': {'en': 'Tense', 'ru': 'Напряжённо'},
    'tags': {'en': 'Tags', 'ru': 'Теги'},
    'focused': {'en': 'Focused', 'ru': 'Сфокусированно'},
    'productive': {'en': 'Productive', 'ru': 'Продуктивно'},
    'social': {'en': 'Social', 'ru': 'Социально'},
    'tired': {'en': 'Tired', 'ru': 'Усталость'},
    'grateful': {'en': 'Grateful', 'ru': 'Благодарность'},
    'addTodaysEntry': {
      'en': "Add today's entry",
      'ru': 'Добавить запись за сегодня',
    },
    'logYourStateOfMind': {
      'en': 'Log your state of mind',
      'ru': 'Отметьте своё состояние',
    },
    'rightNow': {'en': 'Right now', 'ru': 'Сейчас'},
    'todayOverall': {'en': 'Today overall', 'ru': 'Сегодня в целом'},
    'howAreYouFeelingQuestion': {
      'en': 'How are you feeling?',
      'ru': 'Как вы себя чувствуете?',
    },
    'moveFromVeryUnpleasantToVeryPleasant': {
      'en': 'Move from very unpleasant to very pleasant',
      'ru': 'От очень неприятного к очень приятному',
    },
    'stressCalibration': {
      'en': 'Stress calibration',
      'ru': 'Калибровка стресса',
    },
    'stressCalibrationSubtitle': {
      'en': 'These 1-5 ratings help calibrate the stress model',
      'ru': 'Оценки 1-5 помогают калибровать модель стресса',
    },
    'stressNow': {'en': 'Stress now', 'ru': 'Стресс сейчас'},
    'fatigueNow': {'en': 'Fatigue now', 'ru': 'Усталость сейчас'},
    'wellnessNow': {'en': 'Wellbeing now', 'ru': 'Самочувствие сейчас'},
    'high': {'en': 'High', 'ru': 'Высоко'},
    'poor': {'en': 'Poor', 'ru': 'Плохо'},
    'whatDescribesYourDay': {
      'en': 'What describes your day?',
      'ru': 'Что описывает ваш день?',
    },
    'anxious': {'en': 'Anxious', 'ru': 'Тревожно'},
    'overloaded': {'en': 'Overloaded', 'ru': 'Перегруженно'},
    'restless': {'en': 'Restless', 'ru': 'Беспокойно'},
    'mainFactors': {'en': 'Main factors', 'ru': 'Основные факторы'},
    'work': {'en': 'Work', 'ru': 'Работа'},
    'family': {'en': 'Family', 'ru': 'Семья'},
    'friends': {'en': 'Friends', 'ru': 'Друзья'},
    'exercise': {'en': 'Exercise', 'ru': 'Тренировка'},
    'weather': {'en': 'Weather', 'ru': 'Погода'},
    'optionalNoteExample': {
      'en':
          'Optional note: Today felt calmer after a short walk and enough sleep.',
      'ru':
          'Необязательная заметка: сегодня было спокойнее после короткой прогулки и достаточного сна.',
    },
    'selectMoodToSave': {
      'en': 'Please select your mood first',
      'ru': 'Сначала выберите текущее состояние',
    },
    'checkInSaveFailed': {
      'en': 'Failed to save your check-in',
      'ru': 'Не удалось сохранить запись',
    },
    'entryDate': {'en': 'Entry date', 'ru': 'Дата записи'},
    'pickDate': {'en': 'Pick date', 'ru': 'Выбрать дату'},
    'note': {'en': 'Note', 'ru': 'Заметка'},
    'writeNote': {
      'en': 'Write how your day went',
      'ru': 'Опишите, как прошёл день',
    },
    'checkInForDate': {'en': 'Entry for date', 'ru': 'Запись за дату'},
    'editEntry': {'en': 'Edit entry', 'ru': 'Редактировать запись'},
    'viewMode': {'en': 'View mode', 'ru': 'Режим просмотра'},
    'tapEditToUpdate': {
      'en': 'Tap the pencil icon to update this entry',
      'ru': 'Нажмите на карандаш, чтобы изменить запись',
    },
    'updateCheckIn': {'en': 'Update check-in', 'ru': 'Обновить запись'},
    'cancel': {'en': 'Cancel', 'ru': 'Отмена'},
    'done': {'en': 'Done', 'ru': 'Готово'},
    'saveCheckIn': {'en': 'Save check-in', 'ru': 'Сохранить запись'},

    // Data Input
    'manualInput': {'en': 'Manual Input', 'ru': 'Ручной ввод'},
    'step3of4': {'en': 'Step 3 of 4', 'ru': 'Шаг 3 из 4'},
    'basicHealthData': {
      'en': 'Basic health data',
      'ru': 'Базовые данные здоровья',
    },
    'basicHealthDataDesc': {
      'en': 'Add a few core metrics to personalize recommendations',
      'ru': 'Добавьте несколько ключевых метрик для персональных рекомендаций',
    },
    'firstName': {'en': 'First name', 'ru': 'Имя'},
    'lastName': {'en': 'Last name', 'ru': 'Фамилия'},
    'height': {'en': 'Height', 'ru': 'Рост'},
    'age': {'en': 'Age', 'ru': 'Возраст'},
    'sex': {'en': 'Sex', 'ru': 'Пол'},
    'male': {'en': 'Male', 'ru': 'Мужской'},
    'female': {'en': 'Female', 'ru': 'Женский'},
    'updateValuesLater': {
      'en': 'You can update these values later in Settings',
      'ru': 'Эти значения можно изменить позже в Настройках',
    },
    'recordMeasurements': {
      'en': 'Record your health measurements',
      'ru': 'Запишите ваши измерения',
    },
    'bloodPressure': {'en': 'Blood Pressure', 'ru': 'Давление'},
    'systolic': {'en': 'Systolic', 'ru': 'Систолическое'},
    'diastolic': {'en': 'Diastolic', 'ru': 'Диастолическое'},
    'bloodGlucose': {'en': 'Blood Glucose', 'ru': 'Глюкоза в крови'},
    'enterValue': {'en': 'Enter value', 'ru': 'Введите значение'},
    'temperature': {'en': 'Temperature', 'ru': 'Температура'},
    'date': {'en': 'Date', 'ru': 'Дата'},
    'time': {'en': 'Time', 'ru': 'Время'},
    'symptoms': {'en': 'Symptoms', 'ru': 'Симптомы'},
    'headache': {'en': 'Headache', 'ru': 'Головная боль'},
    'fatigue': {'en': 'Fatigue', 'ru': 'Усталость'},
    'dizziness': {'en': 'Dizziness', 'ru': 'Головокружение'},
    'chestPain': {'en': 'Chest pain', 'ru': 'Боль в груди'},
    'shortnessOfBreath': {'en': 'Shortness of breath', 'ru': 'Одышка'},
    'nausea': {'en': 'Nausea', 'ru': 'Тошнота'},
    'musclePain': {'en': 'Muscle pain', 'ru': 'Боль в мышцах'},
    'fever': {'en': 'Fever', 'ru': 'Жар'},
    'saveData': {'en': 'Save Data', 'ru': 'Сохранить'},
    'dataSaved': {'en': 'Data Saved', 'ru': 'Данные сохранены'},
    'dataSavedDesc': {
      'en': 'Your health data has been recorded successfully.',
      'ru': 'Ваши данные успешно записаны.',
    },
    'systolicError': {
      'en': 'Systolic should be between 70-200',
      'ru': 'Систолическое должно быть 70-200',
    },
    'glucoseError': {
      'en': 'Glucose should be between 50-400',
      'ru': 'Глюкоза должна быть 50-400',
    },
    'temperatureError': {
      'en': 'Temperature should be between 95-108°F',
      'ru': 'Температура должна быть 35-42°C',
    },

    // Analytics
    'healthAnalytics': {'en': 'Health Analytics', 'ru': 'Аналитика здоровья'},
    'export': {'en': 'Export', 'ru': 'Экспорт'},
    'exportDataTitle': {'en': 'Data export', 'ru': 'Экспорт данных'},
    'exportDataSubtitle': {
      'en': 'Copy structured health data for AI or a doctor.',
      'ru':
          'Скопируйте структурированные данные о состоянии, чтобы вставить их в нейросеть или показать врачу.',
    },
    'exportSensitiveWarning': {
      'en':
          'You are copying sensitive medical data. Share it only with services you trust.',
      'ru':
          'Вы копируете медицинские данные. Вставляйте их только в сервисы, которым доверяете.',
    },
    'exportPeriod': {'en': 'Period', 'ru': 'Период'},
    'exportToday': {'en': 'Today', 'ru': 'Сегодня'},
    'exportYesterday': {'en': 'Yesterday', 'ru': 'Вчера'},
    'exportLast7Days': {'en': 'Last 7 days', 'ru': '7 дней'},
    'exportLast30Days': {'en': 'Last 30 days', 'ru': '30 дней'},
    'exportChooseRange': {'en': 'Choose range', 'ru': 'Выбрать период'},
    'exportWhat': {'en': 'What to export', 'ru': 'Что экспортировать'},
    'exportPulse': {'en': 'Pulse', 'ru': 'Пульс'},
    'exportRecommendations': {'en': 'Recommendations', 'ru': 'Рекомендации'},
    'exportRawMetrics': {'en': 'Raw metrics', 'ru': 'Сырые показатели'},
    'exportOnlyAnomalies': {
      'en': 'Only deviations',
      'ru': 'Только отклонения от нормы',
    },
    'exportFormatTitle': {'en': 'Format', 'ru': 'Формат'},
    'exportFormatAi': {'en': 'For AI', 'ru': 'Для нейросети'},
    'exportFormatDoctor': {'en': 'For doctor', 'ru': 'Для врача'},
    'exportFormatMarkdown': {'en': 'Markdown', 'ru': 'Markdown'},
    'exportFormatJson': {'en': 'JSON', 'ru': 'JSON'},
    'exportFormatCsv': {'en': 'CSV', 'ru': 'CSV'},
    'exportFormatShort': {'en': 'Short', 'ru': 'Кратко'},
    'exportFormatDetailed': {'en': 'Detailed report', 'ru': 'Подробный отчёт'},
    'exportPromptTitle': {'en': 'AI prompt', 'ru': 'Промт для нейросети'},
    'exportPromptAssess': {
      'en': 'Assess my state',
      'ru': 'Оцени моё состояние',
    },
    'exportPromptAnomalies': {
      'en': 'Find anomalies',
      'ru': 'Найди возможные отклонения',
    },
    'exportPromptRecommendations': {
      'en': 'Recommend my day',
      'ru': 'Составь рекомендации на день',
    },
    'exportPromptDoctorQuestions': {
      'en': 'Questions for doctor',
      'ru': 'Подготовь вопросы врачу',
    },
    'exportPromptSimple': {
      'en': 'Explain simply',
      'ru': 'Объясни простыми словами',
    },
    'exportPromptCustom': {
      'en': 'Custom prompt',
      'ru': 'Пользовательский промт',
    },
    'exportPromptCustomHint': {
      'en': 'Describe what AI should do with the export.',
      'ru': 'Опишите, что нейросеть должна сделать с этими данными.',
    },
    'exportIncludePersonalData': {
      'en': 'Include personal data',
      'ru': 'Включить личные данные',
    },
    'exportIncludePersonalDataHint': {
      'en': 'Disabled by default to keep export de-identified.',
      'ru': 'По умолчанию выключено, чтобы экспорт оставался обезличенным.',
    },
    'exportPreviewTitle': {'en': 'Preview', 'ru': 'Preview'},
    'exportActionsTitle': {'en': 'Actions', 'ru': 'Действия'},
    'exportCopyCurrent': {
      'en': 'Copy current format',
      'ru': 'Скопировать текущий формат',
    },
    'exportCopyAi': {'en': 'Copy for AI', 'ru': 'Скопировать для нейросети'},
    'exportCopyDoctor': {
      'en': 'Copy for doctor',
      'ru': 'Скопировать отчёт для врача',
    },
    'exportSaveFile': {'en': 'Export file', 'ru': 'Экспортировать файл'},
    'exportCopied': {'en': 'Data copied', 'ru': 'Данные скопированы'},
    'exportFileCreated': {
      'en': 'File created: {file}',
      'ru': 'Файл создан: {file}',
    },
    'exportShareFailed': {
      'en': 'Unable to export or share file.',
      'ru': 'Не удалось экспортировать или отправить файл.',
    },
    'exportLoading': {
      'en': 'Collecting data for export.',
      'ru': 'Собираем данные для экспорта.',
    },
    'exportPartialData': {
      'en': 'Part of the requested data is missing',
      'ru': 'Часть данных отсутствует',
    },
    'exportNoData': {
      'en': 'Not enough data for export.',
      'ru': 'Недостаточно данных для экспорта.',
    },
    'exportNoDataHint': {
      'en': 'Choose another period or sync health data.',
      'ru':
          'Недостаточно данных для экспорта. Попробуйте другой период или синхронизируйте данные.',
    },
    'exportReadyState': {
      'en': 'Ready: {records} records from {sources} sources.',
      'ru': 'Готово: {records} записей из {sources} источников.',
    },
    'exportSoftError': {
      'en': 'Unable to prepare export right now.',
      'ru': 'Не удалось подготовить экспорт. Попробуйте ещё раз.',
    },
    'trackTrendsMetricsShared': {
      'en': 'Track trends for the metrics you shared',
      'ru': 'Отслеживайте тренды по метрикам, которыми вы поделились',
    },
    'detailedInsights': {
      'en': 'Detailed insights into your health data',
      'ru': 'Подробный анализ ваших данных',
    },
    'day': {'en': 'Day', 'ru': 'День'},
    'week': {'en': 'Week', 'ru': 'Неделя'},
    'month': {'en': 'Month', 'ru': 'Месяц'},
    'year': {'en': 'Year', 'ru': 'Год'},
    'average': {'en': 'Average', 'ru': 'Среднее'},
    'dailySteps': {'en': 'Daily Steps', 'ru': 'Шаги за день'},
    'weeklyAverage': {'en': 'Weekly average', 'ru': 'Среднее за неделю'},
    'aiInsights': {'en': 'AI Insights', 'ru': 'ИИ-аналитика'},
    'elevatedHeartRate': {
      'en': 'Elevated Heart Rate Detected',
      'ru': 'Обнаружен повышенный пульс',
    },
    'elevatedHeartRateDesc': {
      'en': 'Your resting heart rate was 15% higher than usual on Tuesday.',
      'ru': 'Ваш пульс в покое был на 15% выше обычного во вторник.',
    },
    'sleepQualityImproving': {
      'en': 'Sleep Quality Improving',
      'ru': 'Качество сна улучшается',
    },
    'sleepQualityDesc': {
      'en': 'Your deep sleep has increased by 18% over the past week.',
      'ru': 'Глубокий сон увеличился на 18% за последнюю неделю.',
    },
    'activityGoalAtRisk': {
      'en': 'Activity Goal at Risk',
      'ru': 'Цель активности под угрозой',
    },
    'activityGoalDesc': {
      'en': 'Based on current trends, you may miss your weekly step goal.',
      'ru':
          'Исходя из текущих тенденций, вы можете не достичь недельной цели по шагам.',
    },
    'heartRateTrend': {'en': 'Heart rate trend', 'ru': 'Тренд пульса'},
    'noStepsDataYet': {
      'en': 'No steps data yet',
      'ru': 'Пока нет данных по шагам',
    },
    'noHeartRateDataYet': {
      'en': 'No heart rate data yet',
      'ru': 'Пока нет данных по пульсу',
    },
    'dataQualityBreakdown': {
      'en': 'Data quality breakdown',
      'ru': 'Сводка качества данных',
    },
    'recordsLoaded': {'en': 'Records loaded', 'ru': 'Загружено записей'},
    'connectedSources': {
      'en': 'Connected sources',
      'ru': 'Подключенные источники',
    },
    'aiInsightNoData': {
      'en': 'AI: not enough data yet. Sync health data to generate insights.',
      'ru':
          'ИИ: пока недостаточно данных. Синхронизируйте данные здоровья для рекомендаций.',
    },
    'aiInsightElevatedHeartRate': {
      'en': 'AI: resting heart rate is elevated, keep workload moderate today.',
      'ru': 'ИИ: пульс в покое повышен, сегодня держите умеренную нагрузку.',
    },
    'aiInsightActivityGoalAtRisk': {
      'en': 'AI: activity target is at risk, add 20-30 min of walking.',
      'ru': 'ИИ: цель активности под риском, добавьте 20–30 минут ходьбы.',
    },
    'aiInsightSleepQualityImproving': {
      'en': 'AI: recovery trend is improving, keep your routine stable.',
      'ru': 'ИИ: тренд восстановления улучшается, держите режим стабильным.',
    },
    'aiInsightAnalyzing': {
      'en': 'AI: health data is being analyzed.',
      'ru': 'ИИ: данные здоровья анализируются.',
    },

    // Reports
    'exportAndShare': {
      'en': 'Export and share your health reports',
      'ru': 'Экспортируйте и делитесь отчётами',
    },
    'exportSuccess': {
      'en': 'Exported {items} records from {sources} sources',
      'ru': 'Экспортировано {items} записей из {sources} источников',
    },
    'all': {'en': 'All', 'ru': 'Все'},
    'summary': {'en': 'Summary', 'ru': 'Сводка'},
    'aiReports': {'en': 'AI Reports', 'ru': 'ИИ-отчёты'},
    'trends': {'en': 'Trends', 'ru': 'Тренды'},
    'quickExport': {'en': 'Quick Export', 'ru': 'Быстрый экспорт'},
    'share': {'en': 'Share', 'ru': 'Поделиться'},
    'recentReports': {'en': 'Recent Reports', 'ru': 'Последние отчёты'},
    'filter': {'en': 'Filter', 'ru': 'Фильтр'},
    'weeklyHealthSummary': {
      'en': 'Weekly Health Summary',
      'ru': 'Еженедельная сводка',
    },
    'aiDiagnosticsReport': {
      'en': 'AI Diagnostics Report',
      'ru': 'Отчёт ИИ-диагностики',
    },
    'monthlyTrendsAnalysis': {
      'en': 'Monthly Trends Analysis',
      'ru': 'Месячный анализ трендов',
    },
    'heartRateAnalysis': {'en': 'Heart Rate Analysis', 'ru': 'Анализ пульса'},
    'processing': {'en': 'Processing', 'ru': 'Обработка'},
    'records': {'en': 'Records', 'ru': 'Записи'},
    'sources': {'en': 'Sources', 'ru': 'Источники'},
    'metricTypes': {'en': 'Metric types', 'ru': 'Типы метрик'},
    'importedHealthData': {
      'en': 'Imported health data',
      'ru': 'Импортированные данные здоровья',
    },
    'noSamplesFound': {
      'en': 'No samples found yet. Connect services and retry.',
      'ru': 'Пока нет данных. Подключите сервисы и повторите.',
    },

    // Profile
    'edit': {'en': 'Edit', 'ru': 'Изменить'},
    'accountOverview': {'en': 'Account overview', 'ru': 'Обзор аккаунта'},
    'premium': {'en': 'Premium', 'ru': 'Премиум'},
    'score': {'en': 'Score', 'ru': 'Оценка'},
    'streak': {'en': 'Streak', 'ru': 'Серия'},
    'personalInfo': {'en': 'Personal info', 'ru': 'Личная информация'},
    'heightWeight': {'en': 'Height / Weight', 'ru': 'Рост / Вес'},
    'connectedServices': {
      'en': 'Connected Services',
      'ru': 'Подключённые сервисы',
    },
    'appleHealth': {'en': 'Apple Health', 'ru': 'Apple Health'},
    'googleHealth': {'en': 'Google Health', 'ru': 'Google Health'},
    'settings': {'en': 'Settings', 'ru': 'Настройки'},
    'notifications': {'en': 'Notifications', 'ru': 'Уведомления'},
    'healthAlertsReminders': {
      'en': 'Health alerts & reminders',
      'ru': 'Оповещения и напоминания',
    },
    'darkMode': {'en': 'Dark Mode', 'ru': 'Тёмная тема'},
    'reduceEyeStrain': {
      'en': 'Reduce eye strain',
      'ru': 'Снижение нагрузки на глаза',
    },
    'dataSyncFrequency': {
      'en': 'Data Sync Frequency',
      'ru': 'Частота синхронизации',
    },
    'every30Min': {'en': 'Every 30 min', 'ru': 'Каждые 30 мин'},
    'language': {'en': 'Language', 'ru': 'Язык'},
    'english': {'en': 'English', 'ru': 'English'},
    'russian': {'en': 'Русский', 'ru': 'Русский'},
    'security': {'en': 'Security', 'ru': 'Безопасность'},
    'dataEncryption': {'en': 'Data Encryption', 'ru': 'Шифрование данных'},
    'dataEncryptionEnabled': {
      'en': 'Data encryption enabled',
      'ru': 'Шифрование данных включено',
    },
    'encryptionDesc': {
      'en':
          'Your health data is encrypted with AES-256 encryption and stored securely. We comply with HIPAA and GDPR regulations.',
      'ru':
          'Ваши данные зашифрованы AES-256 и надёжно хранятся. Мы соблюдаем требования HIPAA и GDPR.',
    },
    'privacyDataSourcesAndPreferences': {
      'en': 'Privacy, data sources and preferences',
      'ru': 'Приватность, источники данных и предпочтения',
    },
    'healthSourcesSummary': {
      'en': 'Google Health, Apple Health',
      'ru': 'Google Health, Apple Health',
    },
    'personalDataAndAccount': {
      'en': 'Personal data and account',
      'ru': 'Личные данные и аккаунт',
    },
    'debugLogs': {'en': 'Debug logs', 'ru': 'Логи отладки'},
    'debugLogsSubtitle': {
      'en': 'Auth, Supabase, state transitions and errors',
      'ru': 'Авторизация, Supabase, переходы состояния и ошибки',
    },
    'sleepModelDebug': {'en': 'Sleep model debug', 'ru': 'Отладка модели сна'},
    'sleepModelDebugSubtitle': {
      'en': 'Replay model inference on historical wearable data',
      'ru': 'Прогон инференса на исторических wearable-данных',
    },
    'sleepModelDebugRun2130': {
      'en': 'Run D-30..D-21',
      'ru': 'Прогнать D-30..D-21',
    },
    'sleepModelDebugRunAll': {
      'en': 'Run full history',
      'ru': 'Прогнать всю историю',
    },
    'sleepModelDebugNoRows': {
      'en': 'No run results yet. Start one of the scenarios above.',
      'ru': 'Результатов пока нет. Запустите один из сценариев выше.',
    },
    'stressModelDebug': {
      'en': 'Stress model debug',
      'ru': 'Отладка модели стресса',
    },
    'stressModelDebugSubtitle': {
      'en': 'Replay stress inference on account wearable history',
      'ru': 'Прогон оценки стресса на wearable-истории аккаунта',
    },
    'stressModelDebugRunRecent': {
      'en': 'Run last 7 days',
      'ru': 'Прогнать 7 дней',
    },
    'stressModelDebugRunAll': {
      'en': 'Run full history',
      'ru': 'Прогнать всю историю',
    },
    'stressModelDebugNoRows': {
      'en': 'No run results yet. Start one of the scenarios above.',
      'ru': 'Результатов пока нет. Запустите один из сценариев выше.',
    },
    'physiologyAnomalyDebug': {
      'en': 'Physiology anomaly debug',
      'ru': 'Отладка модели аномалий',
    },
    'physiologyAnomalyDebugSubtitle': {
      'en': 'Replay personal physiology anomaly inference on wearable history',
      'ru': 'Прогон персональной модели отклонений на wearable-истории',
    },
    'physiologyAnomalyDebugRunRecent': {
      'en': 'Run last 14 days',
      'ru': 'Прогнать 14 дней',
    },
    'physiologyAnomalyDebugRunAll': {
      'en': 'Run full history',
      'ru': 'Прогнать всю историю',
    },
    'physiologyAnomalyDebugNoRows': {
      'en': 'No run results yet. Start one of the scenarios above.',
      'ru': 'Результатов пока нет. Запустите один из сценариев выше.',
    },
    'baselineForecastDebug': {
      'en': 'Baseline forecast debug',
      'ru': 'Отладка прогноза нормы',
    },
    'baselineForecastDebugSubtitle': {
      'en': 'Inspect expected vs actual values, ranges and deviation reasons',
      'ru': 'Просмотр expected vs actual, диапазонов и причин отклонений',
    },
    'baselineForecastDebugRunLatest': {
      'en': 'Run latest',
      'ru': 'Последний день',
    },
    'baselineForecastDebugRunRecent': {
      'en': 'Run last 14 days',
      'ru': 'Прогнать 14 дней',
    },
    'baselineForecastDebugRunAll': {
      'en': 'Run full history',
      'ru': 'Прогнать всю историю',
    },
    'baselineForecastDebugNoRows': {
      'en': 'No run results yet. Start one of the scenarios above.',
      'ru': 'Результатов пока нет. Запустите один из сценариев выше.',
    },
    'networkAuthEventsAndErrors': {
      'en': 'Network/auth events and errors',
      'ru': 'Сетевые/авторизационные события и ошибки',
    },
    'copy': {'en': 'Copy', 'ru': 'Копировать'},
    'clear': {'en': 'Clear', 'ru': 'Очистить'},
    'filterLabel': {'en': 'Filter:', 'ru': 'Фильтр:'},
    'debug': {'en': 'Debug', 'ru': 'Отладка'},
    'info': {'en': 'Info', 'ru': 'Инфо'},
    'warn': {'en': 'Warn', 'ru': 'Предупр.'},
    'error': {'en': 'Error', 'ru': 'Ошибка'},
    'noLogsYet': {'en': 'No logs yet', 'ru': 'Логов пока нет'},
    'logsCopiedToClipboard': {
      'en': 'Logs copied to clipboard',
      'ru': 'Логи скопированы в буфер обмена',
    },
    'on': {'en': 'ON', 'ru': 'ВКЛ'},
    'off': {'en': 'OFF', 'ru': 'ВЫКЛ'},
    'signOut': {'en': 'Sign Out', 'ru': 'Выйти'},

    // Navigation
    'home': {'en': 'Home', 'ru': 'Главная'},
    'data': {'en': 'Data', 'ru': 'Данные'},
    'analytics': {'en': 'Analytics', 'ru': 'Аналитика'},
    'reports': {'en': 'Reports', 'ru': 'Отчёты'},
    'profile': {'en': 'Profile', 'ru': 'Профиль'},
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final language = AppLanguage.fromCode(locale.languageCode);
    return AppLocalizations(language);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
