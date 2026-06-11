// test/mindmap/ink/stroke_stabilizer_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/stroke_stabilizer.dart';

void main() {
  group('StrokeStabilizer', () {
    test('level 0 returns raw point', () {
      final stabilizer = StrokeStabilizer(level: 0);
      final result = stabilizer.stabilize(const Offset(100, 100));
      expect(result, const Offset(100, 100));
    });

    test('level > 0 stabilizes jitter', () {
      final stabilizer = StrokeStabilizer(level: 5);
      stabilizer.stabilize(const Offset(0, 0));
      stabilizer.stabilize(const Offset(1, 1)); // 微小抖动
      final result = stabilizer.stabilize(const Offset(50, 50));
      expect(result.dx, greaterThan(0));
      expect(result.dx, lessThan(50));
    });

    test('reset clears internal state', () {
      final stabilizer = StrokeStabilizer(level: 5);
      stabilizer.stabilize(const Offset(100, 100));
      stabilizer.reset();
      final result = stabilizer.stabilize(const Offset(200, 200));
      expect(result, const Offset(200, 200));
    });
  });
}
