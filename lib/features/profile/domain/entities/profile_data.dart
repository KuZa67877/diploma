import 'package:equatable/equatable.dart';
import 'connected_service.dart';
import 'profile_user.dart';

class ProfileData extends Equatable {
  final ProfileUser user;
  final List<ConnectedService> services;

  const ProfileData({
    required this.user,
    required this.services,
  });

  @override
  List<Object> get props => [user, services];
}
