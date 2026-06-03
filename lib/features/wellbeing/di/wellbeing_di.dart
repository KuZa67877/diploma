import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/wellbeing_local_data_source.dart';
import '../data/datasources/wellbeing_remote_data_source.dart';
import '../data/repositories/wellbeing_repository_impl.dart';
import '../domain/repositories/wellbeing_repository.dart';
import '../domain/services/healthscore_base_component_service.dart';
import '../domain/services/healthscore_calculator_service.dart';
import '../domain/services/healthscore_diary_adjustment_service.dart';
import '../domain/usecases/calculate_healthscore.dart';
import '../domain/usecases/get_wellbeing_entries.dart';
import '../domain/usecases/save_wellbeing_entry.dart';
import '../presentation/bloc/wellbeing_cubit.dart';

void registerWellbeing(GetIt getIt) {
  getIt.registerLazySingleton<WellbeingLocalDataSource>(
    () => WellbeingLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
      currentUserIdProvider: getIt<String? Function()>(),
    ),
  );
  getIt.registerLazySingleton<WellbeingRemoteDataSource>(
    () => WellbeingRemoteDataSourceImpl(
      authProvider: getIt<FirebaseAuth Function()>(),
      firestoreProvider: getIt<FirebaseFirestore Function()>(),
    ),
  );

  getIt.registerLazySingleton<WellbeingRepository>(
    () => WellbeingRepositoryImpl(
      localDataSource: getIt<WellbeingLocalDataSource>(),
      remoteDataSource: getIt<WellbeingRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<HealthScoreBaseComponentService>(
    () => const HealthScoreBaseComponentService(),
  );
  getIt.registerLazySingleton<HealthScoreDiaryAdjustmentService>(
    () => const HealthScoreDiaryAdjustmentService(),
  );
  getIt.registerLazySingleton<HealthScoreCalculatorService>(
    () => HealthScoreCalculatorService(
      diaryAdjustmentService: getIt<HealthScoreDiaryAdjustmentService>(),
    ),
  );
  getIt.registerLazySingleton<CalculateHealthScore>(
    () => CalculateHealthScore(getIt<HealthScoreCalculatorService>()),
  );

  getIt.registerLazySingleton<GetWellbeingEntries>(
    () => GetWellbeingEntries(getIt<WellbeingRepository>()),
  );
  getIt.registerLazySingleton<SaveWellbeingEntry>(
    () => SaveWellbeingEntry(getIt<WellbeingRepository>()),
  );

  getIt.registerLazySingleton<WellbeingCubit>(
    () => WellbeingCubit(
      getWellbeingEntries: getIt<GetWellbeingEntries>(),
      saveWellbeingEntry: getIt<SaveWellbeingEntry>(),
    ),
  );
}
