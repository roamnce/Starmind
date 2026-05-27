/// Strikethrough renderer
///
/// Draws a horizontal line through the middle of each text rect.
library;

import 'dart:ui';
import 'package:flutter/material.dart';

/// Renders strikethrough (strikeOut) annotations on a PDF page.
///
/// A strikethrough draws a horizontal line through the middle of each text rect.
class StrikeOutRenderer {
  /// Draw strikethrough lines on the canvas
  ///
  /// [canvas] - The canvas to draw on
  /// [rects] - The bounding rectangles of the text (in screen coordinates)
  /// [color] - The color of the strikethrough line
  /// [strokeWidth] - The width of the strikethrough line
  static void draw(
    Canvas canvas,
    List<Rect> rects,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final rect in rects) {
      // Draw horizontal line through the middle of the text
      final midY = (rect.top + rect.bottom) / 2;
      canvas.drawLine(
        Offset(rect.left, midY),
        Offset(rect.right, midY),
        paint,
      );
    }
  }
}
