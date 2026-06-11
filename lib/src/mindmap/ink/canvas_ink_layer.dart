import 'package:flutter/material.dart';

import 'ink_layer.dart';
import 'ink_layer_controller.dart';
import 'stroke_renderer.dart';

/// 手写墨迹图层 widget。
///
/// **手势处理架构：**
/// - `enabled=false`（非手写模式）：使用 [GestureDetector] 处理手势，
///   但回调为 null，不影响外部手势传递。
/// - `enabled=true`（手写模式）：不使用 [GestureDetector]，让外部
///   [Listener] 直接从 [PointerEvent] 获取压感数据，调用
///   [InkLayerController] 的方法。
///
/// 外部在使用手写模式时，应包裹 [Listener] 并处理：
/// - `onPointerDown` → `controller.beginStroke(..., pressure: pressure)`
/// - `onPointerMove` → `controller.appendPoint(..., pressure: pressure)`
/// - `onPointerUp` → `controller.endStroke(...)`
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
        // 手写模式下不使用 GestureDetector，让外部 Listener 驱动
        if (enabled) {
          return CustomPaint(
            painter: CanvasInkPainter(
              strokes: [
                ...?layer?.strokes,
                if (controller.currentStroke != null) controller.currentStroke!,
              ],
            ),
            child: const SizedBox.expand(),
          );
        }
        // 非手写模式下使用 GestureDetector（但回调为 null）
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
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
