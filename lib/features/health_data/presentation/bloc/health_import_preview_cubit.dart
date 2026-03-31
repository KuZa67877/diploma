import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/health_date_range.dart';
import '../../domain/entities/health_data_source_type.dart';
import '../../domain/entities/health_metric_sample.dart';
import '../../domain/entities/health_metrics_query.dart';
import '../../domain/usecases/get_available_health_sources.dart';
import '../../domain/usecases/get_health_metrics.dart';

class HealthImportPreviewState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final DateTime start;
  final DateTime end;
  final List<HealthMetricSample> samples;
  final Map<String, String> sourceNames;

  const HealthImportPreviewState({
    required this.isLoading,
    required this.errorMessage,
    required this.start,
    required this.end,
    required this.samples,
    required this.sourceNames,
  });

  factory HealthImportPreviewState.initial() {
    final now = DateTime.now();
    return HealthImportPreviewState(
      isLoading: false,
      errorMessage: null,
      start: now.subtract(const Duration(days: 30)),
      end: now,
      samples: const [],
      sourceNames: const {},
    );
  }

  HealthImportPreviewState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    DateTime? start,
    DateTime? end,
    List<HealthMetricSample>? samples,
    Map<String, String>? sourceNames,
  }) {
    return HealthImportPreviewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      start: start ?? this.start,
      end: end ?? this.end,
      samples: samples ?? this.samples,
      sourceNames: sourceNames ?? this.sourceNames,
    );
  }

  int get sourceCount => samples.map((sample) => sample.sourceId).toSet().length;

  int get metricTypeCount => samples.map((sample) => sample.type).toSet().length;

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    start,
    end,
    samples,
    sourceNames,
  ];
}

class HealthImportPreviewCubit extends Cubit<HealthImportPreviewState> {
  final GetHealthMetrics getHealthMetrics;
  final GetAvailableHealthSources getAvailableHealthSources;

  HealthImportPreviewCubit({
    required this.getHealthMetrics,
    required this.getAvailableHealthSources,
  }) : super(HealthImportPreviewState.initial());

  Future<void> load() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    emit(state.copyWith(isLoading: true, clearError: true, start: start, end: now));

    final sourcesResult = await getAvailableHealthSources(const NoParams());
    await sourcesResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: _mapFailureMessage(failure),
            sourceNames: const {},
            samples: const [],
          ),
        );
      },
      (sources) async {
        final externalConnectedSources = sources
            .where(
              (source) =>
                  source.type != HealthDataSourceType.local &&
                  source.isConnected &&
                  source.isAvailable,
            )
            .toList(growable: false);

        final sourceNames = {for (final source in sources) source.id: source.name};

        if (externalConnectedSources.isEmpty) {
          emit(
            state.copyWith(
              isLoading: false,
              clearError: true,
              sourceNames: sourceNames,
              samples: const [],
            ),
          );
          return;
        }

        final results = await Future.wait(
          externalConnectedSources.map(
            (source) => getHealthMetrics(
              HealthMetricsQuery(
                range: HealthDateRange(start: start, end: now),
                sourceId: source.id,
                onlyConnectedSources: false,
              ),
            ),
          ),
        );

        final importedSamples = <HealthMetricSample>[];
        Failure? firstFailure;

        for (final result in results) {
          result.fold(
            (failure) {
              firstFailure ??= failure;
            },
            (samples) {
              importedSamples.addAll(samples);
            },
          );
        }

        if (importedSamples.isEmpty && firstFailure != null) {
          emit(
            state.copyWith(
              isLoading: false,
              errorMessage: _mapFailureMessage(firstFailure!),
              sourceNames: sourceNames,
              samples: const [],
            ),
          );
          return;
        }

        importedSamples.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        emit(
          state.copyWith(
            isLoading: false,
            clearError: true,
            sourceNames: sourceNames,
            samples: importedSamples,
          ),
        );
      },
    );
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
