import 'package:equatable/equatable.dart';

class AuthResult extends Equatable {
  final bool isAuthenticated;

  const AuthResult({
    required this.isAuthenticated,
  });

  @override
  List<Object> get props => [isAuthenticated];
}
