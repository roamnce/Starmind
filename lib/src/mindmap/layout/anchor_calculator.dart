// lib/src/mindmap/layout/anchor_calculator.dart

import 'dart:ui';

/// 锚点计算器
///
/// 计算连线锚点位置，确保锚点精确连接到节点边缘中心
class AnchorCalculator {
  /// 计算从一个节点到另一个节点的连线锚点
  ///
  /// [nodeCenter] 当前节点中心坐标
  /// [nodeSize] 当前节点尺寸
  /// [targetCenter] 目标节点中心坐标
  /// 返回当前节点边缘上的锚点坐标
  static Offset calculateAnchorPoint({
    required Offset nodeCenter,
    required Size nodeSize,
    required Offset targetCenter,
  }) {
    // 确定连线方向：目标在右边则锚点在右边缘，否则在左边缘
    final isRightward = targetCenter.dx > nodeCenter.dx;

    // 锚点 X 坐标：在节点边缘的水平中心
    final anchorX = isRightward
        ? nodeCenter.dx + nodeSize.width / 2   // 右边缘
        : nodeCenter.dx - nodeSize.width / 2;  // 左边缘

    // 锚点 Y 坐标：节点垂直中心
    final anchorY = nodeCenter.dy;

    return Offset(anchorX, anchorY);
  }

  /// 计算两个节点之间的连线锚点对
  ///
  /// [fromCenter] 起点节点中心
  /// [fromSize] 起点节点尺寸
  /// [toCenter] 终点节点中心
  /// [toSize] 终点节点尺寸
  /// 返回 (起点锚点, 终点锚点)
  static (Offset, Offset) calculateAnchorPair({
    required Offset fromCenter,
    required Size fromSize,
    required Offset toCenter,
    required Size toSize,
  }) {
    final startAnchor = calculateAnchorPoint(
      nodeCenter: fromCenter,
      nodeSize: fromSize,
      targetCenter: toCenter,
    );

    final endAnchor = calculateAnchorPoint(
      nodeCenter: toCenter,
      nodeSize: toSize,
      targetCenter: fromCenter,
    );

    return (startAnchor, endAnchor);
  }

  /// 计算节点四个边的锚点
  ///
  /// 返回 (左锚点, 上锚点, 右锚点, 下锚点)
  static ({Offset left, Offset top, Offset right, Offset bottom}) calculateEdgeAnchors({
    required Offset nodeCenter,
    required Size nodeSize,
  }) {
    return (
      left: Offset(nodeCenter.dx - nodeSize.width / 2, nodeCenter.dy),
      top: Offset(nodeCenter.dx, nodeCenter.dy - nodeSize.height / 2),
      right: Offset(nodeCenter.dx + nodeSize.width / 2, nodeCenter.dy),
      bottom: Offset(nodeCenter.dx, nodeCenter.dy + nodeSize.height / 2),
    );
  }
}
