part of 'auth_cubit.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial({
    required bool isLogin,
    required bool isPasswordObscured,
  }) = _Initial;

  const factory AuthState.loading({
    required bool isLogin,
    required bool isPasswordObscured,
  }) = _Loading;

  const factory AuthState.success({
    required bool isLogin,
    required bool isPasswordObscured,
  }) = _Success;

  const factory AuthState.error({
    required bool isLogin,
    required bool isPasswordObscured,
    required String message,
  }) = _Error;
}

extension AuthStateX on AuthState {
  bool get isLogin => when(
        initial: (isLogin, _) => isLogin,
        loading: (isLogin, _) => isLogin,
        success: (isLogin, _) => isLogin,
        error: (isLogin, _, __) => isLogin,
      );

  bool get isPasswordObscured => when(
        initial: (_, isPasswordObscured) => isPasswordObscured,
        loading: (_, isPasswordObscured) => isPasswordObscured,
        success: (_, isPasswordObscured) => isPasswordObscured,
        error: (_, isPasswordObscured, __) => isPasswordObscured,
      );

  bool get isLoading => maybeWhen(
        loading: (_, __) => true,
        orElse: () => false,
      );
}
