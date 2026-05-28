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

        controller.zoomAt(Offset.zero, 0.05);
        expect(controller.zoom, PdfViewportController.minZoom);

        controller.zoomAt(Offset.zero, 50.0);
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
      test('should not modify pan when free pan is enabled', () {
        // constrainBounds is now a no-op for free panning
        controller.setFreePanEnabled(true);
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(0.5);
        controller.setPanOffset(Offset.zero);

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // With free pan, pan offset should remain unchanged
        expect(controller.panOffset, Offset.zero);
      });

      test('should allow any pan position with free pan', () {
        controller.setFreePanEnabled(true);
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(2.0);
        controller.setPanOffset(const Offset(-1000, -1000));

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // With free pan, even extreme positions are allowed
        expect(controller.panOffset, const Offset(-1000, -1000));
      });

      test('should not modify pan when already at any position', () {
        controller.setFreePanEnabled(true);
        controller.setViewportSize(const Size(400, 600));
        controller.setZoom(2.0);
        controller.setPanOffset(const Offset(-100, -100));

        controller.constrainBounds(const Size(595, 842), const Size(400, 600));

        // Should stay at same position since free pan is enabled
        expect(controller.panOffset, const Offset(-100, -100));
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
        controller.setViewportState(zoom: 50.0);

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
      test('allows zoom down to 0.1x', () {
        expect(PdfViewportController.minZoom, 0.1);
      });

      test('allows zoom up to 30x', () {
        expect(PdfViewportController.maxZoom, 30.0);
      });

      test('setZoom clamps below minimum', () {
        controller.setZoom(0.05);

        expect(controller.zoom, PdfViewportController.minZoom);
      });

      test('setZoom clamps above maximum', () {
        controller.setZoom(50.0);

        expect(controller.zoom, PdfViewportController.maxZoom);
      });
    });
  });
}
