// lib/src/mindmap/rendering/straight_renderer.dart

import 'dart:ui';
import 'connection_renderer.dart';
import 'connection_data.dart';

/// 直线连线渲染器
class StraightConnectionRenderer implements ConnectionRenderer {
  @override
  String get name => 'Straight';

  @override
  void render(Canvas canvas, ConnectionData conn, ConnectionPaintConfig config) {
    final paint = Paint()
      ..color = config.color
      ..strokeWidth = config.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(conn.startPoint, conn.endPoint, paint);
  }

  @override
  Path createPath(ConnectionData conn) {
    final path = Path();
    path.moveTo(conn.startPoint.dx, conn.startPoint.dy);
    path.lineTo(conn.endPoint.dx, conn.endPoint.dy);
    return path;
  }
}
