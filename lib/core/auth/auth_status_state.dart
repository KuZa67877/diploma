part of 'auth_status_cubit.dart';

@freezed
class AuthStatusState with _$AuthStatusState {
  const factory AuthStatusState({
    required AuthStatus status,
  }) = _AuthStatusState;
}
