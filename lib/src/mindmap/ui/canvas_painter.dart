// lib/src/mindmap/ui/canvas_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../layout/layout_result.dart';
import '../rendering/connection_renderer.dart';
import '../rendering/bezier_renderer.dart';
import '../rendering/straight_renderer.dart';
import '../rendering/ortho_renderer.dart';
import 'mindmap_controller.dart' show LineStyle;
import 'tree_layout.dart' show Connection;

/// 关联线绘制数据
class AssociativeRelationPaintData {
  final String id;
  final String sourceId;
  final String targetId;
  final Offset startPoint;
  final Offset endPoint;
  final Offset labelCenter;
  final String text;
  final bool isSelected;

  const AssociativeRelationPaintData({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.startPoint,
    required this.endPoint,
    required this.labelCenter,
    required this.text,
    required this.isSelected,
  });
}

/// 概要括线绘制数据
class SummaryPaintData {
  final String id;
  final String parentId;
  final int startIndex;
  final int endIndex;
  final Offset topPoint;  // 覆盖范围顶部锚点
  final Offset bottomPoint;  // 覆盖范围底部锚点
  final Offset labelPoint;  // 概要标签位置
  final String text;
  final bool isSelected;
  final bool isRightward;  // 括线方向：true=向右，false=向左

  const SummaryPaintData({
    required this.id,
    required this.parentId,
    required this.startIndex,
    required this.endIndex,
    required this.topPoint,
    required this.bottomPoint,
    required this.labelPoint,
    required this.text,
    required this.isSelected,
    this.isRightward = true,
  });
}

/// MindMap canvas painter.
///
/// Draws connections between nodes using pluggable renderers.
/// Supports multiple connection styles: bezier, straight, ortho.
///
/// This painter supports two input modes:
/// 1. Legacy mode: Pass `connections` list (old Connection objects)
/// 2. New mode: Pass `layoutResult` (new LayoutResult with ConnectionData)
class MindMapCanvasPainter extends CustomPainter {
  /// Layout result containing connections (new architecture)
  final LayoutResult? layoutResult;

  /// Legacy connections list (backward compatibility)
  final List<Connection>? connections;

  /// 关联线数据
  final List<AssociativeRelationPaintData> associativeRelations;

  /// 概要括线数据
  final List<SummaryPaintData> summaries;

  /// Connection style (from rendering module)
  final ConnectionStyle? connectionStyle;

  /// Line style (from controller - for backward compatibility)
  final LineStyle? lineStyle;

  /// Line color
  final Color lineColor;

  /// Line width
  final double lineWidth;

  /// Show grid background
  final bool showGrid;

  /// Grid cell size
  final double gridSize;

  /// Grid line color
  final Color gridColor;

  /// Rainbow branch colors
  final bool isRainbowBranch;

  /// Layout direction (for summary bracket direction)
  final String? layoutDirection;

  /// Renderer cache
  final Map<ConnectionStyle, ConnectionRenderer> _renderers = {};

  MindMapCanvasPainter({
    this.layoutResult,
    this.connections,
    this.associativeRelations = const [],
    this.summaries = const [],
    this.connectionStyle,
    this.lineStyle,
    this.lineColor = const Color(0xFFC8841A),
    this.lineWidth = 2.0,
    this.showGrid = false,
    this.gridSize = 40.0,
    this.gridColor = const Color(0x05FFFFFF),
    this.isRainbowBranch = false,
    this.layoutDirection,
  }) {
    _renderers[ConnectionStyle.bezier] = BezierConnectionRenderer();
    _renderers[ConnectionStyle.straight] = StraightConnectionRenderer();
    _renderers[ConnectionStyle.ortho] = OrthoConnectionRenderer();
  }

  /// Get effective connection style from either connectionStyle or lineStyle
  ConnectionStyle get _effectiveStyle {
    if (connectionStyle != null) return connectionStyle!;
    if (lineStyle != null) {
      switch (lineStyle!) {
        case LineStyle.bezier:
          return ConnectionStyle.bezier;
        case LineStyle.straight:
          return ConnectionStyle.straight;
        case LineStyle.ortho:
          return ConnectionStyle.ortho;
      }
    }
    return ConnectionStyle.bezier;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid background
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Get current renderer
    final renderer = _renderers[_effectiveStyle] ?? BezierConnectionRenderer();

    // Draw all connections
    if (layoutResult != null) {
      // New architecture: use ConnectionData
      for (int i = 0; i < layoutResult!.connections.length; i++) {
        final conn = layoutResult!.connections[i];
        final config = ConnectionPaintConfig(
          color: _getConnectionColor(i),
          width: lineWidth,
          isRainbow: isRainbowBranch,
        );
        renderer.render(canvas, conn, config);
      }
    } else if (connections != null && connections!.isNotEmpty) {
      // Legacy mode: convert old Connection to ConnectionData
      for (int i = 0; i < connections!.length; i++) {
        final conn = connections![i];
        final connData = ConnectionData(
          fromId: conn.fromId,
          toId: conn.toId,
          startPoint: conn.start,
          endPoint: conn.end,
          fromCenter: conn.start,
          toCenter: conn.end,
        );
        final config = ConnectionPaintConfig(
          color: _getConnectionColor(i),
          width: lineWidth,
          isRainbow: isRainbowBranch,
        );
        renderer.render(canvas, connData, config);
      }
    }

    // 绘制关联线
    for (final relation in associativeRelations) {
      _drawAssociativeLine(canvas, relation);
    }

    // 绘制概要括线
    for (final summary in summaries) {
      _drawSummaryBracket(canvas, summary);
    }
  }

  /// 绘制关联线（带箭头）
  void _drawAssociativeLine(Canvas canvas, AssociativeRelationPaintData data) {
    final paint = Paint()
      ..color = data.isSelected
          ? const Color(0xFFE8A83C)
          : const Color(0xFF8B7355)
      ..strokeWidth = data.isSelected ? 2.5 : 1.8
      ..style = PaintingStyle.stroke;

    // 绘制贝塞尔曲线
    final path = Path();
    final start = data.startPoint;
    final end = data.endPoint;
    final midX = (start.dx + end.dx) / 2;

    path.moveTo(start.dx, start.dy);
    path.cubicTo(
      midX, start.dy,
      midX, end.dy,
      end.dx, end.dy,
    );
    canvas.drawPath(path, paint);

    // 绘制箭头
    _drawArrowHead(canvas, end, start, paint);

    // 选中时绘制控制点
    if (data.isSelected) {
      final controlPaint = Paint()
        ..color = const Color(0xFFE8A83C)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(start, 4, controlPaint);
      canvas.drawCircle(end, 4, controlPaint);
    }
  }

  /// 绘制箭头
  void _drawArrowHead(Canvas canvas, Offset tip, Offset from, Paint paint) {
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    const arrowAngle = math.pi / 6;
    const arrowLength = 10.0;

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - arrowLength * math.cos(angle - arrowAngle),
      tip.dy - arrowLength * math.sin(angle - arrowAngle),
    );
    path.lineTo(
      tip.dx - arrowLength * math.cos(angle + arrowAngle),
      tip.dy - arrowLength * math.sin(angle + arrowAngle),
    );
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  /// 绘制概要括线（直角折线）
  ///
  /// 根据布局方向确定括线方向：
  /// - right: 括线在右侧，向右延伸
  /// - left: 括线在左侧，向左延伸
  /// - both: 根据节点位置判断
  void _drawSummaryBracket(Canvas canvas, SummaryPaintData data) {
    final paint = Paint()
      ..color = data.isSelected
          ? const Color(0xFFE8A83C)
          : const Color(0xFF8B7355)
      ..strokeWidth = data.isSelected ? 2.5 : 1.8
      ..style = PaintingStyle.stroke;

    final top = data.topPoint;
    final bottom = data.bottomPoint;
    final label = data.labelPoint;

    // 使用概要数据中的方向（已根据子节点位置计算）
    final isRightward = data.isRightward;

    // 计算括线的水平延伸距离
    const bracketExtension = 20.0;

    final path = Path();

    if (isRightward) {
      // 向右延伸的括线
      // 从顶部向下
      path.moveTo(top.dx, top.dy);
      path.lineTo(top.dx + bracketExtension, top.dy);
      path.lineTo(top.dx + bracketExtension, bottom.dy);
      path.lineTo(bottom.dx, bottom.dy);

      // 连接到标签
      path.moveTo(top.dx + bracketExtension, (top.dy + bottom.dy) / 2);
      path.lineTo(label.dx, label.dy);
    } else {
      // 向左延伸的括线
      path.moveTo(top.dx, top.dy);
      path.lineTo(top.dx - bracketExtension, top.dy);
      path.lineTo(top.dx - bracketExtension, bottom.dy);
      path.lineTo(bottom.dx, bottom.dy);

      // 连接到标签
      path.moveTo(top.dx - bracketExtension, (top.dy + bottom.dy) / 2);
      path.lineTo(label.dx, label.dy);
    }

    canvas.drawPath(path, paint);

    // 绘制概要文本背景
    final textPainter = TextPainter(
      text: TextSpan(
        text: data.text,
        style: TextStyle(
          color: data.isSelected ? const Color(0xFFE8A83C) : const Color(0xFF8B7355),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 绘制文本背景
    final textRect = Rect.fromCenter(
      center: label,
      width: textPainter.width + 12,
      height: textPainter.height + 6,
    );
    final bgPaint = Paint()
      ..color = const Color(0xFF1C1710)
      ..style = PaintingStyle.fill;
    final bgRRect = RRect.fromRectAndRadius(textRect, const Radius.circular(4));
    canvas.drawRRect(bgRRect, bgPaint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = data.isSelected
          ? const Color(0xFFE8A83C)
          : const Color(0x33FFDC8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(bgRRect, borderPaint);

    // 绘制文本
    textPainter.paint(
      canvas,
      Offset(label.dx - textPainter.width / 2, label.dy - textPainter.height / 2),
    );
  }

  /// Draw grid background
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  /// Get connection color (supports rainbow colors)
  Color _getConnectionColor(int index) {
    if (!isRainbowBranch) return lineColor;

    const rainbowColors = [
      Color(0xFFFF6B6B),
      Color(0xFFFF9F43),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
      Color(0xFF9B59B6),
    ];

    return rainbowColors[index % rainbowColors.length];
  }

  @override
  bool shouldRepaint(covariant MindMapCanvasPainter oldDelegate) {
    // Compare layoutResult
    if (layoutResult != null && oldDelegate.layoutResult != null) {
      if (layoutResult!.connections.length != oldDelegate.layoutResult!.connections.length) {
        return true;
      }
    }

    // Compare connections list
    if (connections != null && oldDelegate.connections != null) {
      if (connections!.length != oldDelegate.connections!.length) {
        return true;
      }
    }

    // Compare associative relations
    if (associativeRelations.length != oldDelegate.associativeRelations.length) {
      return true;
    }
    for (int i = 0; i < associativeRelations.length; i++) {
      if (associativeRelations[i].isSelected != oldDelegate.associativeRelations[i].isSelected ||
          associativeRelations[i].text != oldDelegate.associativeRelations[i].text) {
        return true;
      }
    }

    // Compare summaries
    if (summaries.length != oldDelegate.summaries.length) {
      return true;
    }
    for (int i = 0; i < summaries.length; i++) {
      if (summaries[i].isSelected != oldDelegate.summaries[i].isSelected ||
          summaries[i].text != oldDelegate.summaries[i].text ||
          summaries[i].startIndex != oldDelegate.summaries[i].startIndex ||
          summaries[i].endIndex != oldDelegate.summaries[i].endIndex) {
        return true;
      }
    }

    return layoutResult != oldDelegate.layoutResult ||
        connections != oldDelegate.connections ||
        connectionStyle != oldDelegate.connectionStyle ||
        lineStyle != oldDelegate.lineStyle ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        showGrid != oldDelegate.showGrid ||
        gridSize != oldDelegate.gridSize ||
        gridColor != oldDelegate.gridColor ||
        isRainbowBranch != oldDelegate.isRainbowBranch ||
        layoutDirection != oldDelegate.layoutDirection;
  }
}
