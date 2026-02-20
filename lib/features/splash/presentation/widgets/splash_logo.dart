import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/splash_ui_models.dart';
import 'splash_dashed_circle_painter.dart';

class SplashLogo extends StatelessWidget {
  final SplashViewData data;
  final bool isDark;
  final AnimationController controller;

  const SplashLogo({
    super.key,
    required this.data,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 144,
          height: 144,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Curves.linear,
                  ),
                ),
                child: CustomPaint(
                  size: const Size(124, 124),
                  painter: SplashDashedCirclePainter(
                    color: isDark
                        ? AppColors.darkPrimary.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryGlow,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          data.appName,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.tagline,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
