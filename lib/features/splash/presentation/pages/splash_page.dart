import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../bloc/splash_cubit.dart';
import '../models/splash_ui_models.dart';
import '../widgets/splash_content.dart';
import '../widgets/splash_error_state.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashPage({
    super.key,
    required this.onComplete,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = const SplashViewData(
      appName: 'MediAI',
      tagline: 'AI-powered health diagnostics',
      durationMs: 2500,
    );

    return BlocProvider(
      create: (_) => getIt<SplashCubit>()..load(),
      child: BlocListener<SplashCubit, SplashState>(
        listenWhen: (previous, current) =>
            current.maybeWhen(completed: () => true, orElse: () => false),
        listener: (context, state) {
          widget.onComplete();
        },
        child: BlocBuilder<SplashCubit, SplashState>(
          builder: (context, state) {
            final errorMessage = state.whenOrNull(error: (message) => message);
            final data = state.whenOrNull(ready: (data) => data) ?? fallback;

            if (errorMessage != null) {
              return Scaffold(
                body: SplashErrorState(
                  onRetry: () => context.read<SplashCubit>().load(),
                ),
              );
            }

            return Scaffold(
              body: SplashContent(
                data: data,
                isDark: isDark,
                controller: _controller,
                fadeAnimation: _fadeAnimation,
                scaleAnimation: _scaleAnimation,
              ),
            );
          },
        ),
      ),
    );
  }
}
