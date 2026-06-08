import 'package:flutter/material.dart';
import '../../layout/layout_engine.dart';
import '../../layout/tree_layout_engine.dart';
import '../../layout/layout_config.dart';
import '../../layout/layout_result.dart';
import '../../rendering/connection_renderer.dart';
import '../../service/mindmap_service.dart';
import '../tree_layout.dart' show LayoutDirection;

/// 导图线样式
enum LineStyle {
  bezier,
  straight,
  ortho,
}

/// 布局状态与计算。
///
/// 管理布局引擎、布局结果、布局方向等。
/// 深度模块：布局算法复杂度隐藏在接口背后。
class MindMapLayoutController extends ChangeNotifier {
  final LayoutEngine _layoutEngine = const TreeLayoutEngine();

  bool _useNewLayoutEngine = true;
  LayoutDirection _direction = LayoutDirection.bothSides;
  ConnectionStyle _connectionStyle = ConnectionStyle.bezier;
  LineStyle _lineStyle = LineStyle.bezier;
  String _layoutStyle = 'tree'; // 'tree' or 'framework'
  LayoutResult? _cachedResult;

  bool get useNewLayoutEngine => _useNewLayoutEngine;
  LayoutDirection get direction => _direction;
  ConnectionStyle get connectionStyle => _connectionStyle;
  LineStyle get lineStyle => _lineStyle;
  String get layoutStyle => _layoutStyle;
  LayoutResult? get result => _cachedResult;

  /// 设置是否使用新布局引擎
  void setUseNewLayoutEngine(bool value) {
    _useNewLayoutEngine = value;
    notifyListeners();
  }

  /// 设置布局方向
  void setDirection(LayoutDirection value) {
    _direction = value;
    notifyListeners();
  }

  /// 设置连线样式
  void setConnectionStyle(ConnectionStyle value) {
    _connectionStyle = value;
    notifyListeners();
  }

  /// 设置导图线样式
  void setLineStyle(LineStyle value) {
    _lineStyle = value;
    notifyListeners();
  }

  /// 设置布局样式 ('tree' or 'framework')
  void setLayoutStyle(String value) {
    if (value == 'tree' || value == 'framework') {
      _layoutStyle = value;
      notifyListeners();
    }
  }

  /// 清除缓存的布局结果
  void clearCache() {
    _cachedResult = null;
  }

  /// 重新计算布局
  void recalculate(List<NoteTreeNode> noteTree) {
    if (noteTree.isEmpty) {
      _cachedResult = null;
      return;
    }

    if (!_useNewLayoutEngine) return;

    final config = LayoutConfig(
      strategy: _directionToStrategy(_direction),
      nodeWidth: 120.0,
      nodeHeight: 40.0,
      horizontalSpacing: 60.0,
      verticalSpacing: 30.0,
    );

    _cachedResult = _layoutRoots(noteTree, config);
    notifyListeners();
  }

  LayoutResult _layoutRoots(List<NoteTreeNode> roots, LayoutConfig config) {
    if (roots.isEmpty) return LayoutResult.empty;
    if (roots.length == 1) return _layoutEngine.layout(roots.first, config);

    final positions = <String, Offset>{};
    final sizes = <String, Size>{};
    final connections = <ConnectionData>[];
    var nextX = 0.0;
    Rect? mergedBounds;

    for (final root in roots) {
      final result = _layoutEngine.layout(root, config);
      final rootShift = Offset(nextX - result.contentBounds.left, 0);

      for (final entry in result.nodePositions.entries) {
        positions[entry.key] = entry.value + rootShift;
      }
      sizes.addAll(result.nodeSizes);
      connections.addAll(
        result.connections.map((connection) {
          return ConnectionData(
            fromId: connection.fromId,
            toId: connection.toId,
            startPoint: connection.startPoint + rootShift,
            endPoint: connection.endPoint + rootShift,
            fromCenter: connection.fromCenter + rootShift,
            toCenter: connection.toCenter + rootShift,
          );
        }),
      );

      final shiftedBounds = result.contentBounds.shift(rootShift);
      mergedBounds = mergedBounds == null
          ? shiftedBounds
          : mergedBounds.expandToInclude(shiftedBounds);
      nextX = shiftedBounds.right + config.horizontalSpacing;
    }

    return LayoutResult(
      nodePositions: positions,
      nodeSizes: sizes,
      connections: connections,
      contentBounds: mergedBounds ?? Rect.zero,
    );
  }

  LayoutStrategy _directionToStrategy(LayoutDirection direction) {
    switch (direction) {
      case LayoutDirection.bothSides:
        return LayoutStrategy.bothSides;
      case LayoutDirection.horizontal:
      case LayoutDirection.right:
        return LayoutStrategy.rightOnly;
      case LayoutDirection.left:
        return LayoutStrategy.leftOnly;
      case LayoutDirection.vertical:
        return LayoutStrategy.rightOnly;
    }
  }
}
