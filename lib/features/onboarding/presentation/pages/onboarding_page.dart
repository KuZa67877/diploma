import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/onboarding_cubit.dart';
import '../widgets/onboarding_content.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSignIn;

  const OnboardingPage({
    super.key,
    required this.onComplete,
    required this.onSignIn,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingCubit>()..loadSlides(),
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: OnboardingContent(
                      state: state,
                      onComplete: widget.onComplete,
                      onSignIn: widget.onSignIn,
                      onRetry: () => context.read<OnboardingCubit>().loadSlides(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
