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

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ru'),
  ];

  String get(String key) {
    return _translations[key]?[language.code] ?? key;
  }

  // Translations map
  static const Map<String, Map<String, String>> _translations = {
    // App name and tagline
    'appName': {'en': 'MediAI', 'ru': 'MediAI'},
    'tagline': {
      'en': 'AI-powered health diagnostics',
      'ru': 'ИИ-диагностика здоровья'
    },

    // Onboarding
    'aiHealthAnalysis': {'en': 'AI Health Analysis', 'ru': 'ИИ-анализ здоровья'},
    'aiHealthAnalysisDesc': {
      'en':
          'Advanced neural network analyzes your health metrics to provide personalized insights and early risk detection.',
      'ru':
          'Продвинутая нейросеть анализирует ваши показатели здоровья для персонализированных рекомендаций и раннего выявления рисков.'
    },
    'smartDataSync': {'en': 'Smart Data Sync', 'ru': 'Умная синхронизация'},
    'smartDataSyncDesc': {
      'en':
          'Seamlessly connect with Apple Health and Google Health Connect to automatically track your wellness journey.',
      'ru':
          'Синхронизируйтесь с Apple Health и Google Health Connect для автоматического отслеживания вашего здоровья.'
    },
    'secureReports': {'en': 'Secure Reports', 'ru': 'Безопасные отчёты'},
    'secureReportsDesc': {
      'en':
          'Your medical data is encrypted and protected. Export detailed health reports to share with your healthcare provider.',
      'ru':
          'Ваши медицинские данные зашифрованы и защищены. Экспортируйте подробные отчёты для вашего врача.'
    },
    'getStarted': {'en': 'Get Started', 'ru': 'Начать'},
    'alreadyHaveAccount': {
      'en': 'Already have an account? Sign in',
      'ru': 'Уже есть аккаунт? Войти'
    },

    // Permissions
    'connectHealthData': {
      'en': 'Connect Health Data',
      'ru': 'Подключить данные'
    },
    'syncYourMetrics': {
      'en': 'Sync your health metrics for comprehensive AI analysis',
      'ru': 'Синхронизируйте метрики для комплексного ИИ-анализа'
    },
    'iosDevices': {'en': 'iOS devices', 'ru': 'Устройства iOS'},
    'androidDevices': {'en': 'Android devices', 'ru': 'Устройства Android'},
    'selectDataToSync': {
      'en': 'Select data to sync',
      'ru': 'Выберите данные для синхронизации'
    },
    'heartRateDesc': {'en': 'BPM & HRV data', 'ru': 'Данные ЧСС и ВСР'},
    'stepsDesc': {
      'en': 'Daily activity tracking',
      'ru': 'Ежедневная активность'
    },
    'sleepDesc': {
      'en': 'Sleep cycles & quality',
      'ru': 'Циклы и качество сна'
    },
    'bloodOxygenDesc': {'en': 'SpO2 levels', 'ru': 'Уровень SpO2'},
    'weightDesc': {'en': 'Body measurements', 'ru': 'Измерения тела'},
    'syncHealthData': {'en': 'Sync Health Data', 'ru': 'Синхронизировать'},
    'skipForNow': {'en': 'Skip for now', 'ru': 'Пропустить'},
    'bloodOxygen': {'en': 'Blood Oxygen', 'ru': 'Кислород в крови'},

    // Health sources
    'healthDataSources': {
      'en': 'Health Data Sources',
      'ru': 'Источники данных'
    },
    'healthSourcesSubtitle': {
      'en': 'Connect and manage your health data providers',
      'ru': 'Подключите и управляйте источниками данных'
    },
    'supportedMetrics': {
      'en': 'Supported metrics',
      'ru': 'Поддерживаемые метрики'
    },
    'connected': {'en': 'Connected', 'ru': 'Подключено'},
    'notConnected': {'en': 'Not connected', 'ru': 'Не подключено'},
    'notAvailable': {'en': 'Not available', 'ru': 'Недоступно'},

    // Auth
    'welcomeBack': {'en': 'Welcome Back', 'ru': 'С возвращением'},
    'createAccount': {'en': 'Create Account', 'ru': 'Создать аккаунт'},
    'signInToContinue': {
      'en': 'Sign in to continue your health journey',
      'ru': 'Войдите, чтобы продолжить'
    },
    'startYourAIHealth': {
      'en': 'Start your AI health analysis today',
      'ru': 'Начните ИИ-анализ здоровья сегодня'
    },
    'email': {'en': 'Email', 'ru': 'Эл. почта'},
    'password': {'en': 'Password', 'ru': 'Пароль'},
    'forgotPassword': {'en': 'Forgot password?', 'ru': 'Забыли пароль?'},
    'signIn': {'en': 'Sign In', 'ru': 'Войти'},
    'signUp': {'en': 'Sign Up', 'ru': 'Регистрация'},
    'orContinueWith': {'en': 'or continue with', 'ru': 'или войти через'},
    'dontHaveAccount': {
      'en': "Don't have an account? ",
      'ru': 'Нет аккаунта? '
    },
    'alreadyHaveAccountShort': {
      'en': 'Already have an account? ',
      'ru': 'Уже есть аккаунт? '
    },
    'privacyNote': {
      'en':
          'Your health data is protected with end-to-end encryption. We comply with HIPAA and GDPR regulations to ensure your medical privacy.',
      'ru':
          'Ваши данные защищены сквозным шифрованием. Мы соблюдаем требования HIPAA и GDPR для обеспечения конфиденциальности.'
    },

    // Dashboard
    'goodMorning': {'en': 'Good morning', 'ru': 'Доброе утро'},
    'goodAfternoon': {'en': 'Good afternoon', 'ru': 'Добрый день'},
    'goodEvening': {'en': 'Good evening', 'ru': 'Добрый вечер'},
    'aiHealthScore': {'en': 'AI Health Score', 'ru': 'ИИ-оценка здоровья'},
    'stable': {'en': 'Stable', 'ru': 'Стабильно'},
    'attentionNeeded': {'en': 'Attention Needed', 'ru': 'Требует внимания'},
    'riskDetected': {'en': 'Risk Detected', 'ru': 'Обнаружен риск'},
    'aiInsight': {'en': 'AI Insight', 'ru': 'ИИ-аналитика'},
    'sleepImproved': {
      'en': 'Your sleep quality improved 12% this week',
      'ru': 'Качество сна улучшилось на 12% за неделю'
    },
    'healthMetrics': {'en': 'Health Metrics', 'ru': 'Показатели здоровья'},
    'viewAll': {'en': 'View All', 'ru': 'Все'},
    'heartRate': {'en': 'Heart Rate', 'ru': 'Пульс'},
    'sleep': {'en': 'Sleep', 'ru': 'Сон'},
    'activity': {'en': 'Activity', 'ru': 'Активность'},
    'runAIDiagnostics': {
      'en': 'Run AI Diagnostics',
      'ru': 'Запустить ИИ-диагностику'
    },

    // Data Input
    'manualInput': {'en': 'Manual Input', 'ru': 'Ручной ввод'},
    'recordMeasurements': {
      'en': 'Record your health measurements',
      'ru': 'Запишите ваши измерения'
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
      'ru': 'Ваши данные успешно записаны.'
    },
    'systolicError': {
      'en': 'Systolic should be between 70-200',
      'ru': 'Систолическое должно быть 70-200'
    },
    'glucoseError': {
      'en': 'Glucose should be between 50-400',
      'ru': 'Глюкоза должна быть 50-400'
    },
    'temperatureError': {
      'en': 'Temperature should be between 95-108°F',
      'ru': 'Температура должна быть 35-42°C'
    },

    // Analytics
    'healthAnalytics': {'en': 'Health Analytics', 'ru': 'Аналитика здоровья'},
    'detailedInsights': {
      'en': 'Detailed insights into your health data',
      'ru': 'Подробный анализ ваших данных'
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
      'ru': 'Обнаружен повышенный пульс'
    },
    'elevatedHeartRateDesc': {
      'en': 'Your resting heart rate was 15% higher than usual on Tuesday.',
      'ru': 'Ваш пульс в покое был на 15% выше обычного во вторник.'
    },
    'sleepQualityImproving': {
      'en': 'Sleep Quality Improving',
      'ru': 'Качество сна улучшается'
    },
    'sleepQualityDesc': {
      'en': 'Your deep sleep has increased by 18% over the past week.',
      'ru': 'Глубокий сон увеличился на 18% за последнюю неделю.'
    },
    'activityGoalAtRisk': {
      'en': 'Activity Goal at Risk',
      'ru': 'Цель активности под угрозой'
    },
    'activityGoalDesc': {
      'en': 'Based on current trends, you may miss your weekly step goal.',
      'ru': 'Исходя из текущих тенденций, вы можете не достичь недельной цели по шагам.'
    },

    // Reports
    'exportAndShare': {
      'en': 'Export and share your health reports',
      'ru': 'Экспортируйте и делитесь отчётами'
    },
    'exportSuccess': {
      'en': 'Exported {items} records from {sources} sources',
      'ru': 'Экспортировано {items} записей из {sources} источников'
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
      'ru': 'Еженедельная сводка'
    },
    'aiDiagnosticsReport': {
      'en': 'AI Diagnostics Report',
      'ru': 'Отчёт ИИ-диагностики'
    },
    'monthlyTrendsAnalysis': {
      'en': 'Monthly Trends Analysis',
      'ru': 'Месячный анализ трендов'
    },
    'heartRateAnalysis': {'en': 'Heart Rate Analysis', 'ru': 'Анализ пульса'},
    'processing': {'en': 'Processing', 'ru': 'Обработка'},

    // Profile
    'edit': {'en': 'Edit', 'ru': 'Изменить'},
    'connectedServices': {
      'en': 'Connected Services',
      'ru': 'Подключённые сервисы'
    },
    'appleHealth': {'en': 'Apple Health', 'ru': 'Apple Health'},
    'googleHealth': {'en': 'Google Health', 'ru': 'Google Health'},
    'settings': {'en': 'Settings', 'ru': 'Настройки'},
    'notifications': {'en': 'Notifications', 'ru': 'Уведомления'},
    'healthAlertsReminders': {
      'en': 'Health alerts & reminders',
      'ru': 'Оповещения и напоминания'
    },
    'darkMode': {'en': 'Dark Mode', 'ru': 'Тёмная тема'},
    'reduceEyeStrain': {'en': 'Reduce eye strain', 'ru': 'Снижение нагрузки на глаза'},
    'dataSyncFrequency': {
      'en': 'Data Sync Frequency',
      'ru': 'Частота синхронизации'
    },
    'every30Min': {'en': 'Every 30 min', 'ru': 'Каждые 30 мин'},
    'language': {'en': 'Language', 'ru': 'Язык'},
    'english': {'en': 'English', 'ru': 'English'},
    'russian': {'en': 'Русский', 'ru': 'Русский'},
    'security': {'en': 'Security', 'ru': 'Безопасность'},
    'dataEncryption': {'en': 'Data Encryption', 'ru': 'Шифрование данных'},
    'encryptionDesc': {
      'en':
          'Your health data is encrypted with AES-256 encryption and stored securely. We comply with HIPAA and GDPR regulations.',
      'ru':
          'Ваши данные зашифрованы AES-256 и надёжно хранятся. Мы соблюдаем требования HIPAA и GDPR.'
    },
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
