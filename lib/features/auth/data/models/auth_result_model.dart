import '../../domain/entities/auth_result.dart';

class AuthResultModel extends AuthResult {
  const AuthResultModel({
    required super.isAuthenticated,
  });

  factory AuthResultModel.fromJson(Map<String, dynamic> json) {
    return AuthResultModel(
      isAuthenticated: json['isAuthenticated'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
    };
  }
}
