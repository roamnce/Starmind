// lib/src/mindmap/layout/tree_layout_engine.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'layout_engine.dart';
import 'layout_config.dart';
import 'layout_result.dart';
import 'anchor_calculator.dart';
import '../service/mindmap_service.dart';

/// 树形布局引擎
///
/// 基于现有 TreeLayout 算法重构，支持：
/// - 两侧布局（bothSides）
/// - 右侧布局（rightOnly）
/// - 左侧布局（leftOnly）
class TreeLayoutEngine implements LayoutEngine {
  const TreeLayoutEngine();

  @override
  LayoutResult layout(NoteTreeNode root, LayoutConfig config) {
    final nodePositions = <String, Offset>{};
    final nodeSizes = <String, Size>{};

    // 1. 计算所有节点尺寸
    _calculateNodeSizes(root, config, nodeSizes);

    // 2. 计算子树高度（用于居中对齐）
    final subtreeHeights = <String, double>{};
    _calculateSubtreeHeights(root, config, nodeSizes, subtreeHeights);

    // 3. 根据布局策略计算节点位置
    switch (config.strategy) {
      case LayoutStrategy.bothSides:
        _layoutBothSides(root, config, nodeSizes, subtreeHeights, nodePositions);
        break;
      case LayoutStrategy.rightOnly:
        _layoutSingleSide(root, config, nodeSizes, subtreeHeights, nodePositions, true);
        break;
      case LayoutStrategy.leftOnly:
        _layoutSingleSide(root, config, nodeSizes, subtreeHeights, nodePositions, false);
        break;
      case LayoutStrategy.fishbone:
        // 鱼骨图暂不支持，回退到右侧布局
        _layoutSingleSide(root, config, nodeSizes, subtreeHeights, nodePositions, true);
        break;
    }

    // 4. 计算连线
    final connections = _calculateConnections(root, config, nodePositions, nodeSizes);

    // 5. 计算边界框
    final bounds = _calculateContentBounds(nodePositions, nodeSizes);

    return LayoutResult(
      nodePositions: nodePositions,
      nodeSizes: nodeSizes,
      connections: connections,
      contentBounds: bounds,
    );
  }

  /// 计算节点尺寸
  void _calculateNodeSizes(
    NoteTreeNode node,
    LayoutConfig config,
    Map<String, Size> nodeSizes,
  ) {
    nodeSizes[node.note.id] = config.getNodeSize(node.note.id);
    for (final child in node.children) {
      _calculateNodeSizes(child, config, nodeSizes);
    }
  }

  /// 计算子树高度（用于垂直居中对齐）
  double _calculateSubtreeHeights(
    NoteTreeNode node,
    LayoutConfig config,
    Map<String, Size> nodeSizes,
    Map<String, double> subtreeHeights,
  ) {
    final nodeSize = nodeSizes[node.note.id] ?? Size(config.nodeWidth, config.nodeHeight);
    final selfHeight = nodeSize.height;

    if (node.children.isEmpty || node.note.isCollapsed) {
      subtreeHeights[node.note.id] = selfHeight;
      return selfHeight;
    }

    double childrenHeight = 0;
    for (final child in node.children) {
      childrenHeight += _calculateSubtreeHeights(child, config, nodeSizes, subtreeHeights);
      childrenHeight += config.verticalSpacing;
    }
    childrenHeight -= config.verticalSpacing;

    final totalHeight = max(selfHeight, childrenHeight);
    subtreeHeights[node.note.id] = totalHeight;
    return totalHeight;
  }

  /// 两侧布局
  void _layoutBothSides(
    NoteTreeNode root,
    LayoutConfig config,
    Map<String, Size> nodeSizes,
    Map<String, double> subtreeHeights,
    Map<String, Offset> nodePositions,
  ) {
    final rootSize = nodeSizes[root.note.id] ?? Size(config.nodeWidth, config.nodeHeight);
    nodePositions[root.note.id] = Offset.zero;

    if (root.children.isEmpty) return;

    final leftChildren = <NoteTreeNode>[];
    final rightChildren = <NoteTreeNode>[];

    for (int i = 0; i < root.children.length; i++) {
      if (i % 2 == 0) {
        rightChildren.add(root.children[i]);
      } else {
        leftChildren.add(root.children[i]);
      }
    }

    if (rightChildren.isNotEmpty) {
      final rightStartX = rootSize.width / 2 + config.horizontalSpacing;
      _layoutChildren(rightChildren, Offset(rightStartX, 0), config, nodeSizes, subtreeHeights, nodePositions, true);
    }

    if (leftChildren.isNotEmpty) {
      final leftStartX = -rootSize.width / 2 - config.horizontalSpacing;
      _layoutChildren(leftChildren, Offset(leftStartX, 0), config, nodeSizes, subtreeHeights, nodePositions, false);
    }
  }

  /// 单侧布局
  void _layoutSingleSide(
    NoteTreeNode root,
    LayoutConfig config,
    Map<String, Size> nodeSizes,
    Map<String, double> subtreeHeights,
    Map<String, Offset> nodePositions,
    bool isRight,
  ) {
    final rootSize = nodeSizes[root.note.id] ?? Size(config.nodeWidth, config.nodeHeight);
    nodePositions[root.note.id] = Offset.zero;

    if (root.children.isEmpty) return;

    final startX = isRight
        ? rootSize.width / 2 + config.horizontalSpacing
        : -rootSize.width / 2 - config.horizontalSpacing;

    _layoutChildren(root.children, Offset(startX, 0), config, nodeSizes, subtreeHeights, nodePositions, isRight);
  }

  /// 布局子节点列表
  void _layoutChildren(
    List<NoteTreeNode> children,
    Offset origin,
    LayoutConfig config,
    Map<String, Size> nodeSizes,
    Map<String, double> subtreeHeights,
    Map<String, Offset> nodePositions,
    bool isRight,
  ) {
    if (children.isEmpty) return;

    double totalHeight = 0;
    for (final child in children) {
      totalHeight += subtreeHeights[child.note.id] ?? config.nodeHeight;
      totalHeight += config.verticalSpacing;
    }
    totalHeight -= config.verticalSpacing;

    double currentY = origin.dy - totalHeight / 2;

    for (final child in children) {
      final childSize = nodeSizes[child.note.id] ?? Size(config.nodeWidth, config.nodeHeight);
      final childHeight = subtreeHeights[child.note.id] ?? childSize.height;

      final childCenterY = currentY + childHeight / 2;
      final childCenterX = isRight
          ? origin.dx + childSize.width / 2
          : origin.dx - childSize.width / 2;

      nodePositions[child.note.id] = Offset(childCenterX, childCenterY);

      if (child.children.isNotEmpty && !child.note.isCollapsed) {
        final grandChildStartX = isRight
            ? childCenterX + childSize.width / 2 + config.horizontalSpacing
            : childCenterX - childSize.width / 2 - config.horizontalSpacing;

        _layoutChildren(child.children, Offset(grandChildStartX, childCenterY), config, nodeSizes, subtreeHeights, nodePositions, isRight);
      }

      currentY += childHeight + config.verticalSpacing;
    }
  }

  /// 计算所有连线
  List<ConnectionData> _calculateConnections(
    NoteTreeNode root,
    LayoutConfig config,
    Map<String, Offset> nodePositions,
    Map<String, Size> nodeSizes,
  ) {
    final connections = <ConnectionData>[];
    _collectConnections(root, config, nodePositions, nodeSizes, connections);
    return connections;
  }

  /// 递归收集连线
  void _collectConnections(
    NoteTreeNode node,
    LayoutConfig config,
    Map<String, Offset> nodePositions,
    Map<String, Size> nodeSizes,
    List<ConnectionData> connections,
  ) {
    final parentCenter = nodePositions[node.note.id];
    final parentSize = nodeSizes[node.note.id];
    if (parentCenter == null || parentSize == null) return;

    for (final child in node.children) {
      final childCenter = nodePositions[child.note.id];
      final childSize = nodeSizes[child.note.id];
      if (childCenter == null || childSize == null) continue;

      final (startAnchor, endAnchor) = AnchorCalculator.calculateAnchorPair(
        fromCenter: parentCenter,
        fromSize: parentSize,
        toCenter: childCenter,
        toSize: childSize,
      );

      connections.add(ConnectionData(
        fromId: node.note.id,
        toId: child.note.id,
        startPoint: startAnchor,
        endPoint: endAnchor,
        fromCenter: parentCenter,
        toCenter: childCenter,
      ));

      _collectConnections(child, config, nodePositions, nodeSizes, connections);
    }
  }

  /// 计算内容边界框
  Rect _calculateContentBounds(
    Map<String, Offset> nodePositions,
    Map<String, Size> nodeSizes,
  ) {
    if (nodePositions.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final entry in nodePositions.entries) {
      final id = entry.key;
      final center = entry.value;
      final size = nodeSizes[id] ?? const Size(120, 40);

      final left = center.dx - size.width / 2;
      final right = center.dx + size.width / 2;
      final top = center.dy - size.height / 2;
      final bottom = center.dy + size.height / 2;

      if (left < minX) minX = left;
      if (right > maxX) maxX = right;
      if (top < minY) minY = top;
      if (bottom > maxY) maxY = bottom;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}