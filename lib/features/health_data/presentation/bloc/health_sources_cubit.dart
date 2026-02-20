import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/health_data_source.dart';
import '../../domain/entities/health_data_source_type.dart';
import '../../domain/entities/health_metric_type.dart';
import '../../domain/entities/health_source_connection_params.dart';
import '../../domain/usecases/connect_health_source.dart';
import '../../domain/usecases/disconnect_health_source.dart';
import '../../domain/usecases/get_available_health_sources.dart';
import '../models/health_source_ui_model.dart';

part 'health_sources_cubit.freezed.dart';
part 'health_sources_state.dart';

/// Cubit для управления источниками данных здоровья.
class HealthSourcesCubit extends Cubit<HealthSourcesState> {
  /// Use case получения доступных источников.
  final GetAvailableHealthSources getSources;

  /// Use case подключения источника.
  final ConnectHealthSource connectSource;

  /// Use case отключения источника.
  final DisconnectHealthSource disconnectSource;

  /// Создает cubit источников данных.
  HealthSourcesCubit({
    required this.getSources,
    required this.connectSource,
    required this.disconnectSource,
  }) : super(const HealthSourcesState.initial());

  /// Загружает список источников.
  Future<void> load() async {
    emit(const HealthSourcesState.loading());

    final result = await getSources(const NoParams());
    result.fold(
      (failure) => emit(HealthSourcesState.error(message: _mapFailureMessage(failure))),
      (sources) => emit(
        HealthSourcesState.loaded(
          sources: _mapSources(sources),
          updatingSourceId: null,
        ),
      ),
    );
  }

  /// Переключает состояние подключения выбранного источника.
  Future<void> toggleConnection(String sourceId) async {
    final current = state.maybeWhen(
      loaded: (sources, updatingSourceId) => _LoadedStateCache(
        sources: sources,
        updatingSourceId: updatingSourceId,
      ),
      orElse: () => null,
    );

    if (current == null) return;

    if (current.sources.isEmpty) {
      return;
    }

    final sourceIndex = current.sources.indexWhere(
      (item) => item.id == sourceId,
    );

    if (sourceIndex == -1) {
      return;
    }

    final source = current.sources[sourceIndex];

    if (!source.isAvailable || current.updatingSourceId == sourceId) {
      return;
    }

    emit(
      HealthSourcesState.loaded(
        sources: current.sources,
        updatingSourceId: sourceId,
      ),
    );

    final result = source.isConnected
        ? await disconnectSource(HealthSourceConnectionParams(sourceId: sourceId))
        : await connectSource(HealthSourceConnectionParams(sourceId: sourceId));

    result.fold(
      (failure) => emit(HealthSourcesState.error(message: _mapFailureMessage(failure))),
      (_) {
        final updated = current.sources
            .map(
              (item) => item.id == sourceId
                  ? item.copyWith(isConnected: !item.isConnected)
                  : item,
            )
            .toList(growable: false);
        emit(
          HealthSourcesState.loaded(
            sources: updated,
            updatingSourceId: null,
          ),
        );
      },
    );
  }

  List<HealthSourceUiModel> _mapSources(List<HealthDataSource> sources) {
    return sources
        .map(
          (source) => HealthSourceUiModel(
            id: source.id,
            name: source.name,
            description: source.description,
            icon: _iconForSource(source),
            iconColor: _iconColorForSource(source),
            iconBackground: _iconBackgroundForSource(source),
            isConnected: source.isConnected,
            isAvailable: source.isAvailable,
            metricKeys: source.supportedMetrics
                .map(_metricKeyForType)
                .where((key) => key.isNotEmpty)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  IconData _iconForSource(HealthDataSource source) {
    switch (source.type) {
      case HealthDataSourceType.local:
        return LucideIcons.heart;
      case HealthDataSourceType.appleHealth:
        return LucideIcons.activity;
      case HealthDataSourceType.googleFit:
        return LucideIcons.footprints;
      case HealthDataSourceType.unknown:
        return LucideIcons.helpCircle;
    }
  }

  Color _iconColorForSource(HealthDataSource source) {
    switch (source.type) {
      case HealthDataSourceType.local:
        return AppColors.primary;
      case HealthDataSourceType.appleHealth:
        return AppColors.danger;
      case HealthDataSourceType.googleFit:
        return AppColors.secondary;
      case HealthDataSourceType.unknown:
        return AppColors.mutedForeground;
    }
  }

  Color _iconBackgroundForSource(HealthDataSource source) {
    switch (source.type) {
      case HealthDataSourceType.local:
        return AppColors.primaryLight;
      case HealthDataSourceType.appleHealth:
        return AppColors.dangerLight;
      case HealthDataSourceType.googleFit:
        return AppColors.secondaryLight;
      case HealthDataSourceType.unknown:
        return AppColors.muted;
    }
  }

  String _metricKeyForType(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.heartRate:
        return 'heartRate';
      case HealthMetricType.steps:
        return 'steps';
      case HealthMetricType.sleep:
        return 'sleep';
      case HealthMetricType.bloodOxygen:
        return 'bloodOxygen';
      case HealthMetricType.weight:
        return 'weight';
      case HealthMetricType.unknown:
        return '';
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}

class _LoadedStateCache {
  final List<HealthSourceUiModel> sources;
  final String? updatingSourceId;

  _LoadedStateCache({
    required this.sources,
    required this.updatingSourceId,
  });
}
