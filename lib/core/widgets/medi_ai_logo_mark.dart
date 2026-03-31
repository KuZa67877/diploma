import 'package:flutter/material.dart';

class MediAiLogoMark extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const MediAiLogoMark({
    super.key,
    required this.size,
    this.color = Colors.white,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MediAiLogoPainter(color: color, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _MediAiLogoPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _MediAiLogoPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * 0.36;

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, ringRadius, ringPaint);

    final pulsePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..moveTo(size.width * 0.23, size.height * 0.53)
      ..lineTo(size.width * 0.38, size.height * 0.53)
      ..lineTo(size.width * 0.47, size.height * 0.40)
      ..lineTo(size.width * 0.57, size.height * 0.63)
      ..lineTo(size.width * 0.67, size.height * 0.47)
      ..lineTo(size.width * 0.77, size.height * 0.47);

    canvas.drawPath(path, pulsePaint);

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.29),
      strokeWidth * 0.55,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MediAiLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
