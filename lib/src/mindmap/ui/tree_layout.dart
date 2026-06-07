// ============================================================================
// DEPRECATED: This class is kept for backward compatibility.
//
// New code should use TreeLayoutEngine from layout/tree_layout_engine.dart
// which provides better separation of concerns and anchor point calculation.
//
// This file will be removed in a future version.
// ============================================================================

// lib/src/mindmap/ui/tree_layout.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';

/// 树形布局方向
enum LayoutDirection {
  /// 垂直布局（根在上，子在下）
  vertical,
  /// 水平布局（根在左，子在右）
  horizontal,
  /// 左侧布局（根在右，子在左）
  left,
  /// 两侧布局（根在中央，子在左右两侧）
  bothSides,
}

/// 树形自动布局算法
/// 
/// **重要：positions 存储的是节点中心坐标（与 TreeLayoutEngine 一致）**
class TreeLayout {
  final double nodeWidth;
  final double nodeHeight;
  final double horizontalSpacing;
  final double verticalSpacing;
  final LayoutDirection direction;

  // 缓存节点尺寸与子树排布高度，非线程安全但可通过 clear() 重置
  static final _nodeSizes = <String, Size>{};
  static final _subtreeLayoutHeights = <String, double>{};

  const TreeLayout({
    this.nodeWidth = 120,
    this.nodeHeight = 40,
    this.horizontalSpacing = 60,
    this.verticalSpacing = 30,
    this.direction = LayoutDirection.bothSides,
  });

  /// 获取缓存的每个节点的尺寸
  Map<String, Size> get nodeSizes => _nodeSizes;

  /// 计算子树的尺寸大小 (自底向上递归)
  Size _calculateSubtreeSize(NoteTreeNode node) {
    if (node.note.highlightStyle == 'nestedCard') {
      if (node.children.isEmpty || node.note.isCollapsed) {
        final size = Size(nodeWidth + 32, nodeHeight + 32);
        _nodeSizes[node.note.id] = size;
        return size;
      }

      double childMaxW = 0;
      double childTotalH = 0;
      for (final child in node.children) {
        final childSize = _calculateSubtreeSize(child);
        childMaxW = max(childMaxW, childSize.width);
        childTotalH += childSize.height + 12; // 嵌套卡片紧凑垂直间距为 12
      }
      if (node.children.isNotEmpty) {
        childTotalH -= 12;
      }

      final w = max(nodeWidth, childMaxW) + 32; // 左右 16px padding
      final h = nodeHeight + childTotalH + 32; // 顶部 title + 子树排布高 + padding
      final size = Size(w, h);
      _nodeSizes[node.note.id] = size;
      return size;
    } else {
      final size = Size(nodeWidth, nodeHeight);
      _nodeSizes[node.note.id] = size;
      for (final child in node.children) {
        _calculateSubtreeSize(child);
      }
      return size;
    }
  }

  /// 计算子树排布所需的总占位高度 (用于树形结构中心对齐)
  double _calculateSubtreeLayoutHeight(NoteTreeNode node) {
    final selfHeight = _nodeSizes[node.note.id]?.height ?? nodeHeight;
    if (node.children.isEmpty || node.note.isCollapsed) {
      _subtreeLayoutHeights[node.note.id] = selfHeight;
      return selfHeight;
    }

    // 如果是嵌套卡片组，其子节点全部在内部排列，因此对外占位高度仅为容器自身高度
    if (node.note.highlightStyle == 'nestedCard') {
      _subtreeLayoutHeights[node.note.id] = selfHeight;
      return selfHeight;
    }

    double childrenHeight = 0;
    for (final child in node.children) {
      childrenHeight += _calculateSubtreeLayoutHeight(child) + verticalSpacing;
    }
    childrenHeight -= verticalSpacing;

    final layoutHeight = max(selfHeight, childrenHeight);
    _subtreeLayoutHeights[node.note.id] = layoutHeight;
    return layoutHeight;
  }

  /// 计算所有节点中心位置坐标
  /// 
  /// **返回的 positions 存储节点中心坐标（不是顶部中心）**
  Map<String, Offset> calculate(NoteTreeNode root) {
    final positions = <String, Offset>{};
    _nodeSizes.clear();
    _subtreeLayoutHeights.clear();

    // 1. 自底向上递归计算各节点有效渲染尺寸
    _calculateSubtreeSize(root);

    // 2. 自底向上计算树形占位空间高度
    _calculateSubtreeLayoutHeight(root);
    

    if (root.note.highlightStyle == 'nestedCard') {
      positions[root.note.id] = Offset.zero;
      if (root.children.isNotEmpty && !root.note.isCollapsed) {
        _layoutNestedCardChildren(root, Offset.zero, positions, true);
      }
      return positions;
    }
    if (direction == LayoutDirection.bothSides) {
      // 根节点中心在原点
      positions[root.note.id] = Offset.zero;
      final children = root.children;
      if (children.isEmpty) return positions;

      final leftChildren = <NoteTreeNode>[];
      final rightChildren = <NoteTreeNode>[];
      
      for (int i = 0; i < children.length; i++) {
        if (i % 2 == 0) {
          rightChildren.add(children[i]);
        } else {
          leftChildren.add(children[i]);
        }
      }

      final rootWidth = _nodeSizes[root.note.id]?.width ?? nodeWidth;

      // 右侧子树自顶向下横向排布
      // 传入根节点中心坐标 (0, 0)
      _layoutSubtrees(rightChildren, Offset(horizontalSpacing + rootWidth / 2, 0), positions, true);
      // 左侧子树自顶向下横向排布
      _layoutSubtrees(leftChildren, Offset(-horizontalSpacing - rootWidth / 2, 0), positions, false);

      return positions;
    }

    // 单侧布局
    final rootWidth = _nodeSizes[root.note.id]?.width ?? nodeWidth;
    positions[root.note.id] = Offset.zero;

    if (root.children.isEmpty) return positions;

    final isRight = direction == LayoutDirection.horizontal;
    final startX = isRight
        ? rootWidth / 2 + horizontalSpacing
        : -rootWidth / 2 - horizontalSpacing;

    _layoutSubtrees(root.children, Offset(startX, 0), positions, isRight);

    return positions;
  }

  /// 递归布局子树列表
  void _layoutSubtrees(
    List<NoteTreeNode> nodes,
    Offset origin,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    if (nodes.isEmpty) return;

    double totalHeight = 0;
    for (final node in nodes) {
      totalHeight += _subtreeLayoutHeights[node.note.id] ?? nodeHeight;
      totalHeight += verticalSpacing;
    }
    totalHeight -= verticalSpacing;

    // origin 是父节点的中心坐标
    // currentY 是当前子树布局的起始 Y（从总高度的顶部开始）
    double currentY = origin.dy - totalHeight / 2;

    for (final node in nodes) {
      final nodeSize = _nodeSizes[node.note.id] ?? Size(nodeWidth, nodeHeight);
      final nodeH = nodeSize.height;
      final layoutHeight = _subtreeLayoutHeights[node.note.id] ?? nodeH;

      // 计算节点中心坐标
      // childY 是节点中心的 Y 坐标
      final childY = currentY + (layoutHeight - nodeH) / 2 + nodeH / 2;
      final childX = isRight
          ? origin.dx + nodeSize.width / 2
          : origin.dx - nodeSize.width / 2;

      _layoutSubtreeSingle(node, Offset(childX, childY), positions, isRight);
      currentY += layoutHeight + verticalSpacing;
    }
  }

  /// 递归布局单个子树
  void _layoutSubtreeSingle(
    NoteTreeNode node,
    Offset centerPos,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    // centerPos 是节点中心坐标
    positions[node.note.id] = centerPos;

    if (node.children.isEmpty || node.note.isCollapsed) return;

    final nodeSize = _nodeSizes[node.note.id] ?? Size(nodeWidth, nodeHeight);

    // 嵌套卡片组：子节点在容器内紧凑排布
    if (node.note.highlightStyle == 'nestedCard') {
      _layoutNestedCardChildren(node, centerPos, positions, isRight);
      return;
    }

    // 普通节点：子节点在左/右两侧排布
    final startX = isRight
        ? centerPos.dx + nodeSize.width / 2 + horizontalSpacing
        : centerPos.dx - nodeSize.width / 2 - horizontalSpacing;

    _layoutSubtrees(node.children, Offset(startX, centerPos.dy), positions, isRight);
  }

  /// 嵌套卡片内部子卡片紧凑排布
  void _layoutNestedCardChildren(
    NoteTreeNode node,
    Offset centerPos,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    // centerPos 是容器中心坐标
    // 容器顶部 Y = 中心 Y - 高度/2
    final containerTop = centerPos.dy - (_nodeSizes[node.note.id]?.height ?? nodeHeight) / 2;
    
    // 子节点起始 Y = 容器顶部 + 标题栏高度(40) + padding(16)
    double currentY = containerTop + nodeHeight + 16;

    for (final child in node.children) {
      final childHeight = _nodeSizes[child.note.id]?.height ?? nodeHeight;

      // 水平居中于容器内
      final childX = centerPos.dx;
      // childY 是子节点中心的 Y 坐标
      final childY = currentY + childHeight / 2;

      _layoutSubtreeSingle(child, Offset(childX, childY), positions, isRight);
      currentY += childHeight + 12;
    }
  }

  /// 计算树的连线
  /// 
  /// **positions 必须是节点中心坐标**
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

    // 嵌套容器卡片内部不生成树状贝塞尔连线
    if (node.note.highlightStyle == 'nestedCard') {
      for (final child in node.children) {
        _collectConnections(child, positions, connections);
      }
      return;
    }

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos != null) {
        final parentSize = _nodeSizes[node.note.id] ?? Size(nodeWidth, nodeHeight);
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

        // positions 存储的是节点中心坐标
        // 连线锚点连接到节点边缘中心点
        final isRightSide = childPos.dx > parentPos.dx;

        Offset start, end;
        if (isRightSide) {
          // 子节点在右侧：从父节点右边缘中心连到子节点左边缘中心
          start = Offset(parentPos.dx + parentSize.width / 2, parentPos.dy);
          end = Offset(childPos.dx - childSize.width / 2, childPos.dy);
        } else {
          // 子节点在左侧：从父节点左边缘中心连到子节点右边缘中心
          start = Offset(parentPos.dx - parentSize.width / 2, parentPos.dy);
          end = Offset(childPos.dx + childSize.width / 2, childPos.dy);
        }

        connections.add(Connection(
          fromId: node.note.id,
          toId: child.note.id,
          start: start,
          end: end,
        ));
      }
      _collectConnections(child, positions, connections);
    }
  }

  /// 计算整个脑图边界框
  Rect calculateBounds(NoteTreeNode root) {
    _nodeSizes.clear();
    _subtreeLayoutHeights.clear();
    _calculateSubtreeSize(root);
    _calculateSubtreeLayoutHeight(root);

    final positions = calculate(root);

    if (positions.isEmpty) {
      return Rect.fromLTWH(0, 0, nodeWidth, nodeHeight);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final entry in positions.entries) {
      final id = entry.key;
      final pos = entry.value;  // 中心坐标
      final size = _nodeSizes[id] ?? Size(nodeWidth, nodeHeight);

      minX = pos.dx - size.width / 2 < minX ? pos.dx - size.width / 2 : minX;
      maxX = pos.dx + size.width / 2 > maxX ? pos.dx + size.width / 2 : maxX;
      minY = pos.dy - size.height / 2 < minY ? pos.dy - size.height / 2 : minY;
      maxY = pos.dy + size.height / 2 > maxY ? pos.dy + size.height / 2 : maxY;
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }
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
