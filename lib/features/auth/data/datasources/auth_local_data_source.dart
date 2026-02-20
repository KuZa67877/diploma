import '../../../../core/error/failures.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_result_model.dart';

abstract class AuthLocalDataSource {
  Future<AuthResultModel> submit(AuthCredentialsModel credentials);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  @override
  Future<AuthResultModel> submit(AuthCredentialsModel credentials) async {
    _validate(credentials);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const AuthResultModel(isAuthenticated: true);
  }

  void _validate(AuthCredentialsModel credentials) {
    if (credentials.email.trim().isEmpty || !credentials.email.contains('@')) {
      throw const ValidationFailure('Некорректный email');
    }

    if (credentials.password.trim().length < 6) {
      throw const ValidationFailure('Пароль должен быть не короче 6 символов');
    }
  }
}
