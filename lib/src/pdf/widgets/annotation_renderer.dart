/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/pdf/widgets/strike_out_renderer.dart';

/// Renders all annotation types on a PDF page.
///
/// Annotation types:
/// - Highlight: semi-transparent fill
/// - Underline: solid line at bottom of text
/// - Wave: zigzag pattern at bottom of text
/// - Ink: stroke paths
/// - Note: icon + optional content preview
class AnnotationRenderer extends CustomPainter {
  final List<Annotation> annotations;
  final double scale; // Static baseScale of the page layout
  final double pdfWidth;
  final double pdfHeight;

  AnnotationRenderer({
    required this.annotations,
    required this.scale,
    required this.pdfWidth,
    required this.pdfHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      switch (annotation.type) {
        case AnnotationType.highlight:
          _paintHighlight(canvas, annotation);
        case AnnotationType.underline:
          _paintUnderline(canvas, annotation);
        case AnnotationType.strikeOut:
          _paintStrikeOut(canvas, annotation);
        case AnnotationType.wave:
          _paintWave(canvas, annotation);
        case AnnotationType.ink:
          _paintInk(canvas, annotation);
        case AnnotationType.note:
          _paintNote(canvas, annotation);
      }
    }
  }

  void _paintHighlight(Canvas canvas, Annotation annotation) {
    if (annotation.rects == null) return;

    final color = _parseColor(annotation.colorHex);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final rect in annotation.rects!) {
      final screenRect = _pdfRectToScreen(rect);
      canvas.drawRect(screenRect, paint);
    }
  }

  void _paintUnderline(Canvas canvas, Annotation annotation) {
    if (annotation.rects == null) return;

    final color = _parseColor(annotation.colorHex);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round;

    for (final rect in annotation.rects!) {
      final screenRect = _pdfRectToScreen(rect);
      // Draw line at bottom of rect
      canvas.drawLine(
        Offset(screenRect.left, screenRect.bottom),
        Offset(screenRect.right, screenRect.bottom),
        paint,
      );
    }
  }

  void _paintStrikeOut(Canvas canvas, Annotation annotation) {
    if (annotation.rects == null) return;

    final color = _parseColor(annotation.colorHex);
    final strokeWidth = 2.0 * scale;

    // Convert PDF rects to screen rects
    final screenRects = annotation.rects!.map(_pdfRectToScreen).toList();

    StrikeOutRenderer.draw(canvas, screenRects, color, strokeWidth);
  }

  void _paintWave(Canvas canvas, Annotation annotation) {
    if (annotation.rects == null) return;

    final color = _parseColor(annotation.colorHex);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;

    for (final rect in annotation.rects!) {
      final screenRect = _pdfRectToScreen(rect);
      final path = _createWavePath(screenRect);
      canvas.drawPath(path, paint);
    }
  }

  Path _createWavePath(Rect rect) {
    final path = Path();
    final y = rect.bottom;
    final amplitude = 3.0 * scale;
    final frequency = 8.0 * scale;

    path.moveTo(rect.left, y);

    var x = rect.left;
    while (x < rect.right) {
      final nextX = min(x + frequency, rect.right);
      final midX = (x + nextX) / 2;

      path.quadraticBezierTo(
        midX, y - amplitude,
        nextX, y,
      );

      x = nextX;
    }

    return path;
  }

  void _paintInk(Canvas canvas, Annotation annotation) {
    if (annotation.strokes == null) return;

    for (final stroke in annotation.strokes!) {
      _drawInkStroke(canvas, stroke);
    }
  }

  void _drawInkStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = Color(stroke.color)
      ..strokeWidth = stroke.strokeWidth * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = _pdfToScreen(Offset(stroke.points.first.x, stroke.points.first.y));
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < stroke.points.length; i++) {
      final point = stroke.points[i];
      final screen = _pdfToScreen(Offset(point.x, point.y));
      path.lineTo(screen.dx, screen.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _paintNote(Canvas canvas, Annotation annotation) {
    if (annotation.noteRect == null) return;

    final color = _parseColor(annotation.colorHex);
    final screenRect = _pdfRectToScreen(annotation.noteRect!);

    // Draw note icon (small circle with text indicator)
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final iconCenter = Offset(screenRect.left, screenRect.top);
    final iconRadius = 10.0 * scale;

    canvas.drawCircle(iconCenter, iconRadius, iconPaint);

    // Draw text "📝" indicator
    final textPainter = TextPainter(
      text: TextSpan(
        text: '📝',
        style: TextStyle(fontSize: 12 * scale),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, iconCenter - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  /// Convert PDF rect to screen coordinates.
  Rect _pdfRectToScreen(AnnotationRect rect) {
    final left = rect.left * scale;
    final right = rect.right * scale;
    final top = (pdfHeight - rect.bottom) * scale;
    final bottom = (pdfHeight - rect.top) * scale;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Convert PDF offset to screen coordinates.
  Offset _pdfToScreen(Offset pdfPos) {
    final screenX = pdfPos.dx * scale;
    final screenY = (pdfHeight - pdfPos.dy) * scale;
    return Offset(screenX, screenY);
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  bool shouldRepaint(covariant AnnotationRenderer oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.scale != scale ||
        oldDelegate.pdfWidth != pdfWidth ||
        oldDelegate.pdfHeight != pdfHeight;
  }
}