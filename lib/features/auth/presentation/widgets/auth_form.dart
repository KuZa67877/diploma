import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_input.dart';

class AuthForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLogin;
  final bool isLoading;
  final bool isPasswordObscured;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final String? errorMessage;

  const AuthForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLogin,
    required this.isLoading,
    required this.isPasswordObscured,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Form(
      key: formKey,
      child: Column(
        children: [
          CustomInput(
            label: localizations.get('email'),
            placeholder: 'you@example.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(
              LucideIcons.mail,
              size: 20,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!value.isValidEmail) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.spacingMd),
          CustomInput(
            label: localizations.get('password'),
            placeholder: '••••••••',
            controller: passwordController,
            obscureText: true,
            isObscured: isPasswordObscured,
            onToggleObscure: onTogglePasswordVisibility,
            prefixIcon: const Icon(
              LucideIcons.lock,
              size: 20,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          if (isLogin) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  localizations.get('forgotPassword'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingLg),
          CustomButton(
            text: isLogin
                ? localizations.get('signIn')
                : localizations.get('createAccount'),
            onPressed: onSubmit,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
            fullWidth: true,
            isLoading: isLoading,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
