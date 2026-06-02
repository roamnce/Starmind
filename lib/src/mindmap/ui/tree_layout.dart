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
  Map<String, Offset> calculate(NoteTreeNode root) {
    final positions = <String, Offset>{};
    _nodeSizes.clear();
    _subtreeLayoutHeights.clear();

    // 1. 自底向上递归计算各节点有效渲染尺寸
    _calculateSubtreeSize(root);

    // 2. 自底向上计算树形占位空间高度
    _calculateSubtreeLayoutHeight(root);
    
    if (direction == LayoutDirection.bothSides) {
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
      final rootHeight = _nodeSizes[root.note.id]?.height ?? nodeHeight;

      // 右侧子树自顶向下横向排布
      _layoutSubtrees(rightChildren, Offset(horizontalSpacing + rootWidth / 2, rootHeight / 2), positions, true);
      // 左侧子树自顶向下横向排布
      _layoutSubtrees(leftChildren, Offset(-horizontalSpacing - rootWidth / 2, rootHeight / 2), positions, false);
    } else {
      // 垂直或单侧布局
      final isRight = direction != LayoutDirection.left;
      _layoutSubtreeSingle(root, Offset.zero, positions, isRight);
    }
    return positions;
  }

  /// 横向对称多子树排列 (两侧布局辅助)
  void _layoutSubtrees(
    List<NoteTreeNode> nodes,
    Offset origin,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    if (nodes.isEmpty) return;

    double totalLayoutHeight = 0;
    for (final node in nodes) {
      totalLayoutHeight += (_subtreeLayoutHeights[node.note.id] ?? nodeHeight) + verticalSpacing;
    }
    totalLayoutHeight -= verticalSpacing;

    double currentY = origin.dy - totalLayoutHeight / 2;

    for (final child in nodes) {
      final childLayoutHeight = _subtreeLayoutHeights[child.note.id] ?? nodeHeight;
      final childHeight = _nodeSizes[child.note.id]?.height ?? nodeHeight;
      final childWidth = _nodeSizes[child.note.id]?.width ?? nodeWidth;

      final childY = currentY + (childLayoutHeight - childHeight) / 2;
      final childX = isRight ? origin.dx + childWidth / 2 : origin.dx - childWidth / 2;

      _layoutSubtreeSingle(child, Offset(childX, childY), positions, isRight);
      currentY += childLayoutHeight + verticalSpacing;
    }
  }

  /// 单侧布局坐标计算 (自顶向下递归)
  double _layoutSubtreeSingle(
    NoteTreeNode node,
    Offset origin,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    positions[node.note.id] = origin;

    // 如果是嵌套容器卡片，将其子节点布局在内部
    if (node.note.highlightStyle == 'nestedCard') {
      _layoutNestedCardChildren(node, origin, positions, isRight);
      return _nodeSizes[node.note.id]?.height ?? nodeHeight;
    }

    if (node.children.isEmpty || node.note.isCollapsed) {
      return _nodeSizes[node.note.id]?.height ?? nodeHeight;
    }

    final parentSize = _nodeSizes[node.note.id] ?? Size(nodeWidth, nodeHeight);
    final centerY = origin.dy + parentSize.height / 2;

    double childrenTotalLayoutHeight = 0;
    for (final child in node.children) {
      childrenTotalLayoutHeight += (_subtreeLayoutHeights[child.note.id] ?? nodeHeight) + verticalSpacing;
    }
    childrenTotalLayoutHeight -= verticalSpacing;

    double currentY = centerY - childrenTotalLayoutHeight / 2;

    for (final child in node.children) {
      final childLayoutHeight = _subtreeLayoutHeights[child.note.id] ?? nodeHeight;
      final childHeight = _nodeSizes[child.note.id]?.height ?? nodeHeight;
      final childWidth = _nodeSizes[child.note.id]?.width ?? nodeWidth;

      final childY = currentY + (childLayoutHeight - childHeight) / 2;
      final childX = isRight
          ? origin.dx + parentSize.width / 2 + horizontalSpacing + childWidth / 2
          : origin.dx - parentSize.width / 2 - horizontalSpacing - childWidth / 2;

      _layoutSubtreeSingle(child, Offset(childX, childY), positions, isRight);
      currentY += childLayoutHeight + verticalSpacing;
    }

    return _subtreeLayoutHeights[node.note.id] ?? parentSize.height;
  }

  /// 嵌套卡片内部子卡片紧凑排布
  void _layoutNestedCardChildren(
    NoteTreeNode node,
    Offset origin,
    Map<String, Offset> positions,
    bool isRight,
  ) {
    final containerTop = origin.dy;

    double currentY = containerTop + nodeHeight + 16;

    for (final child in node.children) {
      final childHeight = _nodeSizes[child.note.id]?.height ?? nodeHeight;

      // 水平居中于容器内
      // 子节点中心与容器中心对齐
      final childX = origin.dx;
      final childY = currentY + childHeight / 2;  // currentY 是子节点顶部，中心需要 + childHeight/2

      _layoutSubtreeSingle(child, Offset(childX, childY), positions, isRight);
      currentY += childHeight + 12;
    }
  }

  /// 计算树的连线
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

        // 连线锚点连接到节点边缘中心点
        // parentPos/childPos 是节点顶部中心坐标（Y 是顶部，不是中心）
        // 需要加上 height/2 得到节点中心 Y，再加 width/2 或减 width/2 得到边缘锚点
        final isRightSide = childPos.dx > parentPos.dx;

        // 节点中心 Y = top + height / 2
        final parentCenterY = parentPos.dy + parentSize.height / 2;
        final childCenterY = childPos.dy + childSize.height / 2;

        Offset start, end;
        if (isRightSide) {
          // 子节点在右侧：从父节点右边缘中心连到子节点左边缘中心
          start = Offset(parentPos.dx + parentSize.width / 2, parentCenterY);
          end = Offset(childPos.dx - childSize.width / 2, childCenterY);
        } else {
          // 子节点在左侧：从父节点左边缘中心连到子节点右边缘中心
          start = Offset(parentPos.dx - parentSize.width / 2, parentCenterY);
          end = Offset(childPos.dx + childSize.width / 2, childCenterY);
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
      final pos = entry.value;
      final size = _nodeSizes[id] ?? Size(nodeWidth, nodeHeight);

      minX = pos.dx - size.width / 2 < minX ? pos.dx - size.width / 2 : minX;
      maxX = pos.dx + size.width / 2 > maxX ? pos.dx + size.width / 2 : maxX;
      minY = pos.dy < minY ? pos.dy : minY;
      maxY = pos.dy + size.height > maxY ? pos.dy + size.height : maxY;
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