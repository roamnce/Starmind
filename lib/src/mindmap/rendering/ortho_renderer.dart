// lib/src/mindmap/rendering/ortho_renderer.dart

import 'dart:ui';
import 'connection_renderer.dart';
import 'connection_data.dart';

/// 正交连线渲染器
class OrthoConnectionRenderer implements ConnectionRenderer {
  @override
  String get name => 'Ortho';

  @override
  void render(Canvas canvas, ConnectionData conn, ConnectionPaintConfig config) {
    final paint = Paint()
      ..color = config.color
      ..strokeWidth = config.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = createPath(conn);
    canvas.drawPath(path, paint);
  }

  @override
  Path createPath(ConnectionData conn) {
    final path = Path();
    path.moveTo(conn.startPoint.dx, conn.startPoint.dy);

    final midX = (conn.startPoint.dx + conn.endPoint.dx) / 2;

    path.lineTo(midX, conn.startPoint.dy);
    path.lineTo(midX, conn.endPoint.dy);
    path.lineTo(conn.endPoint.dx, conn.endPoint.dy);

    return path;
  }
}
