import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/stroke_stabilizer.dart';

void main() {
  group('StrokeStabilizer', () {
    test('level 0 should return input unchanged', () {
      final stabilizer = StrokeStabilizer(level: 0);
      final input = Offset(100, 100);
      expect(stabilizer.stabilize(input), input);
    });

    test('level 10 should smooth jittery input', () {
      final stabilizer = StrokeStabilizer(level: 10);

      // Simulate jittery input
      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(5, 2));
      stabilizer.stabilize(Offset(3, -1));
      final smoothed = stabilizer.stabilize(Offset(8, 3));

      // Output should be smoother than raw input
      expect(smoothed.dx, lessThan(8));
    });

    test('should smooth pressure values', () {
      final stabilizer = StrokeStabilizer(level: 5);

      stabilizer.stabilizePressure(0.5);
      stabilizer.stabilizePressure(0.6);
      final smoothed = stabilizer.stabilizePressure(0.4);

      expect(smoothed, closeTo(0.5, 0.1));
    });

    test('finalize should generate catch-up points', () {
      final stabilizer = StrokeStabilizer(level: 10);

      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(50, 50));
      final catchUp = stabilizer.finalize(Offset(100, 100));

      expect(catchUp.length, greaterThan(0));
    });

    test('reset should clear all state', () {
      final stabilizer = StrokeStabilizer(level: 5);

      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(50, 50));
      stabilizer.reset();

      // After reset, first point should be returned directly
      expect(stabilizer.stabilize(Offset(100, 100)), Offset(100, 100));
    });
  });
}
