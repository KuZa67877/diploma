import '../models/connected_service_model.dart';
import '../models/profile_data_model.dart';
import '../models/profile_user_model.dart';

abstract class ProfileLocalDataSource {
  Future<ProfileDataModel> getProfileData();
}

class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  @override
  Future<ProfileDataModel> getProfileData() async {
    return const ProfileDataModel(
      user: ProfileUserModel(name: 'User', email: ''),
      services: [
        ConnectedServiceModel(
          id: 'apple',
          nameKey: 'appleHealth',
          iconKey: 'heart',
          colorKey: 'danger',
          connected: false,
        ),
        ConnectedServiceModel(
          id: 'google',
          nameKey: 'googleHealth',
          iconKey: 'activity',
          colorKey: 'secondary',
          connected: false,
        ),
      ],
    );
  }
}
