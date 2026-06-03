import 'package:flutter/material.dart';

/// Selection handle position.
enum SelectionHandleType {
  start,
  end,
}

/// Overlay widget showing draggable selection handles.
///
/// Two handles (left and right) allow adjusting selection range.
/// Uses iOS-style water-drop shaped handles.
class SelectionHandlesOverlay extends StatelessWidget {
  final Offset? startHandlePosition;
  final double startLineHeight;
  final Offset? endHandlePosition;
  final double endLineHeight;
  final double zoom;
  final void Function(SelectionHandleType handle, Offset newPosition)? onHandleDrag;
  final VoidCallback? onDragEnd;

  const SelectionHandlesOverlay({
    super.key,
    this.startHandlePosition,
    this.startLineHeight = 20.0,
    this.endHandlePosition,
    this.endLineHeight = 20.0,
    required this.zoom,
    this.onHandleDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (startHandlePosition == null && endHandlePosition == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (startHandlePosition != null)
          _SelectionHandle(
            type: SelectionHandleType.start,
            position: startHandlePosition!,
            lineHeight: startLineHeight,
            zoom: zoom,
            onDrag: onHandleDrag != null
                ? (pos) => onHandleDrag!(SelectionHandleType.start, pos)
                : null,
            onDragEnd: onDragEnd,
          ),
        if (endHandlePosition != null)
          _SelectionHandle(
            type: SelectionHandleType.end,
            position: endHandlePosition!,
            lineHeight: endLineHeight,
            zoom: zoom,
            onDrag: onHandleDrag != null
                ? (pos) => onHandleDrag!(SelectionHandleType.end, pos)
                : null,
            onDragEnd: onDragEnd,
          ),
      ],
    );
  }
}

/// Single draggable selection handle with iOS-style water-drop shape.
class _SelectionHandle extends StatefulWidget {
  final SelectionHandleType type;
  final Offset position;
  final double lineHeight;
  final double zoom;
  final void Function(Offset newPosition)? onDrag;
  final VoidCallback? onDragEnd;

  const _SelectionHandle({
    required this.type,
    required this.position,
    required this.lineHeight,
    required this.zoom,
    this.onDrag,
    this.onDragEnd,
  });

  @override
  State<_SelectionHandle> createState() => _SelectionHandleState();
}

class _SelectionHandleState extends State<_SelectionHandle> {
  Offset? _dragStartPos;
  Offset? _dragStartTouchPos;

  @override
  Widget build(BuildContext context) {
    // Premium selection blue color (iOS style)
    final color = const Color(0xFF007AFF);

    // Handle dimensions (iOS-style water drop)
    final double handleWidth = 14.0;
    final double handleHeight = 22.0;
    final double touchAreaWidth = 44.0;

    // Calculate position
    double leftPos = widget.position.dx - touchAreaWidth / 2;
    double topPos = widget.type == SelectionHandleType.start
        ? widget.position.dy - handleHeight + 2
        : widget.position.dy - 2;

    return Positioned(
      left: leftPos,
      top: topPos,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          _dragStartPos = widget.position;
          _dragStartTouchPos = details.globalPosition;
        },
        onPanUpdate: (details) {
          if (_dragStartPos == null || _dragStartTouchPos == null || widget.onDrag == null) return;
          final currentTouchPos = details.globalPosition;
          final delta = currentTouchPos - _dragStartTouchPos!;
          widget.onDrag!(_dragStartPos! + delta);
        },
        onPanEnd: (details) {
          _dragStartPos = null;
          _dragStartTouchPos = null;
          widget.onDragEnd?.call();
        },
        child: Container(
          width: touchAreaWidth,
          height: handleHeight + widget.lineHeight.clamp(10.0, 30.0),
          color: Colors.transparent, // wide touch hit target
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Vertical line from handle to text
              Positioned(
                left: touchAreaWidth / 2 - 1.5,
                top: widget.type == SelectionHandleType.start
                    ? handleHeight - 4
                    : 0,
                width: 3.0,
                height: widget.lineHeight.clamp(10.0, 30.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              // Water-drop shaped handle
              Positioned(
                left: touchAreaWidth / 2 - handleWidth / 2,
                top: widget.type == SelectionHandleType.start ? 0 : null,
                bottom: widget.type == SelectionHandleType.end ? 0 : null,
                child: CustomPaint(
                  size: Size(handleWidth, handleHeight),
                  painter: _WaterDropHandlePainter(
                    color: color,
                    isInverted: widget.type == SelectionHandleType.end,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter for iOS-style water-drop selection handle.
class _WaterDropHandlePainter extends CustomPainter {
  final Color color;
  final bool isInverted;

  _WaterDropHandlePainter({
    required this.color,
    this.isInverted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();

    // Water drop shape
    final width = size.width;
    final height = size.height;
    final cornerRadius = width / 2;

    if (!isInverted) {
      // Normal orientation (pointing down, ball on top)
      // Ball at top
      path.moveTo(width / 2 - cornerRadius, height - 2);
      path.lineTo(width / 2 - cornerRadius, cornerRadius + 2);
      path.arcToPoint(
        Offset(width / 2 + cornerRadius, cornerRadius + 2),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );
      path.lineTo(width / 2 + cornerRadius, height - 2);
      // Point at bottom center
      path.quadraticBezierTo(
        width / 2 + cornerRadius - 2, height + 2,
        width / 2, height + 6,
      );
      path.quadraticBezierTo(
        width / 2 - cornerRadius + 2, height + 2,
        width / 2 - cornerRadius, height - 2,
      );
    } else {
      // Inverted orientation (pointing up, ball on bottom)
      // Point at top center
      path.moveTo(width / 2 - cornerRadius, 2);
      path.quadraticBezierTo(
        width / 2 - cornerRadius + 2, -2,
        width / 2, -6,
      );
      path.quadraticBezierTo(
        width / 2 + cornerRadius - 2, -2,
        width / 2 + cornerRadius, 2,
      );
      // Ball at bottom
      path.lineTo(width / 2 + cornerRadius, height - cornerRadius - 2);
      path.arcToPoint(
        Offset(width / 2 - cornerRadius, height - cornerRadius - 2),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      );
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropHandlePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isInverted != isInverted;
  }
}