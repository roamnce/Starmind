// lib/src/mindmap/utils/mindmap_colors.dart
//
// MindMap 模块颜色常量定义。
// 提取硬编码颜色为常量，便于主题切换和品牌一致性维护。

import 'package:flutter/material.dart';

/// MindMap 模块颜色配置
class MindMapColors {
  MindMapColors._();

  // ============ 主色调 ============
  
  /// 金黄色强调色 - 用于选中状态、边框、图标
  static const Color accent = Color(0xFFC8841A);
  
  /// 强调色半透明变体 - 用于边框（未选中）
  static const Color accentBorder = Color(0x40C8841A);
  
  /// 强调色更淡变体 - 用于边框（未选中框架节点）
  static const Color accentBorderLight = Color(0x25C8841A);
  
  /// 框架节点边框色（同 accentBorderLight）
  static const Color frameworkBorder = Color(0x25C8841A);
  
  /// 强调色选中状态头部背景
  static const Color accentSelectedHeader = Color(0x1CC8841A);
  
  /// 普通节点边框色
  static const Color nodeBorder = Color(0x15FFDC8C);

  // ============ 节点背景 ============
  
  /// 普通节点背景 - 深灰色
  static const Color nodeBackground = Color(0xFF242930);
  
  /// 嵌套卡片/框架节点背景 - 半透明
  static const Color nestedCardBackground = Color(0x0DFFFFFF);

  // ============ 画布背景 ============
  
  /// 画布背景色
  static const Color canvasBackground = Color(0xFF0C0A07);
  
  /// 网格线颜色
  static const Color gridLine = Color(0x05FAD278);

  // ============ 文本颜色 ============
  
  /// 节点标题文本
  static Color nodeTitleText({bool selected = false, bool isNestedCard = false}) =>
      Colors.white.withOpacity((selected || isNestedCard) ? 0.95 : 0.9);
  
  /// 次要文本（如子节点数量）
  static Color secondaryText(Color colorSchemeOnSurfaceVariant) => 
      colorSchemeOnSurfaceVariant;
}
