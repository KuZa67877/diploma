import '../../domain/entities/profile_user.dart';

class ProfileUserModel extends ProfileUser {
  const ProfileUserModel({
    required super.name,
    required super.email,
  });

  factory ProfileUserModel.fromJson(Map<String, dynamic> json) {
    return ProfileUserModel(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
    };
  }
}
