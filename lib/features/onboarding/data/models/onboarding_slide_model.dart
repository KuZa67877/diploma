import '../../domain/entities/onboarding_slide.dart';

class OnboardingSlideModel extends OnboardingSlide {
  const OnboardingSlideModel({
    required super.iconKey,
    required super.titleKey,
    required super.descriptionKey,
    required super.gradientKeys,
  });

  factory OnboardingSlideModel.fromJson(Map<String, dynamic> json) {
    final gradientKeys = (json['gradientKeys'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];

    return OnboardingSlideModel(
      iconKey: json['iconKey']?.toString() ?? '',
      titleKey: json['titleKey']?.toString() ?? '',
      descriptionKey: json['descriptionKey']?.toString() ?? '',
      gradientKeys: gradientKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iconKey': iconKey,
      'titleKey': titleKey,
      'descriptionKey': descriptionKey,
      'gradientKeys': gradientKeys,
    };
  }
}
