import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/stroke_renderer.dart';

void main() {
  group('StrokeRenderer', () {
    test('filterPoints removes jitter points within 0.5px of previous', () {
      const points = [
        InkPoint(0, 0),
        InkPoint(0.3, 0.3), // jitter, filtered
        InkPoint(1, 1),
        InkPoint(2, 2),
      ];
      final filtered = StrokeRenderer.filterPoints(points);
      expect(filtered.length, 3);
      expect(filtered[0].offset, const Offset(0, 0));
      expect(filtered[1].offset, const Offset(1, 1));
      expect(filtered[2].offset, const Offset(2, 2));
    });

    test('filterPoints returns empty for empty input', () {
      expect(StrokeRenderer.filterPoints(const []), isEmpty);
    });

    test('smoothPoints applies weighted average to interior points', () {
      const points = [
        InkPoint(0, 0),
        InkPoint(10, 10),
        InkPoint(20, 0),
      ];
      final smoothed = StrokeRenderer.smoothPoints(points);
      expect(smoothed.length, 3);
      // First and last preserved
      expect(smoothed.first.offset, const Offset(0, 0));
      expect(smoothed.last.offset, const Offset(20, 0));
      // Middle = 0.25 * 0 + 0.5 * 10 + 0.25 * 20 = 10 (x), 0.25 * 0 + 0.5 * 10 + 0.25 * 0 = 5 (y)
      expect(smoothed[1].x, closeTo(10.0, 0.001));
      expect(smoothed[1].y, closeTo(5.0, 0.001));
    });

    test('smoothPoints returns input unchanged when length < 3', () {
      const pts = [InkPoint(0, 0), InkPoint(10, 10)];
      final smoothed = StrokeRenderer.smoothPoints(pts);
      expect(smoothed.length, 2);
      expect(smoothed.first.offset, const Offset(0, 0));
      expect(smoothed.last.offset, const Offset(10, 10));
    });

    test('catmullRomPath produces a path spanning all control points', () {
      const points = [
        InkPoint(0, 0),
        InkPoint(50, 100),
        InkPoint(100, 50),
        InkPoint(150, 150),
      ];
      final path = StrokeRenderer.catmullRomPath(points, 2.0);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(100));
      expect(bounds.height, greaterThan(100));
    });

    test('catmullRomPath falls back to lineTo when length < 4', () {
      const points = [InkPoint(0, 0), InkPoint(10, 10), InkPoint(20, 0)];
      final path = StrokeRenderer.catmullRomPath(points, 2.0);
      // Just ensure no crash and bounds make sense
      expect(path.getBounds().width, closeTo(20.0, 0.5));
    });
  });
}
