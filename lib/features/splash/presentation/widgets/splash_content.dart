import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/splash_ui_models.dart';
import 'splash_logo.dart';

class SplashContent extends StatelessWidget {
  final SplashViewData data;
  final bool isDark;
  final AnimationController controller;
  final Animation<double> fadeAnimation;
  final Animation<double> scaleAnimation;

  const SplashContent({
    super.key,
    required this.data,
    required this.isDark,
    required this.controller,
    required this.fadeAnimation,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkBackground,
                  AppColors.darkCard,
                ]
              : [
                  AppColors.primaryLight,
                  AppColors.lightBackground,
                ],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: SplashLogo(
              data: data,
              isDark: isDark,
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }
}
