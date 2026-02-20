import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';

class AuthModeSwitch extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggleMode;

  const AuthModeSwitch({
    super.key,
    required this.isLogin,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin
              ? localizations.get('dontHaveAccount')
              : localizations.get('alreadyHaveAccountShort'),
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
          ),
        ),
        TextButton(
          onPressed: onToggleMode,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isLogin ? localizations.get('signUp') : localizations.get('signIn'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
