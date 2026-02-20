import '../../domain/entities/health_permission_option.dart';

class HealthPermissionOptionModel extends HealthPermissionOption {
  const HealthPermissionOptionModel({
    required super.id,
    required super.labelKey,
    required super.descKey,
    required super.iconKey,
  });

  factory HealthPermissionOptionModel.fromJson(Map<String, dynamic> json) {
    return HealthPermissionOptionModel(
      id: json['id']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
      descKey: json['descKey']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labelKey': labelKey,
      'descKey': descKey,
      'iconKey': iconKey,
    };
  }
}
