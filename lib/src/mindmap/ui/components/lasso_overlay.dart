// lib/src/mindmap/ui/components/lasso_overlay.dart
//
// 框选覆盖层组件。
//
// 用于实现框选多个节点的手势覆盖层。

import 'package:flutter/material.dart';
import '../lasso_painter.dart';

/// 框选覆盖层。
///
/// 显示框选矩形并处理框选手势。
class LassoOverlay extends StatelessWidget {
  /// 框选开始回调
  final void Function(Offset localPosition) onPanStart;

  /// 框选更新回调
  final void Function(Offset localPosition) onPanUpdate;

  /// 框选结束回调
  final void Function() onPanEnd;

  /// 当前框选矩形
  final Rect? selectionRect;

  const LassoOverlay({
    super.key,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.selectionRect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => onPanStart(details.localPosition),
      onPanUpdate: (details) => onPanUpdate(details.localPosition),
      onPanEnd: (details) => onPanEnd(),
      child: CustomPaint(
        painter: LassoPainter(selectionRect: selectionRect),
        size: Size.infinite,
      ),
    );
  }
}
