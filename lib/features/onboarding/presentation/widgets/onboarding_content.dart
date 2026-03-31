import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_shimmer.dart';
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
            initial: _OnboardingLoadingShimmer.new,
            loading: _OnboardingLoadingShimmer.new,
            loaded: (slides) => OnboardingSlidesList(slides: slides),
            error: (message) =>
                OnboardingErrorState(message: message, onRetry: onRetry),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        OnboardingBottomActions(onComplete: onComplete, onSignIn: onSignIn),
      ],
    );
  }
}

class _OnboardingLoadingShimmer extends StatelessWidget {
  const _OnboardingLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            AppShimmerBox(
              height: 220,
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            SizedBox(height: 18),
            AppShimmerBox(height: 24, width: 220),
            SizedBox(height: 10),
            AppShimmerBox(height: 14),
            SizedBox(height: 8),
            AppShimmerBox(height: 14, width: 260),
          ],
        ),
      ),
    );
  }
}
