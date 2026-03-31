import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

class DevLogsOverlayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpenLogs;

  const DevLogsOverlayButton({
    super.key,
    required this.child,
    required this.onOpenLogs,
  });

  @override
  State<DevLogsOverlayButton> createState() => _DevLogsOverlayButtonState();
}

class _DevLogsOverlayButtonState extends State<DevLogsOverlayButton> {
  static const double _buttonWidth = 34;
  static const double _buttonHeight = 58;
  static const double _edgePadding = 8;

  Offset? _position;

  @override
  Widget build(BuildContext context) {
    if (!AppLogger.instance.isEnabled) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final defaultPosition = Offset(
          constraints.maxWidth - _buttonWidth - _edgePadding,
          (constraints.maxHeight - _buttonHeight) / 2,
        );
        final currentPosition = _position ?? defaultPosition;
        final clamped = _clampPosition(
          position: currentPosition,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          insets: mediaQuery.padding,
        );

        return Stack(
          children: [
            widget.child,
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: GestureDetector(
                onTap: widget.onOpenLogs,
                onPanUpdate: (details) {
                  final start = _position ?? clamped;
                  final next = _clampPosition(
                    position: start + details.delta,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                    insets: mediaQuery.padding,
                  );
                  setState(() {
                    _position = next;
                  });
                },
                child: Container(
                  width: _buttonWidth,
                  height: _buttonHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _clampPosition({
    required Offset position,
    required double maxWidth,
    required double maxHeight,
    required EdgeInsets insets,
  }) {
    final minX = _edgePadding;
    final maxX = (maxWidth - _buttonWidth - _edgePadding).clamp(
      minX,
      double.infinity,
    );
    final minY = insets.top + _edgePadding;
    final maxY = (maxHeight - _buttonHeight - insets.bottom - _edgePadding)
        .clamp(minY, double.infinity);
    return Offset(position.dx.clamp(minX, maxX), position.dy.clamp(minY, maxY));
  }
}
