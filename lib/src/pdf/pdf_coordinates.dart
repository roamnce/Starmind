import 'dart:math' as math;
import 'dart:ui';

/// Encapsulates coordinate transformation between Flutter and PDF coordinate spaces.
///
/// PDF uses a Y-up coordinate system (origin at bottom-left).
/// Flutter uses a Y-down coordinate system (origin at top-left).
/// This class hides the Y-flip transformation behind a deep interface.
class PdfCoordinates {
  const PdfCoordinates({
    required this.pdfWidth,
    required this.pdfHeight,
  });

  /// Width of the PDF page in PDF points.
  final double pdfWidth;

  /// Height of the PDF page in PDF points.
  final double pdfHeight;

  /// Converts a Flutter viewport rectangle to PDF coordinates.
  ///
  /// [flutterRect] - Rectangle in Flutter canvas coordinates (Y-down, scaled)
  /// [scale] - Current zoom scale
  /// Returns rectangle in PDF coordinates (Y-up)
  Rect flutterToPdf(Rect flutterRect, double scale) {
    return Rect.fromLTRB(
      flutterRect.left / scale,
      pdfHeight - (flutterRect.top / scale),    // Y-flip
      flutterRect.right / scale,
      pdfHeight - (flutterRect.bottom / scale), // Y-flip
    );
  }

  /// Converts a PDF rectangle to Flutter viewport coordinates.
  ///
  /// [pdfRect] - Rectangle in PDF coordinates (Y-up)
  /// [scale] - Current zoom scale
  /// Returns rectangle in Flutter canvas coordinates (Y-down, scaled)
  Rect pdfToFlutter(Rect pdfRect, double scale) {
    return Rect.fromLTRB(
      pdfRect.left * scale,
      (pdfHeight - pdfRect.top) * scale,    // Y-flip
      pdfRect.right * scale,
      (pdfHeight - pdfRect.bottom) * scale, // Y-flip
    );
  }

  /// Converts a Flutter point to PDF coordinates.
  Offset flutterToPdfPoint(Offset flutterPoint, double scale) {
    return Offset(
      flutterPoint.dx / scale,
      pdfHeight - (flutterPoint.dy / scale), // Y-flip
    );
  }

  /// Converts a Flutter point to PDF coordinates with pan offset.
  ///
  /// Use this when the Flutter point is in screen coordinates
  /// (relative to viewport, not relative to PDF page).
  Offset screenToPdf(Offset screenPoint, double scale, Offset panOffset) {
    return Offset(
      (screenPoint.dx - panOffset.dx) / scale,
      pdfHeight - (screenPoint.dy - panOffset.dy) / scale, // Y-flip
    );
  }

  /// Converts a PDF point to Flutter coordinates.
  Offset pdfToFlutterPoint(Offset pdfPoint, double scale) {
    return Offset(
      pdfPoint.dx * scale,
      (pdfHeight - pdfPoint.dy) * scale, // Y-flip
    );
  }

  /// Returns the full page rectangle in PDF coordinates.
  /// Top = pdfHeight (max Y), Bottom = 0 (min Y)
  Rect get fullPagePdfRect => Rect.fromLTRB(0, pdfHeight, pdfWidth, 0);

  /// Returns the full page rectangle in Flutter coordinates at given scale.
  Rect fullPageFlutterRect(double scale) => Rect.fromLTWH(0, 0, pdfWidth * scale, pdfHeight * scale);

  /// Normalizes a PDF rectangle so that top >= bottom.
  /// PDF coordinates can have inverted Y values; this ensures consistent ordering.
  Rect normalizePdfRect(Rect pdfRect) {
    return Rect.fromLTRB(
      pdfRect.left,
      math.max(pdfRect.top, pdfRect.bottom),
      pdfRect.right,
      math.min(pdfRect.top, pdfRect.bottom),
    );
  }

  /// Checks if a PDF point is within the given character bounds.
  /// Handles the inverted Y-axis where char.top > char.bottom in PDF coords.
  bool isPointInCharBounds(Offset pdfPoint, Rect charRect) {
    final normalized = normalizePdfRect(charRect);
    return pdfPoint.dx >= charRect.left &&
           pdfPoint.dx <= charRect.right &&
           pdfPoint.dy >= normalized.bottom &&
           pdfPoint.dy <= normalized.top;
  }

  /// Calculates the distance from a PDF point to a character rectangle.
  /// Returns 0 if point is inside the character bounds.
  double distanceToChar(Offset pdfPoint, Rect charRect) {
    final normalized = normalizePdfRect(charRect);

    double dx = 0;
    if (pdfPoint.dx < charRect.left) {
      dx = charRect.left - pdfPoint.dx;
    } else if (pdfPoint.dx > charRect.right) {
      dx = pdfPoint.dx - charRect.right;
    }

    double dy = 0;
    if (pdfPoint.dy < normalized.bottom) {
      dy = normalized.bottom - pdfPoint.dy;
    } else if (pdfPoint.dy > normalized.top) {
      dy = pdfPoint.dy - normalized.top;
    }

    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfCoordinates &&
          pdfWidth == other.pdfWidth &&
          pdfHeight == other.pdfHeight;

  @override
  int get hashCode => pdfWidth.hashCode ^ pdfHeight.hashCode;

  @override
  String toString() => 'PdfCoordinates(width: $pdfWidth, height: $pdfHeight)';
}
