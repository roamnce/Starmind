import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_coordinates.dart';

void main() {
  group('PdfCoordinates', () {
    const coords = PdfCoordinates(pdfWidth: 612.0, pdfHeight: 792.0); // Standard Letter size

    group('flutterToPdf', () {
      test('should convert top-left Flutter point to bottom-left PDF point', () {
        // Flutter point (0, 0) is top-left
        // PDF point should be (0, 792) which is bottom-left
        final result = coords.flutterToPdfPoint(Offset(0, 0), 1.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(792.0));
      });

      test('should convert bottom-left Flutter point to top-left PDF point', () {
        // Flutter point (0, 792) is bottom-left
        // PDF point should be (0, 0) which is top-left
        final result = coords.flutterToPdfPoint(Offset(0, 792.0), 1.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(0.0));
      });

      test('should apply scale correctly', () {
        // At scale 2.0, Flutter point (0, 400) maps to PDF (0, 792 - 200) = (0, 592)
        final result = coords.flutterToPdfPoint(Offset(0, 400.0), 2.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(792.0 - 200.0));
      });

      test('should convert rectangle correctly', () {
        // Flutter rect: left=100, top=200, right=300, bottom=400 (at scale 1.0)
        // PDF rect: left=100, top=792-200=592, right=300, bottom=792-400=392
        final flutterRect = Rect.fromLTWH(100, 200, 200, 200);
        final result = coords.flutterToPdf(flutterRect, 1.0);
        expect(result.left, equals(100.0));
        expect(result.top, equals(592.0));
        expect(result.right, equals(300.0));
        expect(result.bottom, equals(392.0));
      });
    });

    group('pdfToFlutter', () {
      test('should convert bottom-left PDF point to top-left Flutter point', () {
        // PDF point (0, 792) is bottom-left
        // Flutter point should be (0, 0) which is top-left
        final result = coords.pdfToFlutterPoint(Offset(0, 792.0), 1.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(0.0));
      });

      test('should convert top-left PDF point to bottom-left Flutter point', () {
        // PDF point (0, 0) is top-left
        // Flutter point should be (0, 792) which is bottom-left
        final result = coords.pdfToFlutterPoint(Offset(0, 0.0), 1.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(792.0));
      });

      test('should apply scale correctly', () {
        // PDF point (0, 592) at scale 2.0 -> Flutter (0, (792-592)*2) = (0, 400)
        final result = coords.pdfToFlutterPoint(Offset(0, 592.0), 2.0);
        expect(result.dx, equals(0.0));
        expect(result.dy, equals(400.0));
      });

      test('should convert rectangle correctly', () {
        // PDF rect: left=100, top=592, right=300, bottom=392
        // Flutter rect: left=100, top=(792-592)=200, right=300, bottom=(792-392)=400
        final pdfRect = Rect.fromLTRB(100, 592, 300, 392);
        final result = coords.pdfToFlutter(pdfRect, 1.0);
        expect(result.left, equals(100.0));
        expect(result.top, equals(200.0));
        expect(result.right, equals(300.0));
        expect(result.bottom, equals(400.0));
      });
    });

    group('fullPagePdfRect', () {
      test('should return correct full page bounds', () {
        final rect = coords.fullPagePdfRect;
        expect(rect.left, equals(0.0));
        expect(rect.top, equals(792.0)); // Max Y (top of PDF)
        expect(rect.right, equals(612.0));
        expect(rect.bottom, equals(0.0)); // Min Y (bottom of PDF)
      });
    });

    group('fullPageFlutterRect', () {
      test('should return correct full page bounds at scale 1.0', () {
        final rect = coords.fullPageFlutterRect(1.0);
        expect(rect.left, equals(0.0));
        expect(rect.top, equals(0.0));
        expect(rect.width, equals(612.0));
        expect(rect.height, equals(792.0));
      });

      test('should apply scale correctly', () {
        final rect = coords.fullPageFlutterRect(2.0);
        expect(rect.width, equals(1224.0));
        expect(rect.height, equals(1584.0));
      });
    });

    group('normalizePdfRect', () {
      test('should normalize inverted Y rectangle', () {
        // PDF char rect might have top=500, bottom=480 (correct order)
        final rect = Rect.fromLTRB(100, 500, 200, 480);
        final normalized = coords.normalizePdfRect(rect);
        expect(normalized.top, equals(500.0));
        expect(normalized.bottom, equals(480.0));
      });

      test('should normalize already correct rectangle', () {
        final rect = Rect.fromLTRB(100, 480, 200, 500); // Inverted
        final normalized = coords.normalizePdfRect(rect);
        expect(normalized.top, equals(500.0)); // Should be larger
        expect(normalized.bottom, equals(480.0));
      });
    });

    group('isPointInCharBounds', () {
      test('should return true for point inside bounds', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480); // PDF coords
        final point = Offset(150, 490); // Inside
        expect(coords.isPointInCharBounds(point, charRect), isTrue);
      });

      test('should return false for point outside bounds (left)', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480);
        final point = Offset(50, 490); // Outside on left
        expect(coords.isPointInCharBounds(point, charRect), isFalse);
      });

      test('should return false for point outside bounds (above)', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480);
        final point = Offset(150, 510); // Above top
        expect(coords.isPointInCharBounds(point, charRect), isFalse);
      });
    });

    group('distanceToChar', () {
      test('should return 0 for point inside bounds', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480);
        final point = Offset(150, 490);
        expect(coords.distanceToChar(point, charRect), equals(0.0));
      });

      test('should calculate distance for point outside', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480);
        final point = Offset(50, 490); // 50 pixels to the left
        expect(coords.distanceToChar(point, charRect), equals(50.0));
      });

      test('should calculate diagonal distance', () {
        final charRect = Rect.fromLTRB(100, 500, 200, 480);
        final point = Offset(50, 450); // Left and below
        // dx = 100 - 50 = 50, dy = 480 - 450 = 30
        // distance = sqrt(50^2 + 30^2) = sqrt(2500 + 900) = sqrt(3400) ≈ 58.31
        final distance = coords.distanceToChar(point, charRect);
        expect(distance, closeTo(58.31, 0.01));
      });
    });

    group('equality', () {
      test('equal coordinates should be equal', () {
        const coords2 = PdfCoordinates(pdfWidth: 612.0, pdfHeight: 792.0);
        expect(coords, equals(coords2));
      });

      test('different coordinates should not be equal', () {
        const coords2 = PdfCoordinates(pdfWidth: 500.0, pdfHeight: 700.0);
        expect(coords, isNot(equals(coords2)));
      });
    });

    group('round-trip conversion', () {
      test('flutterToPdf then pdfToFlutter should return original point', () {
        const original = Offset(100, 200);
        final pdfPoint = coords.flutterToPdfPoint(original, 1.5);
        final backToFlutter = coords.pdfToFlutterPoint(pdfPoint, 1.5);
        expect(backToFlutter.dx, closeTo(original.dx, 0.001));
        expect(backToFlutter.dy, closeTo(original.dy, 0.001));
      });

      test('flutterToPdf then pdfToFlutter should return original rect', () {
        final original = Rect.fromLTWH(50, 100, 200, 150);
        final pdfRect = coords.flutterToPdf(original, 2.0);
        final backToFlutter = coords.pdfToFlutter(pdfRect, 2.0);
        expect(backToFlutter.left, closeTo(original.left, 0.001));
        expect(backToFlutter.top, closeTo(original.top, 0.001));
        expect(backToFlutter.right, closeTo(original.right, 0.001));
        expect(backToFlutter.bottom, closeTo(original.bottom, 0.001));
      });
    });
  });
}