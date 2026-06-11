import 'package:flutter/material.dart';

import 'ink_layer.dart';
import 'ink_layer_controller.dart';
import 'stroke_renderer.dart';

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

/// 把 [InkStroke] 列表渲染成 Catmull-Rom 平滑 + 变宽笔画的 [CustomPainter]。
///
/// 渲染策略下沉到 [StrokeRenderer.drawStroke]；本类只负责遍历与变更检测。
/// 包含橡皮 ([InkTool.eraser]) 笔画时调用 [Canvas.saveLayer]，让
/// [BlendMode.clear] 仅作用于墨迹图层内，不会击穿到底层 widget。
class CanvasInkPainter extends CustomPainter {
  const CanvasInkPainter({required this.strokes});

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final hasEraser = strokes.any((s) => s.tool == InkTool.eraser);
    final paintBounds = Offset.zero & size;
    if (hasEraser) {
      canvas.saveLayer(paintBounds, Paint());
    }
    for (final stroke in strokes) {
      StrokeRenderer.drawStroke(canvas, stroke);
    }
    if (hasEraser) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CanvasInkPainter oldDelegate) => oldDelegate.strokes != strokes;
}
