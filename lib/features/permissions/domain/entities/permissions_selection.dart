import 'package:equatable/equatable.dart';

class PermissionsSelection extends Equatable {
  final String? sourceId;
  final Map<String, bool> permissions;

  const PermissionsSelection({
    required this.sourceId,
    required this.permissions,
  });

  @override
  List<Object?> get props => [sourceId, permissions];
}
