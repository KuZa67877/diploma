import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

enum ButtonVariant { primary, secondary, ghost, ai, medical }

enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final Widget? icon;
  final bool isLoading;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getBackgroundColor(isDark),
          foregroundColor: _getForegroundColor(isDark),
          elevation: variant == ButtonVariant.ghost ? 0 : 2,
          shadowColor: _getShadowColor(isDark),
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getForegroundColor(isDark),
                  ),
                ),
              )
            else if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: _getFontSize(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    switch (variant) {
      case ButtonVariant.primary:
        return isDark ? AppColors.darkPrimary : AppColors.primary;
      case ButtonVariant.secondary:
        return isDark ? AppColors.darkSecondary : AppColors.secondary;
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.ai:
        return isDark ? AppColors.darkAccent : AppColors.accent;
      case ButtonVariant.medical:
        return isDark ? AppColors.darkCard : AppColors.lightCard;
    }
  }

  Color _getForegroundColor(bool isDark) {
    switch (variant) {
      case ButtonVariant.primary:
        return AppColors.primaryForeground;
      case ButtonVariant.secondary:
        return AppColors.secondaryForeground;
      case ButtonVariant.ghost:
        return isDark ? AppColors.darkForeground : AppColors.lightForeground;
      case ButtonVariant.ai:
        return AppColors.accentForeground;
      case ButtonVariant.medical:
        return isDark ? AppColors.darkForeground : AppColors.lightForeground;
    }
  }

  Color _getShadowColor(bool isDark) {
    if (variant == ButtonVariant.ai) {
      return AppColors.accent.withValues(alpha: 0.3);
    }
    if (variant == ButtonVariant.primary) {
      return AppColors.primary.withValues(alpha: 0.3);
    }
    return Colors.black.withValues(alpha: 0.1);
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }
}

