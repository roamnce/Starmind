import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';

void main() {
  group('PdfViewportController', () {
    late PdfViewportController controller;

    setUp(() {
      controller = PdfViewportController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('zoomAt', () {
      test('should zoom with correct focal point', () {
        controller.setViewportSize(const Size(400, 600));

        // Initial state: zoom=1.0, panOffset=(0,0)
        controller.zoomAt(const Offset(100, 100), 2.0);

        expect(controller.zoom, 2.0);
        // After zooming with focal point at (100,100):
        // The point that was at (100,100) should still be at (100,100)
        // This means panOffset needs adjustment
        // Formula: newPanOffset = focalPoint - (focalPoint - oldPanOffset) * scaleRatio
        // scaleRatio = 2.0 / 1.0 = 2.0
        // newPanOffset = (100, 100) - (100, 100) * 2.0 = (100, 100) - (200, 200) = (-100, -100)
        expect(controller.panOffset.dx, closeTo(-100, 0.1));
        expect(controller.panOffset.dy, closeTo(-100, 0.1));
      });

      test('should clamp zoom to min/max bounds', () {
        controller.setViewportSize(const Size(400, 600));

        controller.zoomAt(Offset.zero, 0.1);
        expect(controller.zoom, PdfViewportController.minZoom);

        controller.zoomAt(Offset.zero, 20.0);
        expect(controller.zoom, PdfViewportController.maxZoom);
      });

      test('should not change zoom if already at target', () {
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(2.0);

        var notified = false;
        controller.addListener(() => notified = true);

        controller.zoomAt(Offset.zero, 2.0);
        expect(notified, false);
      });

      test('should maintain focal point position after zoom', () {
        controller.setViewportSize(const Size(400, 600));
        controller.setPanOffset(const Offset(50, 50));

        // Zoom at focal point (200, 300) from 1.0 to 2.0
        controller.zoomAt(const Offset(200, 300), 2.0);

        // The point at screen position (200, 300) should map to the same PDF position
        // Before: PDF position = (200 - 50, 300 - 50) = (150, 250) at zoom 1.0
        // After: PDF position should still be (150, 250) at zoom 2.0
        // Screen position = panOffset + PDF position * zoom
        // 200 = panOffset.dx + 150 * 2.0 => panOffset.dx = 200 - 300 = -100
        // 300 = panOffset.dy + 250 * 2.0 => panOffset.dy = 300 - 500 = -200
        expect(controller.panOffset.dx, closeTo(-100, 0.1));
        expect(controller.panOffset.dy, closeTo(-200, 0.1));
      });
    });

    group('pan', () {
      test('should add delta to pan offset', () {
        controller.setPanOffset(Offset.zero);
        controller.pan(const Offset(50, 100));

        expect(controller.panOffset.dx, 50);
        expect(controller.panOffset.dy, 100);
      });

      test('should accumulate pan deltas', () {
        controller.setPanOffset(Offset.zero);
        controller.pan(const Offset(50, 100));
        controller.pan(const Offset(25, 50));

        expect(controller.panOffset.dx, 75);
        expect(controller.panOffset.dy, 150);
      });

      test('should notify listeners on pan', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.pan(const Offset(10, 10));
        expect(notified, true);
      });
    });

    group('constrainBounds', () {
      test('should center PDF when smaller than viewport', () {
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(0.5); // PDF smaller than viewport

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // PDF should be centered
        // baseScale = 400 / 595 ≈ 0.672
        // scaledWidth = 595 * 0.672 * 0.5 ≈ 200
        // scaledHeight = 842 * 0.672 * 0.5 ≈ 283
        // centerX = (400 - 200) / 2 = 100
        // centerY = (600 - 283) / 2 ≈ 158.5
        expect(controller.panOffset.dx, closeTo(100, 1.0));
        expect(controller.panOffset.dy, closeTo(158.5, 1.0));
      });

      test('should clamp pan when PDF larger than viewport', () {
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(2.0); // PDF larger than viewport
        controller.setPanOffset(const Offset(-1000, -1000)); // Way out of bounds

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // Should be constrained to valid range
        // baseScale = 400 / 595 ≈ 0.672
        // scaledWidth = 595 * 0.672 * 2.0 ≈ 800
        // scaledHeight = 842 * 0.672 * 2.0 ≈ 1132
        // minX = 400 - 800 = -400
        // minY = 600 - 1132 ≈ -532
        // Use larger tolerance for floating point calculations
        expect(controller.panOffset.dx, closeTo(-400, 0.5));
        expect(controller.panOffset.dy, closeTo(-532, 0.5));
        expect(controller.panOffset.dx, lessThanOrEqualTo(0));
        expect(controller.panOffset.dy, lessThanOrEqualTo(0));
      });

      test('should not modify pan when already within bounds', () {
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(2.0);
        controller.setPanOffset(const Offset(-100, -100));

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // Should stay at same position since it's within bounds
        expect(controller.panOffset.dx, closeTo(-100, 0.1));
        expect(controller.panOffset.dy, closeTo(-100, 0.1));
      });

      test('should clamp to zero when PDF exactly fits viewport width', () {
        controller.setViewportSize(const Size(400, 600));
        // Set zoom so PDF width exactly matches viewport
        // baseScale = 400 / 595 ≈ 0.672
        // For width to match: 595 * 0.672 * zoom = 400 => zoom = 1.0
        controller.setZoom(1.0);
        controller.setPanOffset(const Offset(100, 0)); // Out of bounds horizontally

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // Width fits exactly, so pan.dx should be 0
        expect(controller.panOffset.dx, closeTo(0, 0.1));
      });
    });

    group('setViewportState', () {
      test('should set zoom and pan offset together', () {
        controller.setViewportState(zoom: 2.0, panOffset: const Offset(50, 100));

        expect(controller.zoom, 2.0);
        expect(controller.panOffset.dx, 50);
        expect(controller.panOffset.dy, 100);
      });

      test('should clamp zoom to valid range', () {
        controller.setViewportState(zoom: 10.0);

        expect(controller.zoom, PdfViewportController.maxZoom);
      });
    });

    group('resetViewport', () {
      test('should reset to default state', () {
        controller.setZoom(3.0);
        controller.setPanOffset(const Offset(100, 200));

        controller.resetViewport();

        expect(controller.zoom, 1.0);
        expect(controller.panOffset, Offset.zero);
      });
    });

    group('Zoom range', () {
      test('allows zoom down to 0.3x', () {
        expect(PdfViewportController.minZoom, 0.3);
      });

      test('allows zoom up to 10x', () {
        expect(PdfViewportController.maxZoom, 10.0);
      });

      test('setZoom clamps below minimum', () {
        controller.setZoom(0.1);

        expect(controller.zoom, PdfViewportController.minZoom);
      });

      test('setZoom clamps above maximum', () {
        controller.setZoom(15.0);

        expect(controller.zoom, PdfViewportController.maxZoom);
      });
    });
  });
}
