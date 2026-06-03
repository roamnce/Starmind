// lib/src/mindmap/ui/canvas_painter.dart

import 'package:flutter/material.dart';
import '../layout/layout_result.dart';
import '../rendering/connection_renderer.dart';
import '../rendering/bezier_renderer.dart';
import '../rendering/straight_renderer.dart';
import '../rendering/ortho_renderer.dart';
import 'mindmap_controller.dart' show LineStyle;
import 'tree_layout.dart' show Connection;

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

  /// Renderer cache
  final Map<ConnectionStyle, ConnectionRenderer> _renderers = {};

  MindMapCanvasPainter({
    this.layoutResult,
    this.connections,
    this.connectionStyle,
    this.lineStyle,
    this.lineColor = const Color(0xFFC8841A),
    this.lineWidth = 2.0,
    this.showGrid = false,
    this.gridSize = 40.0,
    this.gridColor = const Color(0x05FFFFFF),
    this.isRainbowBranch = false,
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

    return layoutResult != oldDelegate.layoutResult ||
        connections != oldDelegate.connections ||
        connectionStyle != oldDelegate.connectionStyle ||
        lineStyle != oldDelegate.lineStyle ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        showGrid != oldDelegate.showGrid ||
        gridSize != oldDelegate.gridSize ||
        gridColor != oldDelegate.gridColor ||
        isRainbowBranch != oldDelegate.isRainbowBranch;
  }
}
