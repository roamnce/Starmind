// lib/src/mindmap/ui/tree_layout.dart

import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';

/// 树形自动布局算法。
///
/// 采用自顶向下的层次布局策略：
/// 1. 根节点居中在顶部
/// 2. 子节点在下方水平分散
/// 3. 自动计算边界框
class TreeLayout {
  /// 节点宽度
  final double nodeWidth;

  /// 节点高度
  final double nodeHeight;

  /// 水平间距
  final double horizontalSpacing;

  /// 垂直间距
  final double verticalSpacing;

  /// 布局方向
  final LayoutDirection direction;

  const TreeLayout({
    this.nodeWidth = 120,
    this.nodeHeight = 40,
    this.horizontalSpacing = 60,
    this.verticalSpacing = 30,
    this.direction = LayoutDirection.vertical,
  });

  /// 计算所有节点的位置
  ///
  /// 返回 Map<noteId, Offset>，Offset 是节点中心点坐标
  Map<String, Offset> calculate(NoteTreeNode root) {
    final positions = <String, Offset>{};
    _layoutSubtree(root, Offset.zero, positions);
    return positions;
  }

  /// 递归布局子树
  ///
  /// [node] 当前节点
  /// [origin] 当前子树的原点（顶部中心）
  /// [positions] 位置映射（输出参数）
  double _layoutSubtree(
    NoteTreeNode node,
    Offset origin,
    Map<String, Offset> positions,
  ) {
    if (node.children.isEmpty) {
      // 叶子节点：直接放在原点
      positions[node.note.id] = origin;
      return nodeWidth;
    }

    // 先递归布局所有子节点，计算子树总宽度
    final childWidths = <double>[];
    for (final child in node.children) {
      final childOrigin = Offset(
        origin.dx + _sumWidths(childWidths) + childWidths.length * horizontalSpacing,
        origin.dy + nodeHeight + verticalSpacing,
      );
      final width = _layoutSubtree(child, childOrigin, positions);
      childWidths.add(width);
    }

    final totalChildrenWidth = _sumWidths(childWidths) +
        (childWidths.length - 1) * horizontalSpacing;

    // 父节点居中在子节点上方
    final parentX = origin.dx + totalChildrenWidth / 2;
    positions[node.note.id] = Offset(parentX, origin.dy);

    // 调整子节点位置使其相对于父节点居中
    final shiftX = parentX - totalChildrenWidth / 2 - origin.dx;
    if (shiftX != 0) {
      _shiftSubtree(node.children, shiftX, positions);
    }

    return _max(nodeWidth, totalChildrenWidth);
  }

  /// 计算宽度总和
  double _sumWidths(List<double> widths) {
    return widths.fold(0.0, (sum, w) => sum + w);
  }

  /// 平移子树
  void _shiftSubtree(
    List<NoteTreeNode> nodes,
    double shiftX,
    Map<String, Offset> positions,
  ) {
    for (final node in nodes) {
      final current = positions[node.note.id];
      if (current != null) {
        positions[node.note.id] = Offset(current.dx + shiftX, current.dy);
      }
      _shiftSubtree(node.children, shiftX, positions);
    }
  }

  /// 计算树的边界框
  Rect calculateBounds(NoteTreeNode root) {
    final positions = calculate(root);

    if (positions.isEmpty) {
      return Rect.fromLTWH(0, 0, nodeWidth, nodeHeight);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in positions.values) {
      minX = _min(minX, pos.dx - nodeWidth / 2);
      maxX = _max(maxX, pos.dx + nodeWidth / 2);
      minY = _min(minY, pos.dy);
      maxY = _max(maxY, pos.dy + nodeHeight);
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// 计算两节点之间的连线
  List<Connection> calculateConnections(
    NoteTreeNode root,
    Map<String, Offset> positions,
  ) {
    final connections = <Connection>[];
    _collectConnections(root, positions, connections);
    return connections;
  }

  void _collectConnections(
    NoteTreeNode node,
    Map<String, Offset> positions,
    List<Connection> connections,
  ) {
    final parentPos = positions[node.note.id];
    if (parentPos == null) return;

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos != null) {
        connections.add(Connection(
          fromId: node.note.id,
          toId: child.note.id,
          start: Offset(parentPos.dx, parentPos.dy + nodeHeight / 2),
          end: Offset(childPos.dx, childPos.dy - nodeHeight / 2),
        ));
      }
      _collectConnections(child, positions, connections);
    }
  }
}

/// 布局方向
enum LayoutDirection {
  /// 垂直布局（根在上，子在下）
  vertical,
  /// 水平布局（根在左，子在右）
  horizontal,
}

/// 连线数据
class Connection {
  final String fromId;
  final String toId;
  final Offset start;
  final Offset end;

  const Connection({
    required this.fromId,
    required this.toId,
    required this.start,
    required this.end,
  });
}

/// 辅助函数
double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;