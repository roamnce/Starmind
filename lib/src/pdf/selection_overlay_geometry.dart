import 'dart:ui';

/// Pure functions for converting PDF selection coordinates to screen space.
///
/// This module handles the coordinate transformation from page-local PDF space
/// to screen space, accounting for:
/// - PDF Y-up to Flutter Y-down conversion
/// - Page position in multi-page vertical layout
/// - Zoom and pan transformations
class SelectionOverlayGeometry {
  /// Converts page-local PDF rectangles to screen coordinates.
  ///
  /// Parameters:
  /// - [pdfRects]: Selection rectangles in page-local PDF coordinates (Y-up)
  /// - [pageIndex]: Zero-based page index in document
  /// - [pdfPageHeight]: Height of the PDF page in PDF points
  /// - [baseScale]: Base scale factor (CSS pixels per PDF point)
  /// - [zoom]: Current zoom level from InteractiveViewer
  /// - [panOffset]: Pan offset from InteractiveViewer (screen space)
  /// - [pageVerticalMargin]: Vertical margin between pages in CSS pixels
  ///
  /// Returns: (centerX, topY, bottomY) in screen coordinates
  static (double, double, double) pdfRectsToScreenBounds({
    required List<Rect> pdfRects,
    required int pageIndex,
    required double pdfPageHeight,
    required double baseScale,
    required double zoom,
    required Offset panOffset,
    required double pageVerticalMargin,
  }) {
    if (pdfRects.isEmpty) return (0, 0, 0);

    // Convert PDF rects to page-local Flutter coordinates (Y-down)
    final pageLocalRects = pdfRects.map((r) {
      return Rect.fromLTRB(
        r.left * baseScale,
        (pdfPageHeight - r.top) * baseScale,    // Y-flip
        r.right * baseScale,
        (pdfPageHeight - r.bottom) * baseScale, // Y-flip
      );
    }).toList();

    // Find bounds in page-local space
    final topRect = pageLocalRects.reduce((a, b) => a.top < b.top ? a : b);
    final bottomRect = pageLocalRects.reduce((a, b) => a.bottom > b.bottom ? a : b);
    final centerX = pageLocalRects.fold<double>(0, (sum, r) => sum + (r.left + r.right) / 2) / pageLocalRects.length;

    // Calculate page vertical offset in Column layout
    // Layout: margin + page0 + margin + margin + page1 + margin + ...
    // Page N starts at: N * (pageHeight + 2*margin) + margin
    final pageHeight = pdfPageHeight * baseScale;
    final pageVerticalOffset = pageIndex * (pageHeight + 2 * pageVerticalMargin) + pageVerticalMargin;

    // Apply zoom to both page-local coordinates and page offset
    final screenCenterX = centerX * zoom + panOffset.dx;
    final screenTopY = topRect.top * zoom + pageVerticalOffset * zoom + panOffset.dy;
    final screenBottomY = bottomRect.bottom * zoom + pageVerticalOffset * zoom + panOffset.dy;

    return (screenCenterX, screenTopY, screenBottomY);
  }

  /// Converts a page-local PDF point to screen coordinates.
  ///
  /// Used for positioning selection handles.
  ///
  /// Parameters:
  /// - [pdfPoint]: Point in page-local PDF coordinates (Y-up)
  /// - [pageIndex]: Zero-based page index in document
  /// - [pdfPageHeight]: Height of the PDF page in PDF points
  /// - [baseScale]: Base scale factor (CSS pixels per PDF point)
  /// - [zoom]: Current zoom level from InteractiveViewer
  /// - [panOffset]: Pan offset from InteractiveViewer (screen space)
  /// - [pageVerticalMargin]: Vertical margin between pages in CSS pixels
  ///
  /// Returns: Screen coordinates (Offset)
  static Offset pdfPointToScreen({
    required Offset pdfPoint,
    required int pageIndex,
    required double pdfPageHeight,
    required double baseScale,
    required double zoom,
    required Offset panOffset,
    required double pageVerticalMargin,
  }) {
    // Convert to page-local Flutter coordinates
    final pageLocalX = pdfPoint.dx * baseScale;
    final pageLocalY = (pdfPageHeight - pdfPoint.dy) * baseScale; // Y-flip

    // Calculate page vertical offset in Column layout
    final pageHeight = pdfPageHeight * baseScale;
    final pageVerticalOffset = pageIndex * (pageHeight + 2 * pageVerticalMargin) + pageVerticalMargin;

    // Apply zoom to both page-local coordinates and page offset
    final screenX = pageLocalX * zoom + panOffset.dx;
    final screenY = pageLocalY * zoom + pageVerticalOffset * zoom + panOffset.dy;

    return Offset(screenX, screenY);
  }
}
