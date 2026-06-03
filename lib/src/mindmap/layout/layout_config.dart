// lib/src/mindmap/layout/layout_config.dart

import 'dart:ui';

/// 布局策略
enum LayoutStrategy {
  /// 两侧布局（根在中央，子在左右两侧）
  bothSides,
  /// 右侧布局（根在左，子在右）
  rightOnly,
  /// 左侧布局（根在右，子在左）
  leftOnly,
  /// 鱼骨图布局
  fishbone,
}

/// 布局配置
class LayoutConfig {
  /// 布局策略
  final LayoutStrategy strategy;

  /// 默认节点宽度
  final double nodeWidth;

  /// 默认节点高度
  final double nodeHeight;

  /// 水平间距
  final double horizontalSpacing;

  /// 垂直间距
  final double verticalSpacing;

  /// 自定义节点尺寸（可选）
  final Map<String, Size>? customNodeSizes;

  const LayoutConfig({
    this.strategy = LayoutStrategy.bothSides,
    this.nodeWidth = 120.0,
    this.nodeHeight = 40.0,
    this.horizontalSpacing = 60.0,
    this.verticalSpacing = 30.0,
    this.customNodeSizes,
  });

  /// 默认配置
  static const LayoutConfig defaultConfig = LayoutConfig();

  /// 获取节点尺寸
  Size getNodeSize(String nodeId) {
    return customNodeSizes?[nodeId] ?? Size(nodeWidth, nodeHeight);
  }

  /// 复制并修改
  LayoutConfig copyWith({
    LayoutStrategy? strategy,
    double? nodeWidth,
    double? nodeHeight,
    double? horizontalSpacing,
    double? verticalSpacing,
    Map<String, Size>? customNodeSizes,
  }) {
    return LayoutConfig(
      strategy: strategy ?? this.strategy,
      nodeWidth: nodeWidth ?? this.nodeWidth,
      nodeHeight: nodeHeight ?? this.nodeHeight,
      horizontalSpacing: horizontalSpacing ?? this.horizontalSpacing,
      verticalSpacing: verticalSpacing ?? this.verticalSpacing,
      customNodeSizes: customNodeSizes ?? this.customNodeSizes,
    );
  }
}