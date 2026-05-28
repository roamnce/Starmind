import 'package:flutter/material.dart';

/// Selection handle position.
enum SelectionHandleType {
  start,
  end,
}

/// Overlay widget showing draggable selection handles.
///
/// Two handles (left and right) allow adjusting selection range.
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

/// Single draggable selection handle.
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
    // Premium classic selection blue color
    final color = const Color(0xFF0A84FF);

    final double ballSize = 12.0;
    final double touchAreaWidth = 36.0;
    final double lineHeight = widget.lineHeight;

    // The container height
    final double totalHeight = lineHeight + ballSize / 2;

    double leftPos = widget.position.dx - touchAreaWidth / 2;
    double topPos = widget.type == SelectionHandleType.start
        ? widget.position.dy - ballSize / 2
        : widget.position.dy;

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
          height: totalHeight,
          color: Colors.transparent, // wide touch hit target
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.type == SelectionHandleType.start) ...[
                // Start line
                Positioned(
                  left: touchAreaWidth / 2 - 1,
                  top: ballSize / 2,
                  width: 2.0,
                  height: lineHeight,
                  child: Container(color: color),
                ),
                // Start ball
                Positioned(
                  left: touchAreaWidth / 2 - ballSize / 2,
                  top: 0,
                  width: ballSize,
                  height: ballSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // End line
                Positioned(
                  left: touchAreaWidth / 2 - 1,
                  top: 0,
                  width: 2.0,
                  height: lineHeight,
                  child: Container(color: color),
                ),
                // End ball
                Positioned(
                  left: touchAreaWidth / 2 - ballSize / 2,
                  top: lineHeight - ballSize / 2,
                  width: ballSize,
                  height: ballSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}