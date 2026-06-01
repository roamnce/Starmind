// lib/src/mindmap/ui/framework_layout.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';
import 'framework_child_position.dart';

/// 框架式布局算法
///
/// 用于计算 MarginNote 风格的框架容器布局：
/// - 子节点在容器内网格排列
/// - 支持用户自定义位置
/// - 递归嵌套子框架
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
  void calculateNodeSizes(NoteTreeNode node) {
    if (node.note.layoutStyle == 'framework') {
      for (final child in node.children) {
        calculateNodeSizes(child);
      }
      _nodeSizes[node.note.id] = calculateFrameworkSize(node);
    } else {
      _nodeSizes[node.note.id] = Size(nodeWidth, nodeHeight);
      for (final child in node.children) {
        calculateNodeSizes(child);
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
  Map<String, Offset> calculateChildPositions(
    NoteTreeNode node,
    Offset frameworkOrigin,
  ) {
    final positions = <String, Offset>{};

    if (node.children.isEmpty || node.note.isCollapsed) {
      return positions;
    }

    final grid = arrangeGrid(node.children);
    final frameworkSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    final innerTop = frameworkOrigin.dy - frameworkSize.height / 2 + headerHeight + nodeHeight;
    final innerLeft = frameworkOrigin.dx - frameworkSize.width / 2 + containerPadding;

    double currentY = innerTop;

    for (final row in grid) {
      double currentX = innerLeft;
      final rowHeight = row.fold(0.0, (maxH, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return max(maxH, childSize.height);
      });

      for (final child in row) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

        final childCenterX = currentX + childSize.width / 2;
        final childCenterY = currentY + rowHeight / 2;

        positions[child.note.id] = Offset(childCenterX, childCenterY);

        currentX += childSize.width + nodeSpacing;
      }

      currentY += rowHeight + nodeSpacing;
    }

    return positions;
  }

  /// 计算框架式节点及其子节点的所有位置
  Map<String, Offset> calculate(NoteTreeNode node, Offset origin) {
    final positions = <String, Offset>{};

    calculateNodeSizes(node);

    positions[node.note.id] = origin;

    final childPositions = calculateChildPositions(node, origin);
    positions.addAll(childPositions);

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos != null && child.note.layoutStyle == 'framework') {
        final subPositions = calculate(child, childPos);
        positions.addAll(subPositions);
      }
    }

    return positions;
  }

  /// 计算框架内部的连线
  List<Connection> calculateConnections(
    NoteTreeNode node,
    Map<String, Offset> positions,
  ) {
    final connections = <Connection>[];

    if (node.note.layoutStyle != 'framework') {
      return connections;
    }

    final parentPos = positions[node.note.id];
    if (parentPos == null) return connections;

    final parentSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    final anchorY = parentPos.dy - parentSize.height / 2 + headerHeight + nodeHeight;

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos == null) continue;

      final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

      connections.add(Connection(
        fromId: node.note.id,
        toId: child.note.id,
        start: Offset(parentPos.dx, anchorY),
        end: Offset(childPos.dx, childPos.dy - childSize.height / 2),
      ));

      if (child.note.layoutStyle == 'framework') {
        connections.addAll(calculateConnections(child, positions));
      }
    }

    return connections;
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
