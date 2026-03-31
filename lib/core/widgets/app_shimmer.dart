import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        widget.baseColor ??
        (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0));
    final highlight =
        widget.highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = (_controller.value * 2) - 1;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + shift, 0),
              end: Alignment(-0.8 + shift, 0),
              colors: [base, highlight, base],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class AppShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;

  const AppShimmerBox({
    super.key,
    this.width,
    this.height,
    this.margin,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMuted : Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(12))
            : null,
      ),
    );
  }
}
