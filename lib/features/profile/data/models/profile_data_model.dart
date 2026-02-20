import '../../domain/entities/profile_data.dart';
import 'connected_service_model.dart';
import 'profile_user_model.dart';

class ProfileDataModel extends ProfileData {
  const ProfileDataModel({
    required super.user,
    required super.services,
  });

  factory ProfileDataModel.fromJson(Map<String, dynamic> json) {
    final services = (json['services'] as List<dynamic>?)
            ?.map((item) => ConnectedServiceModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <ConnectedServiceModel>[];

    final user = json['user'] is Map<String, dynamic>
        ? ProfileUserModel.fromJson(json['user'] as Map<String, dynamic>)
        : const ProfileUserModel(name: '', email: '');

    return ProfileDataModel(
      user: user,
      services: services,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': (user as ProfileUserModel).toJson(),
      'services': services
          .map((item) => (item as ConnectedServiceModel).toJson())
          .toList(),
    };
  }
}
