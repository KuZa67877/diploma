import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class OnboardingLogo extends StatelessWidget {
  const OnboardingLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: _RotatingDashedBorder(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppConstants.radius3xl,
            ),
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
      ),
    );
  }
}

class _RotatingDashedBorder extends StatefulWidget {
  final Widget child;

  const _RotatingDashedBorder({required this.child});

  @override
  State<_RotatingDashedBorder> createState() => _RotatingDashedBorderState();
}

class _RotatingDashedBorderState extends State<_RotatingDashedBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _rotationController,
          child: CustomPaint(
            size: const Size(122, 122),
            painter: _DashedCirclePainter(
              color: isDark
                  ? AppColors.darkPrimary.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashLength = 8.0;
    const gapLength = 4.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(32),
    );

    final path = Path()..addRRect(rect);
    _drawDashedPath(canvas, path, paint, dashLength, gapLength);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashLength).clamp(0.0, metric.length);

        final extractPath = metric.extractPath(start, end);
        canvas.drawPath(extractPath, paint);

        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
