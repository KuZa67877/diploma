import 'package:equatable/equatable.dart';

class AuthCredentials extends Equatable {
  final String email;
  final String password;
  final bool isLogin;

  const AuthCredentials({
    required this.email,
    required this.password,
    required this.isLogin,
  });

  @override
  List<Object> get props => [email, password, isLogin];
}
