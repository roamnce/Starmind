import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/selection_overlay_geometry.dart';

void main() {
  group('SelectionOverlayGeometry', () {
    group('pdfRectsToScreenBounds', () {
      test('page 0 at zoom=1 with no pan should account for top margin', () {
        // PDF page: 595pt wide x 842pt tall (A4)
        // Base scale: 1.0 (1 CSS pixel per PDF point)
        // Margin: 8px
        // Selection: rect at top of page (PDF coords: y=800 to y=820)

        final pdfRects = [
          Rect.fromLTRB(100, 820, 200, 800), // PDF Y-up: top=820, bottom=800
        ];

        final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
          pdfRects: pdfRects,
          pageIndex: 0,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 1.0,
          panOffset: Offset.zero,
          pageVerticalMargin: 8.0,
        );

        // Expected page-local Flutter coords (Y-down):
        // top = 842 - 820 = 22
        // bottom = 842 - 800 = 42

        // Expected screen coords (page 0):
        // Page vertical offset = margin = 8px
        // screenTopY = 22 * 1.0 + 8 + 0 = 30
        // screenBottomY = 42 * 1.0 + 8 + 0 = 50

        expect(centerX, 150.0); // (100 + 200) / 2
        expect(topY, 30.0);
        expect(bottomY, 50.0);
      });

      test('page 0 at zoom=3 should scale margin offset', () {
        final pdfRects = [
          Rect.fromLTRB(100, 820, 200, 800),
        ];

        final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
          pdfRects: pdfRects,
          pageIndex: 0,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 3.0,
          panOffset: Offset.zero,
          pageVerticalMargin: 8.0,
        );

        // Expected:
        // Page vertical offset = 8px
        // screenTopY = 22 * 3.0 + 8 * 3.0 + 0 = 66 + 24 = 90
        // screenBottomY = 42 * 3.0 + 8 * 3.0 + 0 = 126 + 24 = 150

        expect(centerX, 450.0); // 150 * 3.0
        expect(topY, 90.0);
        expect(bottomY, 150.0);
      });

      test('page 1 at zoom=1 should account for previous page height and margins', () {
        final pdfRects = [
          Rect.fromLTRB(100, 820, 200, 800),
        ];

        final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
          pdfRects: pdfRects,
          pageIndex: 1,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 1.0,
          panOffset: Offset.zero,
          pageVerticalMargin: 8.0,
        );

        // Expected:
        // Page 0 takes: margin(8) + pageHeight(842) + margin(8) = 858px
        // Page 1 starts at: 858px
        // Page 1 top margin: 8px
        // Total offset for page 1: 858 + 8 = 866px
        //
        // Wait, let me recalculate the layout:
        // Column layout:
        //   margin(8)
        //   page0(842)
        //   margin(8)
        //   margin(8)  <- between pages
        //   page1(842)
        //   margin(8)
        //
        // Actually, looking at the code pattern, it's:
        //   margin + page0 + margin + margin + page1 + margin
        // = 8 + 842 + 8 + 8 + page1_content + 8
        //
        // But more simply: pageIndex * (pageHeight + 2*margin) + margin
        // Page 1 offset = 1 * (842 + 16) + 8 = 858 + 8 = 866
        //
        // screenTopY = 22 * 1.0 + 866 + 0 = 888
        // screenBottomY = 42 * 1.0 + 866 + 0 = 908

        expect(centerX, 150.0);
        expect(topY, 888.0);
        expect(bottomY, 908.0);
      });

      test('page 2 at zoom=2 with pan offset', () {
        final pdfRects = [
          Rect.fromLTRB(100, 820, 200, 800),
        ];

        final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
          pdfRects: pdfRects,
          pageIndex: 2,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 2.0,
          panOffset: const Offset(50, -100),
          pageVerticalMargin: 8.0,
        );

        // Expected:
        // Page 2 offset = 2 * (842 + 16) + 8 = 1716 + 8 = 1724
        // screenTopY = 22 * 2.0 + 1724 * 2.0 + (-100) = 44 + 3448 - 100 = 3392
        // screenBottomY = 42 * 2.0 + 1724 * 2.0 + (-100) = 84 + 3448 - 100 = 3432

        expect(centerX, 350.0); // 150 * 2.0 + 50
        expect(topY, 3392.0);
        expect(bottomY, 3432.0);
      });

      test('multiple rects should merge bounds correctly', () {
        final pdfRects = [
          Rect.fromLTRB(100, 820, 200, 800), // top rect
          Rect.fromLTRB(100, 780, 200, 760), // bottom rect
        ];

        final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
          pdfRects: pdfRects,
          pageIndex: 0,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 1.0,
          panOffset: Offset.zero,
          pageVerticalMargin: 8.0,
        );

        // Page-local Flutter coords:
        // Rect 1: top=22, bottom=42
        // Rect 2: top=62, bottom=82
        // Merged: top=22, bottom=82

        // Screen coords:
        // screenTopY = 22 + 8 = 30
        // screenBottomY = 82 + 8 = 90

        expect(centerX, 150.0);
        expect(topY, 30.0);
        expect(bottomY, 90.0);
      });
    });

    group('pdfPointToScreen', () {
      test('page 0 at zoom=1 should account for top margin', () {
        final pdfPoint = Offset(100, 800); // PDF Y-up

        final screenPoint = SelectionOverlayGeometry.pdfPointToScreen(
          pdfPoint: pdfPoint,
          pageIndex: 0,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 1.0,
          panOffset: Offset.zero,
          pageVerticalMargin: 8.0,
        );

        // Page-local: (100, 42)
        // Screen: (100, 42 + 8) = (100, 50)
        expect(screenPoint.dx, 100.0);
        expect(screenPoint.dy, 50.0);
      });

      test('page 1 at zoom=2 should account for previous page', () {
        final pdfPoint = Offset(100, 800);

        final screenPoint = SelectionOverlayGeometry.pdfPointToScreen(
          pdfPoint: pdfPoint,
          pageIndex: 1,
          pdfPageHeight: 842,
          baseScale: 1.0,
          zoom: 2.0,
          panOffset: const Offset(10, -50),
          pageVerticalMargin: 8.0,
        );

        // Page 1 offset = 1 * (842 + 16) + 8 = 866
        // Page-local: (100, 42)
        // Screen: 100 * 2.0 + 10 = 210
        //         42 * 2.0 + 866 * 2.0 + (-50) = 84 + 1732 - 50 = 1766
        expect(screenPoint.dx, 210.0);
        expect(screenPoint.dy, 1766.0);
      });
    });
  });
}
