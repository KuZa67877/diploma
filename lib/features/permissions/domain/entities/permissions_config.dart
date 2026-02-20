import 'package:equatable/equatable.dart';
import 'health_permission_option.dart';
import 'health_source_option.dart';
import 'permissions_selection.dart';

class PermissionsConfig extends Equatable {
  final List<HealthSourceOption> sources;
  final List<HealthPermissionOption> permissions;
  final PermissionsSelection defaultSelection;

  const PermissionsConfig({
    required this.sources,
    required this.permissions,
    required this.defaultSelection,
  });

  @override
  List<Object> get props => [sources, permissions, defaultSelection];
}
