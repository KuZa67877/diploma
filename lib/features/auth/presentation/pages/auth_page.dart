import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../bloc/auth_cubit.dart';
import '../widgets/auth_content.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onAuthSuccess;

  const AuthPage({
    super.key,
    required this.onBack,
    required this.onAuthSuccess,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().submit(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous != current &&
            current.maybeWhen(success: (_, __) => true, orElse: () => false),
        listener: (context, state) {
          context.hideKeyboard();
          widget.onAuthSuccess();
          context.read<AuthCubit>().resetStatus();
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLogin = state.isLogin;
            final isLoading = state.isLoading;
            final isPasswordObscured = state.isPasswordObscured;
            final errorMessage = state.maybeWhen(
              error: (_, __, message) => message,
              orElse: () => null,
            );

            return Scaffold(
              body: GradientBackground(
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AuthContent(
                      isLogin: isLogin,
                      isLoading: isLoading,
                      isPasswordObscured: isPasswordObscured,
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      onBack: widget.onBack,
                      onSubmit: () => _handleSubmit(context),
                      onToggleMode: () => context.read<AuthCubit>().toggleMode(),
                      onTogglePasswordVisibility: () =>
                          context.read<AuthCubit>().togglePasswordVisibility(),
                      onGoogle: () =>
                          context.read<AuthCubit>().signInWithGoogleProvider(),
                      onApple: () =>
                          context.read<AuthCubit>().signInWithAppleProvider(),
                      showSocialButtons: AppEnv.enableSocialAuth,
                      errorMessage: errorMessage,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
