import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/health_permission_option_model.dart';
import '../models/health_source_option_model.dart';
import '../models/permissions_config_model.dart';
import '../models/permissions_selection_model.dart';

abstract class PermissionsLocalDataSource {
  Future<PermissionsConfigModel> getConfig();
  Future<PermissionsSelectionModel> saveSelection(
    PermissionsSelectionModel selection,
  );
}

class PermissionsLocalDataSourceImpl implements PermissionsLocalDataSource {
  static const String _assetPath = 'assets/data/permissions.json';
  PermissionsSelectionModel? _cachedSelection;

  @override
  Future<PermissionsConfigModel> getConfig() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final config = PermissionsConfigModel.fromJson(decoded);
    final selection = _cachedSelection ??
        PermissionsSelectionModel(
          sourceId: config.defaultSelection.sourceId,
          permissions: config.defaultSelection.permissions,
        );

    return PermissionsConfigModel(
      sources: config.sources
          .map((item) => item as HealthSourceOptionModel)
          .toList(),
      permissions: config.permissions
          .map((item) => item as HealthPermissionOptionModel)
          .toList(),
      defaultSelection: selection,
    );
  }

  @override
  Future<PermissionsSelectionModel> saveSelection(
    PermissionsSelectionModel selection,
  ) async {
    _cachedSelection = selection;
    return selection;
  }
}
