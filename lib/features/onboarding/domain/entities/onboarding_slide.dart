import 'package:equatable/equatable.dart';

class OnboardingSlide extends Equatable {
  final String iconKey;
  final String titleKey;
  final String descriptionKey;
  final List<String> gradientKeys;

  const OnboardingSlide({
    required this.iconKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.gradientKeys,
  });

  @override
  List<Object> get props => [iconKey, titleKey, descriptionKey, gradientKeys];
}
