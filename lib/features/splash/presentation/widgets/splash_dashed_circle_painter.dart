import 'package:flutter/material.dart';

class SplashDashedCirclePainter extends CustomPainter {
  final Color color;

  SplashDashedCirclePainter({required this.color});

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
