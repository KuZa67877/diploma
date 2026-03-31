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
  final int? healthScore;
  final int recordsCount;
  final int streakDays;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final List<ProfileServiceUiModel> services;

  const ProfileViewData({
    required this.userName,
    required this.email,
    required this.healthScore,
    required this.recordsCount,
    required this.streakDays,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.services,
  });
}
