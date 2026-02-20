import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_status_cubit.freezed.dart';
part 'auth_status_state.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticated,
}

class AuthStatusCubit extends Cubit<AuthStatusState> {
  AuthStatusCubit() : super(const AuthStatusState(status: AuthStatus.unknown));

  void setAuthenticated() =>
      emit(const AuthStatusState(status: AuthStatus.authenticated));

  void setUnauthenticated() =>
      emit(const AuthStatusState(status: AuthStatus.unauthenticated));

  void reset() => emit(const AuthStatusState(status: AuthStatus.unknown));
}
