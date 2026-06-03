// lib/src/mindmap/layout/layout_result.dart

import 'dart:ui';

/// 连线数据
class ConnectionData {
  /// 起点节点 ID
  final String fromId;

  /// 终点节点 ID
  final String toId;

  /// 连线起点锚点（节点边缘）
  final Offset startPoint;

  /// 连线终点锚点（节点边缘）
  final Offset endPoint;

  /// 起点节点中心
  final Offset fromCenter;

  /// 终点节点中心
  final Offset toCenter;

  const ConnectionData({
    required this.fromId,
    required this.toId,
    required this.startPoint,
    required this.endPoint,
    required this.fromCenter,
    required this.toCenter,
  });

  /// 连线方向是否向右
  bool get isRightward => endPoint.dx > startPoint.dx;

  /// 连线方向是否向左
  bool get isLeftward => endPoint.dx < startPoint.dx;
}

/// 布局结果
class LayoutResult {
  /// 节点 ID -> 中心坐标
  final Map<String, Offset> nodePositions;

  /// 节点 ID -> 尺寸
  final Map<String, Size> nodeSizes;

  /// 连线列表
  final List<ConnectionData> connections;

  /// 内容边界框
  final Rect contentBounds;

  const LayoutResult({
    required this.nodePositions,
    required this.nodeSizes,
    required this.connections,
    required this.contentBounds,
  });

  /// 空结果
  static LayoutResult empty = LayoutResult(
    nodePositions: {},
    nodeSizes: {},
    connections: [],
    contentBounds: Rect.zero,
  );

  /// 获取节点边界矩形
  Rect? getNodeRect(String nodeId) {
    final center = nodePositions[nodeId];
    final size = nodeSizes[nodeId];
    if (center == null || size == null) return null;
    return Rect.fromCenter(center: center, width: size.width, height: size.height);
  }
}