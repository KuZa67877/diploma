import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/auth_credentials.dart';
import '../../domain/usecases/sign_in_with_apple.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/submit_auth.dart';

part 'auth_cubit.freezed.dart';
part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final SubmitAuth submitAuth;
  final SignInWithGoogle signInWithGoogle;
  final SignInWithApple signInWithApple;

  AuthCubit({
    required this.submitAuth,
    required this.signInWithGoogle,
    required this.signInWithApple,
  }) : super(const AuthState.initial(
          isLogin: true,
          isPasswordObscured: true,
        ));

  void toggleMode() {
    emit(AuthState.initial(
      isLogin: !state.isLogin,
      isPasswordObscured: state.isPasswordObscured,
    ));
  }

  void togglePasswordVisibility() {
    emit(AuthState.initial(
      isLogin: state.isLogin,
      isPasswordObscured: !state.isPasswordObscured,
    ));
  }

  Future<void> submit({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return;

    emit(AuthState.loading(
      isLogin: state.isLogin,
      isPasswordObscured: state.isPasswordObscured,
    ));

    final result = await submitAuth(
      AuthParams(
        credentials: AuthCredentials(
          email: email,
          password: password,
          isLogin: state.isLogin,
        ),
      ),
    );

    result.fold(
      (failure) => emit(
        AuthState.error(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
          message: _mapFailureMessage(failure),
        ),
      ),
      (_) => emit(
        AuthState.success(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
        ),
      ),
    );
  }

  Future<void> signInWithGoogleProvider() async {
    if (state.isLoading) return;

    emit(AuthState.loading(
      isLogin: state.isLogin,
      isPasswordObscured: state.isPasswordObscured,
    ));

    final result = await signInWithGoogle(const NoParams());

    result.fold(
      (failure) => emit(
        AuthState.error(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
          message: _mapFailureMessage(failure),
        ),
      ),
      (_) => emit(
        AuthState.success(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
        ),
      ),
    );
  }

  Future<void> signInWithAppleProvider() async {
    if (state.isLoading) return;

    emit(AuthState.loading(
      isLogin: state.isLogin,
      isPasswordObscured: state.isPasswordObscured,
    ));

    final result = await signInWithApple(const NoParams());

    result.fold(
      (failure) => emit(
        AuthState.error(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
          message: _mapFailureMessage(failure),
        ),
      ),
      (_) => emit(
        AuthState.success(
          isLogin: state.isLogin,
          isPasswordObscured: state.isPasswordObscured,
        ),
      ),
    );
  }

  void resetStatus() {
    emit(
      AuthState.initial(
        isLogin: state.isLogin,
        isPasswordObscured: state.isPasswordObscured,
      ),
    );
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
