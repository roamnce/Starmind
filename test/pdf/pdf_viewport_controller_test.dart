import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/viewport_transform.dart';

void main() {
  group('ViewportTransform', () {
    late ViewportTransform transform;

    setUp(() {
      transform = ViewportTransform();
    });

    tearDown(() {
      transform.dispose();
    });

    group('zoomAt', () {
      test('should zoom with correct focal point', () {
        transform.setViewportSize(const Size(400, 600));

        // Initial state: zoom=1.0, panOffset=(0,0)
        transform.zoomAt(const Offset(100, 100), 2.0);

        expect(transform.zoom, 2.0);
        // After zooming with focal point at (100,100):
        // The point that was at (100,100) should still be at (100,100)
        // This means panOffset needs adjustment
        // Formula: newPanOffset = focalPoint - (focalPoint - oldPanOffset) * scaleRatio
        // scaleRatio = 2.0 / 1.0 = 2.0
        // newPanOffset = (100, 100) - (100, 100) * 2.0 = (100, 100) - (200, 200) = (-100, -100)
        expect(transform.panOffset.dx, closeTo(-100, 0.1));
        expect(transform.panOffset.dy, closeTo(-100, 0.1));
      });

      test('should clamp zoom to min/max bounds', () {
        transform.setViewportSize(const Size(400, 600));

        transform.zoomAt(Offset.zero, 0.05);
        expect(transform.zoom, ViewportTransform.minZoom);

        transform.zoomAt(Offset.zero, 50.0);
        expect(transform.zoom, ViewportTransform.maxZoom);
      });

      test('should not change zoom if already at target', () {
        transform.setViewportSize(const Size(400, 600));
        transform.setZoom(2.0);

        var notified = false;
        transform.addListener(() => notified = true);

        transform.zoomAt(Offset.zero, 2.0);
        expect(notified, false);
      });

      test('should maintain focal point position after zoom', () {
        transform.setViewportSize(const Size(400, 600));
        transform.setPanOffset(const Offset(50, 50));

        // Zoom at focal point (200, 300) from 1.0 to 2.0
        transform.zoomAt(const Offset(200, 300), 2.0);

        // The point at screen position (200, 300) should map to the same PDF position
        // Before: PDF position = (200 - 50, 300 - 50) = (150, 250) at zoom 1.0
        // After: PDF position should still be (150, 250) at zoom 2.0
        // Screen position = panOffset + PDF position * zoom
        // 200 = panOffset.dx + 150 * 2.0 => panOffset.dx = 200 - 300 = -100
        // 300 = panOffset.dy + 250 * 2.0 => panOffset.dy = 300 - 500 = -200
        expect(transform.panOffset.dx, closeTo(-100, 0.1));
        expect(transform.panOffset.dy, closeTo(-200, 0.1));
      });
    });

    group('pan', () {
      test('should add delta to pan offset', () {
        transform.setPanOffset(Offset.zero);
        transform.pan(const Offset(50, 100));

        expect(transform.panOffset.dx, 50);
        expect(transform.panOffset.dy, 100);
      });

      test('should accumulate pan deltas', () {
        transform.setPanOffset(Offset.zero);
        transform.pan(const Offset(50, 100));
        transform.pan(const Offset(25, 50));

        expect(transform.panOffset.dx, 75);
        expect(transform.panOffset.dy, 150);
      });

      test('should notify listeners on pan', () {
        var notified = false;
        transform.addListener(() => notified = true);

        transform.pan(const Offset(10, 10));
        expect(notified, true);
      });
    });

    group('constrainBounds', () {
      test('should not modify pan when free pan is enabled', () {
        // constrainBounds is now a no-op for free panning
        transform.setFreePanEnabled(true);
        transform.setViewportSize(const Size(400, 600));
        transform.setZoom(0.5);
        transform.setPanOffset(Offset.zero);

        transform.constrainBounds(
          pdfSize: const Size(595, 842),
          viewportSize: const Size(400, 600),
          freePanEnabled: transform.freePanEnabled,
        );

        // With free pan, pan offset should remain unchanged
        expect(transform.panOffset, Offset.zero);
      });

      test('should allow any pan position with free pan', () {
        transform.setFreePanEnabled(true);
        transform.setViewportSize(const Size(400, 600));
        transform.setZoom(2.0);
        transform.setPanOffset(const Offset(-1000, -1000));

        transform.constrainBounds(
          pdfSize: const Size(595, 842),
          viewportSize: const Size(400, 600),
          freePanEnabled: transform.freePanEnabled,
        );

        // With free pan, even extreme positions are allowed
        expect(transform.panOffset, const Offset(-1000, -1000));
      });

      test('should not modify pan when already at any position', () {
        transform.setFreePanEnabled(true);
        transform.setViewportSize(const Size(400, 600));
        transform.setZoom(2.0);
        transform.setPanOffset(const Offset(-100, -100));

        transform.constrainBounds(
          pdfSize: const Size(595, 842),
          viewportSize: const Size(400, 600),
          freePanEnabled: transform.freePanEnabled,
        );

        // Should stay at same position since free pan is enabled
        expect(transform.panOffset, const Offset(-100, -100));
      });
    });

    group('setViewportState', () {
      test('should set zoom and pan offset together', () {
        transform.setViewportState(zoom: 2.0, panOffset: const Offset(50, 100));

        expect(transform.zoom, 2.0);
        expect(transform.panOffset.dx, 50);
        expect(transform.panOffset.dy, 100);
      });

      test('should clamp zoom to valid range', () {
        transform.setViewportState(zoom: 50.0);

        expect(transform.zoom, ViewportTransform.maxZoom);
      });
    });

    group('resetViewport', () {
      test('should reset to default state', () {
        transform.setZoom(3.0);
        transform.setPanOffset(const Offset(100, 200));

        transform.resetViewport();

        expect(transform.zoom, 1.0);
        expect(transform.panOffset, Offset.zero);
      });
    });

    group('Zoom range', () {
      test('allows zoom down to 0.1x', () {
        expect(ViewportTransform.minZoom, 0.1);
      });

      test('allows zoom up to 30x', () {
        expect(ViewportTransform.maxZoom, 30.0);
      });

      test('setZoom clamps below minimum', () {
        transform.setZoom(0.05);

        expect(transform.zoom, ViewportTransform.minZoom);
      });

      test('setZoom clamps above maximum', () {
        transform.setZoom(50.0);

        expect(transform.zoom, ViewportTransform.maxZoom);
      });
    });
  });
}
