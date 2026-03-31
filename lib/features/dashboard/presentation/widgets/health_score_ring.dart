import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dashboard_ui_models.dart';

class HealthScoreRing extends StatefulWidget {
  final int score;
  final DashboardScoreState state;
  final double size;

  const HealthScoreRing({
    super.key,
    required this.score,
    required this.state,
    this.size = 280,
  });

  @override
  State<HealthScoreRing> createState() => _HealthScoreRingState();
}

class _HealthScoreRingState extends State<HealthScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _HealthScoreOrbitPainter(
              progress: widget.score.clamp(0, 100) / 100,
              animationValue: _controller.value,
              colors: _paletteForState(widget.state),
            ),
          );
        },
      ),
    );
  }

  List<Color> _paletteForState(DashboardScoreState state) {
    switch (state) {
      case DashboardScoreState.risk:
        return const [Color(0xFFF97316), Color(0xFFFDBA74), Color(0xFFEF4444)];
      case DashboardScoreState.attention:
        return const [Color(0xFFF59E0B), Color(0xFFFDE68A), Color(0xFFD97706)];
      case DashboardScoreState.noAccess:
      case DashboardScoreState.calculating:
      case DashboardScoreState.stable:
        return const [Color(0xFF2A9D8F), Color(0xFFA7E8E1), Color(0xFF1F7A71)];
    }
  }
}

class _HealthScoreOrbitPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final List<Color> colors;

  _HealthScoreOrbitPainter({
    required this.progress,
    required this.animationValue,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rotation = animationValue * 2 * math.pi;

    final ringConfigs = [
      (radius: size.width * 0.41, stroke: 6.0, sweep: 1.45, color: colors[0]),
      (radius: size.width * 0.46, stroke: 5.0, sweep: 1.08, color: colors[1]),
      (radius: size.width * 0.39, stroke: 4.0, sweep: 0.72, color: colors[2]),
    ];

    for (var i = 0; i < ringConfigs.length; i++) {
      final cfg = ringConfigs[i];
      final start = (-math.pi / 2) + rotation * (i.isEven ? 1 : -1);
      final sweep = cfg.sweep * (0.62 + (progress * 0.38));
      final paint = Paint()
        ..color = cfg.color.withValues(alpha: 0.8)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = cfg.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: cfg.radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    final dots = [
      (
        radius: size.width * 0.46,
        angle: rotation + 0.6,
        size: 4.0,
        color: colors[1],
      ),
      (
        radius: size.width * 0.44,
        angle: rotation + math.pi + 0.2,
        size: 3.0,
        color: colors[0],
      ),
      (
        radius: size.width * 0.47,
        angle: -rotation + math.pi / 2,
        size: 2.5,
        color: colors[1],
      ),
    ];

    for (final dot in dots) {
      final point = Offset(
        center.dx + dot.radius * math.cos(dot.angle),
        center.dy + dot.radius * math.sin(dot.angle),
      );
      canvas.drawCircle(
        point,
        dot.size,
        Paint()..color = dot.color.withValues(alpha: 0.92),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthScoreOrbitPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.colors != colors;
  }
}
