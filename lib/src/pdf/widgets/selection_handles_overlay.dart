import 'dart:ui';
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
  final Offset? endHandlePosition;
  final double zoom;
  final void Function(SelectionHandleType handle, Offset newPosition)? onHandleDrag;

  const SelectionHandlesOverlay({
    super.key,
    this.startHandlePosition,
    this.endHandlePosition,
    required this.zoom,
    this.onHandleDrag,
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
            zoom: zoom,
            onDrag: onHandleDrag != null
                ? (pos) => onHandleDrag!(SelectionHandleType.start, pos)
                : null,
          ),
        if (endHandlePosition != null)
          _SelectionHandle(
            type: SelectionHandleType.end,
            position: endHandlePosition!,
            zoom: zoom,
            onDrag: onHandleDrag != null
                ? (pos) => onHandleDrag!(SelectionHandleType.end, pos)
                : null,
          ),
      ],
    );
  }
}

/// Single draggable selection handle.
class _SelectionHandle extends StatefulWidget {
  final SelectionHandleType type;
  final Offset position;
  final double zoom;
  final void Function(Offset newPosition)? onDrag;

  const _SelectionHandle({
    required this.type,
    required this.position,
    required this.zoom,
    this.onDrag,
  });

  @override
  State<_SelectionHandle> createState() => _SelectionHandleState();
}

class _SelectionHandleState extends State<_SelectionHandle> {
  Offset? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    // Handle size scales with zoom, but has min/max bounds
    final handleSize = (12.0 * widget.zoom).clamp(8.0, 24.0);

    return Positioned(
      left: widget.type == SelectionHandleType.start
          ? widget.position.dx - handleSize / 2
          : widget.position.dx - handleSize / 2,
      top: widget.position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          _dragPosition = widget.position;
        },
        onPanUpdate: (details) {
          if (_dragPosition == null || widget.onDrag == null) return;

          _dragPosition = _dragPosition! + details.delta;
          widget.onDrag!(_dragPosition!);
        },
        onPanEnd: (details) {
          _dragPosition = null;
        },
        child: Container(
          width: handleSize,
          height: handleSize * 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(handleSize / 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Handle ball
              Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
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