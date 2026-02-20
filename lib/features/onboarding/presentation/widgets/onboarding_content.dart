import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/onboarding_cubit.dart';
import 'onboarding_bottom_actions.dart';
import 'onboarding_error_state.dart';
import 'onboarding_header.dart';
import 'onboarding_slides_list.dart';

class OnboardingContent extends StatelessWidget {
  final OnboardingState state;
  final VoidCallback onComplete;
  final VoidCallback onSignIn;
  final VoidCallback onRetry;

  const OnboardingContent({
    super.key,
    required this.state,
    required this.onComplete,
    required this.onSignIn,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OnboardingHeader(),
        Expanded(
          child: state.when(
            initial: () => const Center(
              child: CircularProgressIndicator(),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            loaded: (slides) => OnboardingSlidesList(slides: slides),
            error: (message) => OnboardingErrorState(
              message: message,
              onRetry: onRetry,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        OnboardingBottomActions(
          onComplete: onComplete,
          onSignIn: onSignIn,
        ),
      ],
    );
  }
}
