import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import 'auth_divider.dart';
import 'auth_form.dart';
import 'auth_header.dart';
import 'auth_logo_section.dart';
import 'auth_mode_switch.dart';
import 'auth_privacy_note.dart';
import 'auth_social_buttons.dart';

class AuthContent extends StatelessWidget {
  final bool isLogin;
  final bool isLoading;
  final bool isPasswordObscured;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool showSocialButtons;
  final String? errorMessage;

  const AuthContent({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.isPasswordObscured,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onBack,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onTogglePasswordVisibility,
    required this.onGoogle,
    required this.onApple,
    required this.showSocialButtons,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AuthHeader(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthLogoSection(isLogin: isLogin),
                const SizedBox(height: AppConstants.spacingXl),
                AuthForm(
                  formKey: formKey,
                  emailController: emailController,
                  passwordController: passwordController,
                  isLogin: isLogin,
                  isLoading: isLoading,
                  isPasswordObscured: isPasswordObscured,
                  onTogglePasswordVisibility: onTogglePasswordVisibility,
                  onSubmit: onSubmit,
                  errorMessage: errorMessage,
                ),
                const SizedBox(height: AppConstants.spacingLg),
                if (showSocialButtons) ...[
                  const AuthDivider(),
                  const SizedBox(height: AppConstants.spacingLg),
                  AuthSocialButtons(
                    onGoogle: onGoogle,
                    onApple: onApple,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                AuthModeSwitch(
                  isLogin: isLogin,
                  onToggleMode: onToggleMode,
                ),
                const SizedBox(height: AppConstants.spacingLg),
                const AuthPrivacyNote(),
                const SizedBox(height: AppConstants.spacingXl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
