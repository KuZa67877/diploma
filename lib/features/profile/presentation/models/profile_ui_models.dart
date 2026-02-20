import 'package:flutter/material.dart';

class ProfileServiceUiModel {
  final String id;
  final String nameKey;
  final IconData icon;
  final Color color;
  final bool connected;

  const ProfileServiceUiModel({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.color,
    required this.connected,
  });
}

class ProfileViewData {
  final String userName;
  final String email;
  final List<ProfileServiceUiModel> services;

  const ProfileViewData({
    required this.userName,
    required this.email,
    required this.services,
  });
}
