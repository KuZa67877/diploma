import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_env.dart';
import '../../../core/firebase/firebase_initializer.dart';
import '../../dashboard/domain/usecases/get_dashboard_summary.dart';
import '../../export/data/services/historical_model_output_service.dart';
import '../../health_data/domain/usecases/get_health_metrics.dart';
import '../../wellbeing/domain/usecases/get_wellbeing_entries.dart';
import '../data/datasources/ai_assistant_local_data_source.dart';
import '../data/datasources/deepseek_remote_datasource.dart';
import '../data/repositories/deepseek_chat_repository_impl.dart';
import '../domain/repositories/deepseek_chat_repository.dart';
import '../domain/services/ai_usage_limiter_service.dart';
import '../domain/services/health_data_prompt_builder.dart';
import '../domain/services/token_estimator_service.dart';
import '../domain/usecases/build_ai_health_context.dart';
import '../presentation/bloc/deepseek_chat_cubit.dart';

void registerAiAssistant(GetIt getIt) {
  getIt.registerLazySingleton<AiAssistantLocalDataSource>(
    () => AiAssistantLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );
  getIt.registerLazySingleton<DeepSeekRemoteDataSource>(
    () => DeepSeekRemoteDataSourceImpl(
      proxyUrlProvider: () => AppEnv.aiProxyUrl,
      authTokenProvider: () async {
        if (!isFirebaseReady) {
          return null;
        }
        final user = getIt<FirebaseAuth Function()>()().currentUser;
        return user?.getIdToken();
      },
    ),
  );
  getIt.registerLazySingleton<DeepSeekChatRepository>(
    () => DeepSeekChatRepositoryImpl(
      remoteDataSource: getIt<DeepSeekRemoteDataSource>(),
      localDataSource: getIt<AiAssistantLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<TokenEstimatorService>(
    () => const TokenEstimatorService(),
  );
  getIt.registerLazySingleton<AiUsageLimiterService>(
    () => AiUsageLimiterService(sharedPreferences: getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton<HealthDataPromptBuilder>(
    () => const HealthDataPromptBuilder(),
  );
  getIt.registerLazySingleton<BuildAiHealthContextUseCase>(
    () => BuildAiHealthContextUseCase(
      getHealthMetrics: getIt<GetHealthMetrics>(),
      getWellbeingEntries: getIt<GetWellbeingEntries>(),
      getDashboardSummary: getIt<GetDashboardSummary>(),
      historicalModelOutputService: getIt<HistoricalModelOutputService>(),
    ),
  );
  getIt.registerFactory<DeepSeekChatCubit>(
    () => DeepSeekChatCubit(
      buildAiHealthContext: getIt<BuildAiHealthContextUseCase>(),
      promptBuilder: getIt<HealthDataPromptBuilder>(),
      tokenEstimator: getIt<TokenEstimatorService>(),
      usageLimiter: getIt<AiUsageLimiterService>(),
      repository: getIt<DeepSeekChatRepository>(),
    ),
  );
}
