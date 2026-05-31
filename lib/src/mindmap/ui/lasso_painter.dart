import 'package:flutter/material.dart';

class LassoPainter extends CustomPainter {
  final Rect? selectionRect;

  const LassoPainter({required this.selectionRect});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = selectionRect;
    if (rect == null) return;

    // 1. Fill the inside of the selection rectangle with 5% transparent gold
    final fillPaint = Paint()
      ..color = const Color(0x0DC8841A) // 5% transparent gold (0x0D is 13 out of 255, which is ~5.1%)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // 2. Paint a gold dashed selection rectangle using Color(0xFFC8841A) and stroke width 1.5
    final strokePaint = Paint()
      ..color = const Color(0xFFC8841A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawDashedRect(canvas, rect, strokePaint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;

    // Top border: left to right
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, dashWidth, dashSpace, paint);
    // Right border: top to bottom
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, dashWidth, dashSpace, paint);
    // Bottom border: left to right
    _drawDashedLine(canvas, rect.bottomLeft, rect.bottomRight, dashWidth, dashSpace, paint);
    // Left border: top to bottom
    _drawDashedLine(canvas, rect.topLeft, rect.bottomLeft, dashWidth, dashSpace, paint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double dashWidth,
    double dashSpace,
    Paint paint,
  ) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = (p2 - p1).distance;
    if (distance == 0.0) return;

    final double dashCount = (distance / (dashWidth + dashSpace)).floorToDouble();
    final double stepX = dx / distance;
    final double stepY = dy / distance;

    for (int i = 0; i < dashCount; i++) {
      final double startFraction = i * (dashWidth + dashSpace);
      final double endFraction = startFraction + dashWidth;

      final startOffset = Offset(
        p1.dx + startFraction * stepX,
        p1.dy + startFraction * stepY,
      );
      final endOffset = Offset(
        p1.dx + endFraction * stepX,
        p1.dy + endFraction * stepY,
      );

      canvas.drawLine(startOffset, endOffset, paint);
    }

    // Draw the remaining bit if any
    final double remainingStart = dashCount * (dashWidth + dashSpace);
    if (remainingStart < distance) {
      final startOffset = Offset(
        p1.dx + remainingStart * stepX,
        p1.dy + remainingStart * stepY,
      );
      final double remainingEnd = (remainingStart + dashWidth).clamp(0.0, distance);
      final endOffset = Offset(
        p1.dx + remainingEnd * stepX,
        p1.dy + remainingEnd * stepY,
      );
      canvas.drawLine(startOffset, endOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LassoPainter oldDelegate) {
    return selectionRect != oldDelegate.selectionRect;
  }
}
