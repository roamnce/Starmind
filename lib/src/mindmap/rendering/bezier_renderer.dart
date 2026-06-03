// lib/src/mindmap/rendering/bezier_renderer.dart

import 'dart:ui';
import 'connection_renderer.dart';
import 'connection_data.dart';

/// 贝塞尔连线渲染器
class BezierConnectionRenderer implements ConnectionRenderer {
  @override
  String get name => 'Bezier';

  @override
  void render(Canvas canvas, ConnectionData conn, ConnectionPaintConfig config) {
    final paint = Paint()
      ..color = config.color
      ..strokeWidth = config.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = createPath(conn);
    canvas.drawPath(path, paint);
  }

  @override
  Path createPath(ConnectionData conn) {
    final path = Path();
    path.moveTo(conn.startPoint.dx, conn.startPoint.dy);

    final dx = (conn.endPoint.dx - conn.startPoint.dx).abs();
    final controlOffset = dx * 0.5;

    if (conn.isRightward) {
      path.cubicTo(
        conn.startPoint.dx + controlOffset, conn.startPoint.dy,
        conn.endPoint.dx - controlOffset, conn.endPoint.dy,
        conn.endPoint.dx, conn.endPoint.dy,
      );
    } else {
      path.cubicTo(
        conn.startPoint.dx - controlOffset, conn.startPoint.dy,
        conn.endPoint.dx + controlOffset, conn.endPoint.dy,
        conn.endPoint.dx, conn.endPoint.dy,
      );
    }

    return path;
  }
}
