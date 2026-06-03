import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/theme_cubit.dart';
import 'core/localization/language_cubit.dart';
import 'core/auth/auth_status_cubit.dart';
import 'core/perf/perf_trace_service.dart';
import 'core/supabase/anonymous_user_snapshot_data_source.dart';
import 'features/analytics/di/analytics_di.dart';
import 'features/ai_assistant/di/ai_assistant_di.dart';
import 'features/auth/di/auth_di.dart';
import 'features/dashboard/di/dashboard_di.dart';
import 'features/export/di/export_di.dart';
import 'features/data_input/di/data_input_di.dart';
import 'features/diagnostics/di/diagnostics_di.dart';
import 'features/health_data/di/health_data_di.dart';
import 'features/profile/di/profile_di.dart';
import 'features/splash/di/splash_di.dart';
import 'features/wellbeing/di/wellbeing_di.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  getIt.registerLazySingleton<FirebaseAuth Function()>(
    () =>
        () => FirebaseAuth.instance,
  );
  getIt.registerLazySingleton<FirebaseFirestore Function()>(
    () =>
        () => FirebaseFirestore.instance,
  );
  getIt.registerLazySingleton<String? Function()>(
    () =>
        () => FirebaseAuth.instance.currentUser?.uid,
  );
  getIt.registerLazySingleton<AnonymousUserSnapshotDataSource>(
    () => AnonymousUserSnapshotDataSourceImpl(
      authProvider: getIt<FirebaseAuth Function()>(),
      firestoreProvider: getIt<FirebaseFirestore Function()>(),
    ),
  );

  // Core - Theme
  getIt.registerLazySingleton<ThemeCubit>(
    () => ThemeCubit(getIt<SharedPreferences>()),
  );

  // Core - Language
  getIt.registerLazySingleton<LanguageCubit>(
    () => LanguageCubit(getIt<SharedPreferences>()),
  );

  // Core - Auth status
  getIt.registerLazySingleton<AuthStatusCubit>(() => AuthStatusCubit());
  getIt.registerLazySingleton<PerfTraceService>(() => PerfTraceService());

  // Features
  registerAnalytics(getIt);
  registerAuth(getIt);
  registerDashboard(getIt);
  registerDataInput(getIt);
  registerDiagnostics(getIt);
  registerExport(getIt);
  registerAiAssistant(getIt);
  registerHealthData(getIt);
  registerProfile(getIt);
  registerSplash(getIt);
  registerWellbeing(getIt);
}
