import 'package:equatable/equatable.dart';

class HealthPermissionOption extends Equatable {
  final String id;
  final String labelKey;
  final String descKey;
  final String iconKey;

  const HealthPermissionOption({
    required this.id,
    required this.labelKey,
    required this.descKey,
    required this.iconKey,
  });

  @override
  List<Object> get props => [id, labelKey, descKey, iconKey];
}
