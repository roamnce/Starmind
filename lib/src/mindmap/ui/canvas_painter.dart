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

  MindMapCanvasPainter({
    required this.connections,
    this.lineColor = Colors.grey,
    this.lineWidth = 2.0,
    this.connectionStyle = ConnectionStyle.bezier,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

  /// Bezier curve path
  ///
  /// Uses cubic bezier curve with control points offset vertically
  Path _createBezierPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // Calculate control points
    final dy = (conn.end.dy - conn.start.dy).abs();
    final controlOffset = dy * 0.5; // Control point offset

    final control1 = Offset(
      conn.start.dx,
      conn.start.dy + controlOffset,
    );
    final control2 = Offset(
      conn.end.dx,
      conn.end.dy - controlOffset,
    );

    path.cubicTo(
      control1.dx, control1.dy,
      control2.dx, control2.dy,
      conn.end.dx, conn.end.dy,
    );

    return path;
  }

  /// Stepped path (orthogonal connection)
  Path _createSteppedPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // Midpoint for the step
    final midY = (conn.start.dy + conn.end.dy) / 2;

    path.lineTo(conn.start.dx, midY);
    path.lineTo(conn.end.dx, midY);
    path.lineTo(conn.end.dx, conn.end.dy);

    return path;
  }

  @override
  bool shouldRepaint(covariant MindMapCanvasPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        connectionStyle != oldDelegate.connectionStyle;
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