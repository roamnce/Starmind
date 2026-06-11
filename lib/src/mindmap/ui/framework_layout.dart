// lib/src/mindmap/ui/framework_layout.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';
import 'tree_layout.dart' show Connection; // 复用 TreeLayout 的 Connection 类

/// 框架式布局算法
///
/// 用于计算 MarginNote 风格的框架容器布局：
/// - 子节点在容器内网格排列
/// - 支持用户自定义位置
/// - 递归嵌套子框架
///
/// **坐标系**：所有坐标均为节点中心坐标（与 TreeLayoutEngine 一致）
class FrameworkLayout {
  /// 框架容器内边距
  final double containerPadding;

  /// 框架内节点间距
  final double nodeSpacing;

  /// 悬挂标题栏高度
  final double headerHeight;

  /// 默认节点宽度
  final double nodeWidth;

  /// 默认节点高度
  final double nodeHeight;

  /// 每行最大列数
  final int maxColumnsPerRow;

  /// 缓存节点尺寸
  final Map<String, Size> _nodeSizes = {};

  FrameworkLayout({
    this.containerPadding = 16.0,
    this.nodeSpacing = 12.0,
    this.headerHeight = 32.0,
    this.nodeWidth = 120.0,
    this.nodeHeight = 40.0,
    this.maxColumnsPerRow = 2,
  });

  /// 获取缓存的节点尺寸
  Map<String, Size> get nodeSizes => _nodeSizes;

  /// 自动计算网格排列
  ///
  /// 规则：
  /// - 子节点数量 <= 2：水平排列（一行）
  /// - 子节点数量 > 2：网格排列，每行最多 2 个
  List<List<NoteTreeNode>> arrangeGrid(List<NoteTreeNode> children) {
    final count = children.length;
    if (count <= 2) {
      return [children];
    }

    final rows = <List<NoteTreeNode>>[];
    for (int i = 0; i < count; i += maxColumnsPerRow) {
      final row = children.sublist(i, min(i + maxColumnsPerRow, count));
      rows.add(row);
    }
    return rows;
  }

  /// 计算所有节点的尺寸（自底向上递归）
  /// isFramework: 表示整个导图是否处于框架式布局模式
  void calculateNodeSizes(NoteTreeNode node, {bool isFramework = true}) {
    if (isFramework) {
      // 框架模式下，所有节点都按框架样式处理
      for (final child in node.children) {
        calculateNodeSizes(child, isFramework: true);
      }
      _nodeSizes[node.note.id] = calculateFrameworkSize(node);
    } else {
      _nodeSizes[node.note.id] = Size(nodeWidth, nodeHeight);
      for (final child in node.children) {
        calculateNodeSizes(child, isFramework: false);
      }
    }
  }

  /// 计算框架尺寸（包含所有子节点）
  Size calculateFrameworkSize(NoteTreeNode node) {
    if (node.children.isEmpty || node.note.isCollapsed) {
      return Size(
        nodeWidth + containerPadding * 2,
        headerHeight + nodeHeight + containerPadding,
      );
    }

    final grid = arrangeGrid(node.children);

    double maxRowWidth = 0;
    double totalHeight = 0;

    for (int r = 0; r < grid.length; r++) {
      final row = grid[r];
      final rowWidth = row.fold(0.0, (sum, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return sum + childSize.width;
      }) + (row.length - 1) * nodeSpacing;
      maxRowWidth = max(maxRowWidth, rowWidth);

      final rowHeight = row.fold(0.0, (maxH, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return max(maxH, childSize.height);
      });
      totalHeight += rowHeight;
      if (r < grid.length - 1) {
        totalHeight += nodeSpacing;
      }
    }

    return Size(
      max(containerPadding * 2 + maxRowWidth, nodeWidth + containerPadding * 2),
      headerHeight + nodeHeight + totalHeight + containerPadding,
    );
  }

  /// 计算框架式节点的子节点位置
  ///
  /// 返回的 positions 是节点中心坐标（与 TreeLayoutEngine 一致）
  Map<String, Offset> calculateChildPositions(
    NoteTreeNode node,
    Offset frameworkCenter,
  ) {
    final positions = <String, Offset>{};

    if (node.children.isEmpty || node.note.isCollapsed) {
      return positions;
    }

    final grid = arrangeGrid(node.children);
    final frameworkSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    // 框架内部起始位置（考虑 padding 和 header）
    // frameworkCenter 是框架中心坐标
    final frameworkTop = frameworkCenter.dy - frameworkSize.height / 2;
    final frameworkLeft = frameworkCenter.dx - frameworkSize.width / 2;
    
    final innerTop = frameworkTop + headerHeight + nodeHeight;
    final innerLeft = frameworkLeft + containerPadding;

    double currentY = innerTop;

    for (final row in grid) {
      double currentX = innerLeft;
      final rowHeight = row.fold(0.0, (maxH, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return max(maxH, childSize.height);
      });

      for (final child in row) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

        // 返回节点中心坐标
        final childCenterX = currentX + childSize.width / 2;
        final childCenterY = currentY + childSize.height / 2;

        positions[child.note.id] = Offset(childCenterX, childCenterY);

        currentX += childSize.width + nodeSpacing;
      }

      currentY += rowHeight + nodeSpacing;
    }

    return positions;
  }

  /// 计算框架式节点及其子节点的所有位置
  /// isFramework: 表示整个导图是否处于框架式布局模式
  Map<String, Offset> calculate(NoteTreeNode node, Offset origin, {bool isFramework = true}) {
    final positions = <String, Offset>{};

    calculateNodeSizes(node, isFramework: isFramework);

    // origin 现在是节点中心坐标
    positions[node.note.id] = origin;

    final childPositions = calculateChildPositions(node, origin);
    positions.addAll(childPositions);

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos != null && isFramework) {
        final subPositions = calculate(child, childPos, isFramework: true);
        positions.addAll(subPositions);
      }
    }

    return positions;
  }

  /// 计算框架内部的连线
  ///
  /// positions 存储的是节点中心坐标
  /// isFramework: 表示整个导图是否处于框架式布局模式
  List<Connection> calculateConnections(
    NoteTreeNode node,
    Map<String, Offset> positions, {
    bool isFramework = true,
  }) {
    final connections = <Connection>[];

    if (!isFramework) {
      return connections;
    }

    final parentCenter = positions[node.note.id];
    if (parentCenter == null) return connections;

    final parentSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    // 父节点连线锚点：标题栏底部中心
    // parentCenter 是框架中心，需要计算标题栏底部的位置
    final anchorY = parentCenter.dy - parentSize.height / 2 + headerHeight + nodeHeight;

    for (final child in node.children) {
      final childCenter = positions[child.note.id];
      if (childCenter == null) continue;

      final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

      // 子节点锚点：顶部中心
      connections.add(Connection(
        fromId: node.note.id,
        toId: child.note.id,
        start: Offset(parentCenter.dx, anchorY),
        end: Offset(childCenter.dx, childCenter.dy - childSize.height / 2),
      ));

      if (isFramework) {
        connections.addAll(calculateConnections(child, positions, isFramework: true));
      }
    }

    return connections;
  }
}
