// lib/src/mindmap/ui/canvas_painter.dart

import 'package:flutter/material.dart';
import 'tree_layout.dart';

/// MindMap canvas painter.
///
/// Draws connections between nodes using bezier curves.
/// Supports multiple connection styles: straight, bezier, stepped.
class MindMapCanvasPainter extends CustomPainter {
  /// Connection data
  final List<Connection> connections;

  /// Line color
  final Color lineColor;

  /// Line width
  final double lineWidth;

  /// Connection style
  final ConnectionStyle connectionStyle;

  /// Show grid background
  final bool showGrid;

  /// Grid cell size
  final double gridSize;

  /// Grid line color
  final Color gridColor;

  MindMapCanvasPainter({
    required this.connections,
    this.lineColor = Colors.grey,
    this.lineWidth = 2.0,
    this.connectionStyle = ConnectionStyle.bezier,
    this.showGrid = false,
    this.gridSize = 40.0,
    this.gridColor = const Color(0x05FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
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

    if (connections.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final conn in connections) {
      final path = _createPath(conn);
      canvas.drawPath(path, paint);
    }
  }

  /// Create connection path
  Path _createPath(Connection conn) {
    switch (connectionStyle) {
      case ConnectionStyle.straight:
        return _createStraightPath(conn);
      case ConnectionStyle.bezier:
        return _createBezierPath(conn);
      case ConnectionStyle.stepped:
        return _createSteppedPath(conn);
    }
  }

  /// Straight line path
  Path _createStraightPath(Connection conn) {
    return Path()
      ..moveTo(conn.start.dx, conn.start.dy)
      ..lineTo(conn.end.dx, conn.end.dy);
  }

  /// Bezier curve path (improved)
  ///
  /// Uses cubic bezier curve with control points positioned based on
  /// connection direction. Inspired by wanglin-mindmap implementation.
  Path _createBezierPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // Determine connection direction
    final dx = conn.end.dx - conn.start.dx;
    final dy = conn.end.dy - conn.start.dy;
    final isHorizontal = dx.abs() > dy.abs();

    if (isHorizontal) {
      // Horizontal direction: control points on horizontal axis
      final midX = (conn.start.dx + conn.end.dx) / 2;
      path.cubicTo(
        midX, conn.start.dy,
        midX, conn.end.dy,
        conn.end.dx, conn.end.dy,
      );
    } else {
      // Vertical direction: control points on vertical axis
      final midY = (conn.start.dy + conn.end.dy) / 2;
      path.cubicTo(
        conn.start.dx, midY,
        conn.end.dx, midY,
        conn.end.dx, conn.end.dy,
      );
    }

    return path;
  }

  /// Stepped path (orthogonal connection)
  Path _createSteppedPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // Horizontal step midpoint
    final midX = (conn.start.dx + conn.end.dx) / 2;

    path.lineTo(midX, conn.start.dy);
    path.lineTo(midX, conn.end.dy);
    path.lineTo(conn.end.dx, conn.end.dy);

    return path;
  }

  @override
  bool shouldRepaint(covariant MindMapCanvasPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        connectionStyle != oldDelegate.connectionStyle ||
        showGrid != oldDelegate.showGrid ||
        gridSize != oldDelegate.gridSize ||
        gridColor != oldDelegate.gridColor;
  }
}

/// Connection style
enum ConnectionStyle {
  /// Straight line
  straight,

  /// Bezier curve (default)
  bezier,

  /// Stepped line (orthogonal)
  stepped,
}