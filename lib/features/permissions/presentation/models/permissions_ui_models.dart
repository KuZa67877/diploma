import 'package:flutter/material.dart';

class HealthSourceUiModel {
  final String id;
  final IconData icon;
  final String nameKey;
  final String descKey;
  final List<Color> gradientColors;

  const HealthSourceUiModel({
    required this.id,
    required this.icon,
    required this.nameKey,
    required this.descKey,
    required this.gradientColors,
  });
}

class HealthPermissionUiModel {
  final String id;
  final IconData icon;
  final String labelKey;
  final String descKey;

  const HealthPermissionUiModel({
    required this.id,
    required this.icon,
    required this.labelKey,
    required this.descKey,
  });
}
