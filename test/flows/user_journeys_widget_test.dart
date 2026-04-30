import 'package:dartz/dartz.dart' show Either, Right, Unit, unit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/core/localization/app_localizations.dart';
import 'package:medi_ai/core/usecases/usecase.dart';
import 'package:medi_ai/features/analytics/domain/entities/activity_sample.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_data.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_filter_option.dart';
import 'package:medi_ai/features/analytics/domain/entities/analytics_insight.dart';
import 'package:medi_ai/features/analytics/domain/entities/heart_rate_sample.dart';
import 'package:medi_ai/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:medi_ai/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:medi_ai/features/analytics/presentation/bloc/analytics_cubit.dart';
import 'package:medi_ai/features/analytics/presentation/pages/analytics_page.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_credentials.dart';
import 'package:medi_ai/features/auth/domain/entities/auth_result.dart';
import 'package:medi_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:medi_ai/features/auth/domain/usecases/sign_in_with_apple.dart';
import 'package:medi_ai/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:medi_ai/features/auth/domain/usecases/submit_auth.dart';
import 'package:medi_ai/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:medi_ai/features/auth/presentation/pages/auth_page.dart';
import 'package:medi_ai/features/dashboard/data/datasources/health_model_output_remote_data_source.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_insight.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_metric.dart';
import 'package:medi_ai/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:medi_ai/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:medi_ai/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:medi_ai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_entry.dart';
import 'package:medi_ai/features/data_input/domain/entities/symptom_option.dart';
import 'package:medi_ai/features/data_input/domain/repositories/data_input_repository.dart';
import 'package:medi_ai/features/data_input/domain/usecases/get_data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/usecases/submit_data_input.dart';
import 'package:medi_ai/features/data_input/presentation/bloc/data_input_cubit.dart';
import 'package:medi_ai/features/data_input/presentation/pages/data_input_page.dart';
import 'package:medi_ai/features/export/data/services/ai_prompt_export_builder.dart';
import 'package:medi_ai/features/export/data/services/csv_export_builder.dart';
import 'package:medi_ai/features/export/data/services/export_file_service.dart';
import 'package:medi_ai/features/export/data/services/health_data_export_mapper.dart';
import 'package:medi_ai/features/export/data/services/historical_model_output_service.dart';
import 'package:medi_ai/features/export/data/services/json_export_builder.dart';
import 'package:medi_ai/features/export/data/services/markdown_export_builder.dart';
import 'package:medi_ai/features/export/data/services/medical_export_builder.dart';
import 'package:medi_ai/features/export/data/services/native_share_service.dart';
import 'package:medi_ai/features/export/presentation/bloc/export_data_cubit.dart';
import 'package:medi_ai/features/export/presentation/pages/export_data_page.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_data_source_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_sample.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metric_type.dart';
import 'package:medi_ai/features/health_data/domain/entities/health_metrics_query.dart';
import 'package:medi_ai/features/health_data/domain/repositories/health_data_repository.dart';
import 'package:medi_ai/features/health_data/domain/usecases/connect_health_source.dart';
import 'package:medi_ai/features/health_data/domain/usecases/disconnect_health_source.dart';
import 'package:medi_ai/features/health_data/domain/usecases/get_available_health_sources.dart';
import 'package:medi_ai/features/health_data/domain/usecases/get_health_metrics.dart';
import 'package:medi_ai/features/health_data/presentation/bloc/health_sources_cubit.dart';
import 'package:medi_ai/features/health_data/presentation/pages/health_sources_page.dart';
import 'package:medi_ai/features/health_data/presentation/widgets/health_source_card.dart';
import 'package:medi_ai/features/profile/domain/entities/connected_service.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_data.dart';
import 'package:medi_ai/features/profile/domain/entities/profile_user.dart';
import 'package:medi_ai/features/profile/domain/repositories/profile_repository.dart';
import 'package:medi_ai/features/profile/domain/usecases/get_profile_data.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/diary_health_adjustment.dart';
import 'package:medi_ai/injection_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'registration flow navigates auth -> data input -> health sources -> dashboard',
    (tester) async {
      final authRepository = _FlowAuthRepository();
      final dataInputRepository = _FlowDataInputRepository();
      final healthDataRepository = _FlowHealthDataRepository(
        sources: <HealthDataSource>[
          const HealthDataSource(
            id: 'apple_health',
            name: 'Apple Health',
            description: 'Sync heart rate, sleep and activity.',
            type: HealthDataSourceType.appleHealth,
            iconKey: 'apple_health',
            supportedMetrics: <HealthMetricType>[
              HealthMetricType.heartRate,
              HealthMetricType.sleepAsleep,
              HealthMetricType.steps,
            ],
            isConnected: false,
            isAvailable: true,
          ),
        ],
      );
      final dashboardRepository = _FlowDashboardRepository(
        summary: _dashboardSummary(),
      );

      getIt.registerFactory<AuthCubit>(
        () => AuthCubit(
          submitAuth: SubmitAuth(authRepository),
          signInWithGoogle: SignInWithGoogle(authRepository),
          signInWithApple: SignInWithApple(authRepository),
        ),
      );
      getIt.registerFactory<DataInputCubit>(
        () => DataInputCubit(
          getConfig: GetDataInputConfig(dataInputRepository),
          submitDataInput: SubmitDataInput(dataInputRepository),
        ),
      );
      getIt.registerFactory<HealthSourcesCubit>(
        () => HealthSourcesCubit(
          getSources: GetAvailableHealthSources(healthDataRepository),
          connectSource: ConnectHealthSource(healthDataRepository),
          disconnectSource: DisconnectHealthSource(healthDataRepository),
        ),
      );
      getIt.registerFactory<DashboardCubit>(
        () => DashboardCubit(
          getDashboardSummary: GetDashboardSummary(dashboardRepository),
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(child: const _AuthToDashboardFlowHost()),
      );

      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'flow@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await _pumpUntilVisible(tester, find.text('Basic health data'));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await _pumpUntilVisible(tester, find.text('Health Data Sources'));

      final appleCard = find.ancestor(
        of: find.text('Apple Health'),
        matching: find.byType(HealthSourceCard),
      );
      expect(
        find.descendant(of: appleCard, matching: find.text('Not connected')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: appleCard, matching: find.byType(GestureDetector)),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        find.descendant(of: appleCard, matching: find.text('Connected')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await _pumpUntilVisible(tester, find.text('Health Score'));

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Recommended today'), findsOneWidget);
      expect(authRepository.lastCredentials?.isLogin, isFalse);
      expect(dataInputRepository.submitCalls, 1);
      expect(
        healthDataRepository.sources
            .singleWhere((item) => item.id == 'apple_health')
            .isConnected,
        isTrue,
      );
    },
  );

  testWidgets('analytics flow opens export page with prepared preview', (
    tester,
  ) async {
    final analyticsRepository = _FlowAnalyticsRepository(
      data: _analyticsData(),
    );
    final healthDataRepository = _FlowHealthDataRepository(
      sources: const <HealthDataSource>[],
      metrics: _exportMetrics(),
    );
    final profileRepository = _FlowProfileRepository(
      data: const ProfileData(
        user: ProfileUser(
          name: 'Alex Johnson',
          email: 'alex@example.com',
          age: 29,
          sex: 'male',
          heightCm: 178,
          weightKg: 72.4,
          healthScore: 81,
        ),
        services: <ConnectedService>[
          ConnectedService(
            id: 'apple',
            nameKey: 'appleHealth',
            iconKey: 'activity',
            colorKey: 'danger',
            connected: true,
          ),
        ],
      ),
    );

    getIt.registerFactory<AnalyticsCubit>(
      () => AnalyticsCubit(
        getAnalyticsData: GetAnalyticsData(analyticsRepository),
      ),
    );
    getIt.registerFactory<ExportDataCubit>(
      () => ExportDataCubit(
        getHealthMetrics: GetHealthMetrics(healthDataRepository),
        getProfileData: GetProfileData(profileRepository),
        historicalModelOutputService: HistoricalModelOutputService(
          remoteDataSource: _FlowModelOutputRemoteDataSource(),
        ),
        exportMapper: const HealthDataExportMapper(),
        aiPromptExportBuilder: const AiPromptExportBuilder(),
        medicalExportBuilder: const MedicalExportBuilder(),
        markdownExportBuilder: const MarkdownExportBuilder(),
        jsonExportBuilder: const JsonExportBuilder(),
        csvExportBuilder: const CsvExportBuilder(),
      ),
    );
    getIt.registerLazySingleton<ExportFileService>(
      () => const ExportFileService(),
    );
    getIt.registerLazySingleton<NativeShareService>(
      () => const NativeShareService(),
    );

    await tester.pumpWidget(
      _buildTestApp(child: const _AnalyticsToExportFlowHost()),
    );

    await _pumpUntilVisible(tester, find.text('Health Analytics'));
    expect(find.text('Export'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Data export'));

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.textContaining('ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:'), findsOneWidget);
    expect(find.text('Copy current format'), findsOneWidget);
  });
}

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 30,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Finder did not appear: $finder');
}

DashboardSummary _dashboardSummary() {
  return DashboardSummary(
    greetingKey: 'goodMorning',
    userName: 'Alex',
    healthScore: 82,
    status: 'stable',
    recommendationKeys: const <String>[
      'recStable1',
      'recStable2',
      'recStable3',
    ],
    insight: const DashboardInsight(
      titleKey: 'aiInsight',
      descKey: 'sleepImproved',
    ),
    metrics: const <DashboardMetric>[
      DashboardMetric(
        id: 'heart',
        labelKey: 'heartRate',
        value: '72',
        unit: 'bpm',
        trend: 'stable',
        data: <double>[71, 72, 72],
      ),
    ],
    dataSnapshot: DashboardDataSnapshot(
      connectedSources: 1,
      wearableSampleCount: 16,
      latestWearableSampleAt: DateTime.utc(2026, 4, 30, 8),
    ),
    modelResults: const DashboardModelResults(
      healthScoreConfidence: 0.82,
      diaryAdjustment: DiaryHealthAdjustment.none(),
    ),
  );
}

AnalyticsData _analyticsData() {
  return const AnalyticsData(
    filters: <AnalyticsFilterOption>[
      AnalyticsFilterOption(id: 'day', labelKey: 'day'),
      AnalyticsFilterOption(id: 'week', labelKey: 'week'),
      AnalyticsFilterOption(id: 'month', labelKey: 'month'),
    ],
    selectedFilterId: 'week',
    heartRate: <HeartRateSample>[
      HeartRateSample(hour: 8, bpm: 70),
      HeartRateSample(hour: 12, bpm: 74),
      HeartRateSample(hour: 18, bpm: 72),
    ],
    activity: <ActivitySample>[
      ActivitySample(label: 'Mon', steps: 5400),
      ActivitySample(label: 'Tue', steps: 7200),
      ActivitySample(label: 'Wed', steps: 8100),
    ],
    insights: <AnalyticsInsight>[
      AnalyticsInsight(
        type: 'positive',
        titleKey: 'sleepQualityImproving',
        descKey: 'sleepQualityDesc',
        severity: 'success',
      ),
    ],
    recordsCount: 24,
    sourceCount: 2,
    metricTypeCount: 4,
    averageHeartRate: 72,
    averageSteps: 6900,
    sleepAiScore: 78,
    sleepAiConfidence: 0.8,
    sleepAiStatus: 'ok',
    sleepAiReason: 'ok',
  );
}

List<HealthMetricSample> _exportMetrics() {
  final now = DateTime.utc(2026, 4, 30, 10);
  return <HealthMetricSample>[
    _sample(
      id: 'hr_1',
      type: HealthMetricType.heartRate,
      value: 72,
      unit: 'bpm',
      timestamp: now.subtract(const Duration(hours: 2)),
      sourceId: 'apple_health',
    ),
    _sample(
      id: 'steps_1',
      type: HealthMetricType.steps,
      value: 7100,
      unit: 'count',
      timestamp: now.subtract(const Duration(hours: 1)),
      sourceId: 'apple_health',
    ),
    _sample(
      id: 'sleep_1',
      type: HealthMetricType.sleepAsleep,
      value: 430,
      unit: 'MIN',
      timestamp: now.subtract(const Duration(hours: 8)),
      intervalStart: now.subtract(const Duration(hours: 15)),
      intervalEnd: now.subtract(const Duration(hours: 8)),
      sourceId: 'google_fit',
    ),
  ];
}

HealthMetricSample _sample({
  required String id,
  required HealthMetricType type,
  required double value,
  required String unit,
  required DateTime timestamp,
  DateTime? intervalStart,
  DateTime? intervalEnd,
  required String sourceId,
}) {
  return HealthMetricSample(
    id: id,
    type: type,
    value: value,
    unit: unit,
    timestamp: timestamp,
    intervalStart: intervalStart,
    intervalEnd: intervalEnd,
    sourceId: sourceId,
  );
}

class _AuthToDashboardFlowHost extends StatefulWidget {
  const _AuthToDashboardFlowHost();

  @override
  State<_AuthToDashboardFlowHost> createState() =>
      _AuthToDashboardFlowHostState();
}

enum _AuthStage { auth, dataInput, healthSources, dashboard }

class _AuthToDashboardFlowHostState extends State<_AuthToDashboardFlowHost> {
  _AuthStage _stage = _AuthStage.auth;

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _AuthStage.auth => AuthPage(
        onAuthSuccess: (isLogin) {
          setState(() {
            _stage = isLogin ? _AuthStage.dashboard : _AuthStage.dataInput;
          });
        },
      ),
      _AuthStage.dataInput => DataInputPage(
        onComplete: () {
          setState(() {
            _stage = _AuthStage.healthSources;
          });
        },
      ),
      _AuthStage.healthSources => HealthSourcesPage(
        onBack: () {},
        onComplete: () {
          setState(() {
            _stage = _AuthStage.dashboard;
          });
        },
        onSkip: () {
          setState(() {
            _stage = _AuthStage.dashboard;
          });
        },
        showSkipAction: true,
        showContinueAction: true,
      ),
      _AuthStage.dashboard => DashboardPage(
        onOpenProfile: () {},
        onOpenHealthSources: () {},
      ),
    };
  }
}

class _AnalyticsToExportFlowHost extends StatefulWidget {
  const _AnalyticsToExportFlowHost();

  @override
  State<_AnalyticsToExportFlowHost> createState() =>
      _AnalyticsToExportFlowHostState();
}

enum _AnalyticsStage { analytics, export }

class _AnalyticsToExportFlowHostState
    extends State<_AnalyticsToExportFlowHost> {
  _AnalyticsStage _stage = _AnalyticsStage.analytics;

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _AnalyticsStage.analytics => AnalyticsPage(
        onOpenExport: () {
          setState(() {
            _stage = _AnalyticsStage.export;
          });
        },
      ),
      _AnalyticsStage.export => ExportDataPage(onBack: () {}),
    };
  }
}

class _FlowAuthRepository implements AuthRepository {
  AuthCredentials? lastCredentials;

  @override
  Future<Either<Failure, AuthResult>> signInWithApple() async {
    return const Right(AuthResult(isAuthenticated: true));
  }

  @override
  Future<Either<Failure, AuthResult>> signInWithGoogle() async {
    return const Right(AuthResult(isAuthenticated: true));
  }

  @override
  Future<Either<Failure, AuthResult>> submit(
    AuthCredentials credentials,
  ) async {
    lastCredentials = credentials;
    return const Right(AuthResult(isAuthenticated: true));
  }
}

class _FlowDataInputRepository implements DataInputRepository {
  int submitCalls = 0;

  @override
  Future<Either<Failure, DataInputConfig>> getConfig() async {
    return Right(
      const DataInputConfig(
        symptoms: <SymptomOption>[
          SymptomOption(id: 'fatigue', labelKey: 'fatigue'),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry) async {
    submitCalls += 1;
    return const Right(unit);
  }
}

class _FlowHealthDataRepository implements HealthDataRepository {
  List<HealthDataSource> sources;
  final List<HealthMetricSample> metrics;

  _FlowHealthDataRepository({
    required this.sources,
    this.metrics = const <HealthMetricSample>[],
  });

  @override
  Future<Either<Failure, Unit>> connectSource(String sourceId) async {
    sources = sources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(isConnected: true)
              : source,
        )
        .toList(growable: false);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> disconnectSource(String sourceId) async {
    sources = sources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(isConnected: false)
              : source,
        )
        .toList(growable: false);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<HealthDataSource>>> getAvailableSources() async {
    return Right(sources);
  }

  @override
  Future<Either<Failure, List<HealthMetricSample>>> getMetrics(
    HealthMetricsQuery query,
  ) async {
    return Right(metrics);
  }

  @override
  Future<Either<Failure, Unit>> syncConnectedSources() async {
    return const Right(unit);
  }
}

class _FlowDashboardRepository implements DashboardRepository {
  final DashboardSummary summary;

  _FlowDashboardRepository({required this.summary});

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    return Right(summary);
  }
}

class _FlowAnalyticsRepository implements AnalyticsRepository {
  final AnalyticsData data;

  _FlowAnalyticsRepository({required this.data});

  @override
  Future<Either<Failure, AnalyticsData>> getAnalyticsData(
    String filterId,
  ) async {
    return Right(data);
  }
}

class _FlowProfileRepository implements ProfileRepository {
  final ProfileData data;

  _FlowProfileRepository({required this.data});

  @override
  Future<Either<Failure, ProfileData>> getProfileData() async {
    return Right(data);
  }
}

class _FlowModelOutputRemoteDataSource
    implements HealthModelOutputRemoteDataSource {
  @override
  Future<Map<String, HealthModelOutputRecord>> getLatestOutputsByModelIds(
    List<String> modelIds,
  ) async {
    return const <String, HealthModelOutputRecord>{};
  }

  @override
  Future<List<HealthModelOutputRecord>> getOutputsByModelIdsForRange({
    required List<String> modelIds,
    required DateTime start,
    required DateTime end,
  }) async {
    return const <HealthModelOutputRecord>[];
  }

  @override
  Future<void> saveOutputs(List<HealthModelOutputPayload> outputs) async {}
}
