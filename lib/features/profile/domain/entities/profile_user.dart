import 'package:equatable/equatable.dart';

class ProfileUser extends Equatable {
  final String name;
  final String email;

  const ProfileUser({
    required this.name,
    required this.email,
  });

  @override
  List<Object> get props => [name, email];
}
