import 'package:flutter/material.dart';

import 'ink_layer.dart';
import 'ink_layer_controller.dart';

class CanvasInkLayer extends StatelessWidget {
  const CanvasInkLayer({
    super.key,
    required this.controller,
    required this.ownerType,
    required this.ownerId,
    this.enabled = true,
    this.onLayerChanged,
  });

  final InkLayerController controller;
  final InkLayerOwnerType ownerType;
  final String ownerId;
  final bool enabled;
  final void Function(InkLayer layer)? onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layer = controller.getLayer(ownerType, ownerId);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: enabled ? (details) => controller.beginStroke(ownerType, ownerId, details.localPosition) : null,
          onPanUpdate: enabled ? (details) => controller.appendPoint(details.localPosition) : null,
          onPanEnd: enabled
              ? (_) {
                  controller.endStroke(ownerType, ownerId);
                  final layer = controller.getLayer(ownerType, ownerId);
                  if (layer != null) onLayerChanged?.call(layer);
                }
              : null,
          child: CustomPaint(
            painter: CanvasInkPainter(
              strokes: [
                ...?layer?.strokes,
                if (controller.currentStroke != null) controller.currentStroke!,
              ],
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class CanvasInkPainter extends CustomPainter {
  const CanvasInkPainter({required this.strokes});

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.tool == InkTool.highlighter ? BlendMode.srcOver : BlendMode.srcOver;
      final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasInkPainter oldDelegate) => oldDelegate.strokes != strokes;
}
