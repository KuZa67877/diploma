import '../../domain/entities/auth_credentials.dart';

class AuthCredentialsModel extends AuthCredentials {
  const AuthCredentialsModel({
    required super.email,
    required super.password,
    required super.isLogin,
  });

  factory AuthCredentialsModel.fromJson(Map<String, dynamic> json) {
    return AuthCredentialsModel(
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      isLogin: json['isLogin'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'isLogin': isLogin,
    };
  }
}
