import 'package:flutter/material.dart';

class OnboardingSlideUiModel {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final List<Color> gradientColors;

  const OnboardingSlideUiModel({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.gradientColors,
  });
}
