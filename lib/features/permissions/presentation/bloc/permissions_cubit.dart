import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/health_permission_option.dart';
import '../../domain/entities/health_source_option.dart';
import '../../domain/entities/permissions_selection.dart';
import '../../domain/usecases/get_permissions_config.dart';
import '../../domain/usecases/save_permissions_selection.dart';
import '../models/permissions_ui_models.dart';

part 'permissions_cubit.freezed.dart';
part 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  final GetPermissionsConfig getConfig;
  final SavePermissionsSelection saveSelection;

  PermissionsCubit({
    required this.getConfig,
    required this.saveSelection,
  }) : super(const PermissionsState.initial());

  Future<void> load() async {
    emit(const PermissionsState.loading());

    final result = await getConfig(const NoParams());
    result.fold(
      (failure) => emit(PermissionsState.error(message: _mapFailureMessage(failure))),
      (config) {
        emit(
          PermissionsState.loaded(
            sources: _mapSources(config.sources),
            permissions: _mapPermissions(config.permissions),
            selectedSourceId: config.defaultSelection.sourceId,
            selectedPermissions: Map<String, bool>.from(
              config.defaultSelection.permissions,
            ),
          ),
        );
      },
    );
  }

  Future<void> selectSource(String sourceId) async {
    await _updateSelection(
      sourceId: sourceId,
    );
  }

  Future<void> togglePermission(String permissionId) async {
    await _updateSelection(togglePermissionId: permissionId);
  }

  Future<void> _updateSelection({
    String? sourceId,
    String? togglePermissionId,
  }) async {
    final current = state.maybeWhen(
      loaded: (
        sources,
        permissions,
        selectedSourceId,
        selectedPermissions,
      ) => _LoadedStateCache(
        sources: sources,
        permissions: permissions,
        selectedSourceId: selectedSourceId,
        selectedPermissions: selectedPermissions,
      ),
      orElse: () => null,
    );

    if (current == null) return;

    final nextPermissions = Map<String, bool>.from(current.selectedPermissions);
    if (togglePermissionId != null) {
      nextPermissions[togglePermissionId] =
          !(nextPermissions[togglePermissionId] ?? false);
    }

    final nextSelection = PermissionsSelection(
      sourceId: sourceId ?? current.selectedSourceId,
      permissions: nextPermissions,
    );

    final result = await saveSelection(
      SavePermissionsParams(selection: nextSelection),
    );

    result.fold(
      (failure) => emit(
        PermissionsState.error(message: _mapFailureMessage(failure)),
      ),
      (selection) => emit(
        PermissionsState.loaded(
          sources: current.sources,
          permissions: current.permissions,
          selectedSourceId: selection.sourceId,
          selectedPermissions: Map<String, bool>.from(selection.permissions),
        ),
      ),
    );
  }

  List<HealthSourceUiModel> _mapSources(List<HealthSourceOption> sources) {
    return sources
        .map(
          (source) => HealthSourceUiModel(
            id: source.id,
            icon: _iconForKey(source.iconKey),
            nameKey: source.nameKey,
            descKey: source.descKey,
            gradientColors: source.gradientKeys
                .map(_colorForKey)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<HealthPermissionUiModel> _mapPermissions(
    List<HealthPermissionOption> permissions,
  ) {
    return permissions
        .map(
          (permission) => HealthPermissionUiModel(
            id: permission.id,
            icon: _iconForKey(permission.iconKey),
            labelKey: permission.labelKey,
            descKey: permission.descKey,
          ),
        )
        .toList(growable: false);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'heart':
        return LucideIcons.heart;
      case 'activity':
        return LucideIcons.activity;
      case 'footprints':
        return LucideIcons.footprints;
      case 'moon':
        return LucideIcons.moon;
      case 'scale':
        return LucideIcons.scale;
      default:
        return LucideIcons.helpCircle;
    }
  }

  Color _colorForKey(String key) {
    switch (key) {
      case 'appleRed':
        return const Color(0xFFEF4444);
      case 'applePink':
        return const Color(0xFFEC4899);
      case 'googleGreen':
        return const Color(0xFF10B981);
      case 'googleGreenDark':
        return const Color(0xFF059669);
      default:
        return AppColors.primary;
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}

class _LoadedStateCache {
  final List<HealthSourceUiModel> sources;
  final List<HealthPermissionUiModel> permissions;
  final String? selectedSourceId;
  final Map<String, bool> selectedPermissions;

  _LoadedStateCache({
    required this.sources,
    required this.permissions,
    required this.selectedSourceId,
    required this.selectedPermissions,
  });
}
