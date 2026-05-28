import 'package:flutter/material.dart';

/// Model representing a text highlight on a PDF page.
///
/// This is used for rendering highlights in the viewport.
/// Persistent highlights are stored via AnnotationController.
class PdfHighlight {
  final String id;
  final int pageIndex;
  final int startCharIndex;
  final int endCharIndex;
  final Color color;
  final List<Rect> rects; // Bounding boxes in PDF point coordinates
  final String text;

  PdfHighlight({
    required this.id,
    required this.pageIndex,
    required this.startCharIndex,
    required this.endCharIndex,
    required this.color,
    required this.rects,
    required this.text,
  });
}