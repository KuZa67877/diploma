import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/onboarding_slide_model.dart';

abstract class OnboardingLocalDataSource {
  Future<List<OnboardingSlideModel>> getSlides();
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _assetPath = 'assets/data/onboarding.json';

  @override
  Future<List<OnboardingSlideModel>> getSlides() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = (decoded['slides'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => OnboardingSlideModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return items;
  }
}
