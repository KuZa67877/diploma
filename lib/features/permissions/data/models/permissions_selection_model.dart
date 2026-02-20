import '../../domain/entities/permissions_selection.dart';

class PermissionsSelectionModel extends PermissionsSelection {
  const PermissionsSelectionModel({
    required super.sourceId,
    required super.permissions,
  });

  factory PermissionsSelectionModel.fromJson(Map<String, dynamic> json) {
    final permissions = <String, bool>{};
    final raw = json['permissions'];

    if (raw is Map<String, dynamic>) {
      raw.forEach((key, value) {
        permissions[key] = value == true;
      });
    }

    return PermissionsSelectionModel(
      sourceId: json['sourceId']?.toString(),
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'permissions': permissions,
    };
  }
}
