import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';

/// Hit detection for annotations on PDF pages.
///
/// Detects which annotation (if any) is at a given screen position.
/// Uses PDF coordinate system for consistent hit testing across zoom/pan.
class AnnotationHitDetector {
  final PdfViewportController viewportController;

  AnnotationHitDetector({required this.viewportController});

  /// Find annotation at screen position for a specific page.
  ///
  /// Returns null if no annotation is at that position.
  Annotation? hitTest({
    required int pageIndex,
    required Offset screenPosition,
    required List<Annotation> annotations,
    double hitPadding = 8.0,
  }) {
    final pdfSize = viewportController.pageSizes[pageIndex];
    if (pdfSize == null) return null;

    final pdfPos = _screenToPdf(screenPosition, pageIndex, pdfSize);

    // Check annotations in reverse order (top-most first)
    for (int i = annotations.length - 1; i >= 0; i--) {
      final annotation = annotations[i];
      if (_isHit(annotation, pdfPos, hitPadding)) {
        return annotation;
      }
    }

    return null;
  }

  /// Check if PDF position hits the annotation.
  bool _isHit(Annotation annotation, Offset pdfPos, double padding) {
    switch (annotation.type) {
      case AnnotationType.highlight:
      case AnnotationType.underline:
      case AnnotationType.wave:
      case AnnotationType.strikeOut:
        return _hitTestRects(annotation, pdfPos, padding);
      case AnnotationType.ink:
        return _hitTestInk(annotation, pdfPos, padding);
      case AnnotationType.note:
        return _hitTestNote(annotation, pdfPos, padding);
    }
  }

  /// Hit test for rect-based annotations (highlight, underline, wave).
  bool _hitTestRects(Annotation annotation, Offset pdfPos, double padding) {
    if (annotation.rects == null) return false;

    for (final rect in annotation.rects!) {
      final expandedRect = Rect.fromLTRB(
        rect.left - padding,
        rect.top - padding,
        rect.right + padding,
        rect.bottom + padding,
      );
      if (expandedRect.contains(pdfPos)) {
        return true;
      }
    }

    return false;
  }

  /// Hit test for ink annotations.
  bool _hitTestInk(Annotation annotation, Offset pdfPos, double padding) {
    if (annotation.strokes == null) return false;

    for (final stroke in annotation.strokes!) {
      for (final point in stroke.points) {
        final distance = (Offset(point.x, point.y) - pdfPos).distance;
        final effectivePadding = padding + stroke.strokeWidth / 2;
        if (distance <= effectivePadding) {
          return true;
        }
      }
    }

    return false;
  }

  /// Hit test for note annotations.
  bool _hitTestNote(Annotation annotation, Offset pdfPos, double padding) {
    if (annotation.noteRect == null) return false;

    final rect = annotation.noteRect!;
    final expandedRect = Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );

    return expandedRect.contains(pdfPos);
  }

  /// Convert screen position to PDF coordinates.
  Offset _screenToPdf(Offset screenPos, int pageIndex, Size pdfSize) {
    final zoom = viewportController.zoom;
    final panOffset = viewportController.panOffset;

    final pdfX = (screenPos.dx - panOffset.dx * zoom) / zoom;
    final pdfY = pdfSize.height - (screenPos.dy - panOffset.dy * zoom) / zoom;

    return Offset(pdfX, pdfY);
  }
}
