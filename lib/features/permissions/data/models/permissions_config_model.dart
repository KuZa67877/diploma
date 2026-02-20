import '../../domain/entities/permissions_config.dart';
import 'health_permission_option_model.dart';
import 'health_source_option_model.dart';
import 'permissions_selection_model.dart';

class PermissionsConfigModel extends PermissionsConfig {
  const PermissionsConfigModel({
    required super.sources,
    required super.permissions,
    required super.defaultSelection,
  });

  factory PermissionsConfigModel.fromJson(Map<String, dynamic> json) {
    final sources = (json['sources'] as List<dynamic>?)
            ?.map((item) => HealthSourceOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <HealthSourceOptionModel>[];

    final permissions = (json['permissions'] as List<dynamic>?)
            ?.map((item) => HealthPermissionOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <HealthPermissionOptionModel>[];

    final selection = json['defaultSelection'] is Map<String, dynamic>
        ? PermissionsSelectionModel.fromJson(
            json['defaultSelection'] as Map<String, dynamic>,
          )
        : const PermissionsSelectionModel(
            sourceId: null,
            permissions: {},
          );

    return PermissionsConfigModel(
      sources: sources,
      permissions: permissions,
      defaultSelection: selection,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sources': sources
          .map((item) => (item as HealthSourceOptionModel).toJson())
          .toList(),
      'permissions': permissions
          .map((item) => (item as HealthPermissionOptionModel).toJson())
          .toList(),
      'defaultSelection': (defaultSelection as PermissionsSelectionModel).toJson(),
    };
  }
}
