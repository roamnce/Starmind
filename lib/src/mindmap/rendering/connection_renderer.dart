// lib/src/mindmap/rendering/connection_renderer.dart

import 'dart:ui';
import 'connection_data.dart';

/// 连线样式
enum ConnectionStyle {
  /// 贝塞尔曲线（默认）
  bezier,

  /// 直线
  straight,

  /// 正交折线
  ortho,
}

/// 连线绘制配置
class ConnectionPaintConfig {
  /// 线条颜色
  final Color color;

  /// 线条宽度
  final double width;

  /// 是否使用彩虹色
  final bool isRainbow;

  /// 彩虹色渐变颜色列表
  final List<Color>? gradientColors;

  const ConnectionPaintConfig({
    this.color = const Color(0xFFC8841A),
    this.width = 2.0,
    this.isRainbow = false,
    this.gradientColors,
  });

  /// 默认配置
  static const ConnectionPaintConfig defaultConfig = ConnectionPaintConfig();
}

/// 连线渲染器接口
///
/// 定义连线绘制的抽象接口，支持不同的连线样式
abstract class ConnectionRenderer {
  /// 渲染连线到画布
  ///
  /// [canvas] 画布
  /// [conn] 连线数据
  /// [config] 绘制配置
  void render(Canvas canvas, ConnectionData conn, ConnectionPaintConfig config);

  /// 创建连线路径（用于测试和调试）
  ///
  /// [conn] 连线数据
  /// 返回 Path 对象
  Path createPath(ConnectionData conn);

  /// 获取渲染器名称
  String get name;
}
