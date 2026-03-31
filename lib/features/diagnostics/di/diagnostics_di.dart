import 'package:get_it/get_it.dart';
import '../data/datasources/diagnostics_local_data_source.dart';
import '../data/repositories/diagnostics_repository_impl.dart';
import '../domain/repositories/diagnostics_repository.dart';
import '../domain/usecases/get_risk_assessment.dart';

void registerDiagnostics(GetIt getIt) {
  getIt.registerLazySingleton<DiagnosticsLocalDataSource>(
    () => DiagnosticsLocalDataSourceImpl(),
  );

  getIt.registerLazySingleton<DiagnosticsRepository>(
    () => DiagnosticsRepositoryImpl(
      localDataSource: getIt<DiagnosticsLocalDataSource>(),
    ),
  );

  getIt.registerLazySingleton<GetRiskAssessment>(
    () => GetRiskAssessment(getIt<DiagnosticsRepository>()),
  );
}
