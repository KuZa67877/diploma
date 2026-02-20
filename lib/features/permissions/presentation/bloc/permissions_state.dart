part of 'permissions_cubit.dart';

@freezed
class PermissionsState with _$PermissionsState {
  const factory PermissionsState.initial() = _Initial;
  const factory PermissionsState.loading() = _Loading;
  const factory PermissionsState.loaded({
    required List<HealthSourceUiModel> sources,
    required List<HealthPermissionUiModel> permissions,
    required String? selectedSourceId,
    required Map<String, bool> selectedPermissions,
  }) = _Loaded;
  const factory PermissionsState.error({
    required String message,
  }) = _Error;
}
