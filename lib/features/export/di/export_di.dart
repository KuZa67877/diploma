import 'package:get_it/get_it.dart';
import '../../dashboard/data/datasources/health_model_output_remote_data_source.dart';
import '../../health_data/domain/usecases/get_health_metrics.dart';
import '../../profile/domain/usecases/get_profile_data.dart';
import '../data/services/ai_prompt_export_builder.dart';
import '../data/services/csv_export_builder.dart';
import '../data/services/export_file_service.dart';
import '../data/services/health_data_export_mapper.dart';
import '../data/services/historical_model_output_service.dart';
import '../data/services/json_export_builder.dart';
import '../data/services/markdown_export_builder.dart';
import '../data/services/medical_export_builder.dart';
import '../data/services/native_share_service.dart';
import '../presentation/bloc/export_data_cubit.dart';

void registerExport(GetIt getIt) {
  getIt.registerLazySingleton<HealthDataExportMapper>(
    () => const HealthDataExportMapper(),
  );
  getIt.registerLazySingleton<AiPromptExportBuilder>(
    () => const AiPromptExportBuilder(),
  );
  getIt.registerLazySingleton<MedicalExportBuilder>(
    () => const MedicalExportBuilder(),
  );
  getIt.registerLazySingleton<MarkdownExportBuilder>(
    () => const MarkdownExportBuilder(),
  );
  getIt.registerLazySingleton<JsonExportBuilder>(
    () => const JsonExportBuilder(),
  );
  getIt.registerLazySingleton<CsvExportBuilder>(() => const CsvExportBuilder());
  getIt.registerLazySingleton<ExportFileService>(
    () => const ExportFileService(),
  );
  getIt.registerLazySingleton<NativeShareService>(
    () => const NativeShareService(),
  );
  getIt.registerLazySingleton<HistoricalModelOutputService>(
    () => HistoricalModelOutputService(
      remoteDataSource: getIt<HealthModelOutputRemoteDataSource>(),
    ),
  );

  getIt.registerFactory<ExportDataCubit>(
    () => ExportDataCubit(
      getHealthMetrics: getIt<GetHealthMetrics>(),
      getProfileData: getIt<GetProfileData>(),
      historicalModelOutputService: getIt<HistoricalModelOutputService>(),
      exportMapper: getIt<HealthDataExportMapper>(),
      aiPromptExportBuilder: getIt<AiPromptExportBuilder>(),
      medicalExportBuilder: getIt<MedicalExportBuilder>(),
      markdownExportBuilder: getIt<MarkdownExportBuilder>(),
      jsonExportBuilder: getIt<JsonExportBuilder>(),
      csvExportBuilder: getIt<CsvExportBuilder>(),
    ),
  );
}
