import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/profile_data_model.dart';

abstract class ProfileLocalDataSource {
  Future<ProfileDataModel> getProfileData();
}

class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  static const String _assetPath = 'assets/data/profile.json';

  @override
  Future<ProfileDataModel> getProfileData() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ProfileDataModel.fromJson(decoded);
  }
}
