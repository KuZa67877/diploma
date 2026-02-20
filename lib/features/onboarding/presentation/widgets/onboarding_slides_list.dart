import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/onboarding_slide_ui_model.dart';
import 'onboarding_slide.dart';

class OnboardingSlidesList extends StatelessWidget {
  final List<OnboardingSlideUiModel> slides;

  const OnboardingSlidesList({
    super.key,
    required this.slides,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      itemCount: slides.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.spacingMd),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(
            milliseconds: 500 + (index * 150),
          ),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 20),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: OnboardingSlide(data: slides[index]),
        );
      },
    );
  }
}
