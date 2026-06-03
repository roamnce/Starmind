import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

void main() {
  group('PressureCurve', () {
    test('linear curve should return input unchanged', () {
      const curve = PressureCurve.linear;
      expect(curve.evaluate(0.0), closeTo(0.0, 0.01));
      expect(curve.evaluate(0.5), closeTo(0.5, 0.01));
      expect(curve.evaluate(1.0), closeTo(1.0, 0.01));
    });

    test('soft curve should amplify light pressure', () {
      const curve = PressureCurve.soft;
      // Light pressure should produce higher output
      expect(curve.evaluate(0.3), greaterThan(0.3));
    });

    test('firm curve should require more pressure', () {
      const curve = PressureCurve.firm;
      // Light pressure should produce lower output
      expect(curve.evaluate(0.3), lessThan(0.3));
    });

    test('should serialize and deserialize correctly', () {
      const curve = PressureCurve.soft;
      final json = curve.toJson();
      final restored = PressureCurve.fromJson(json);
      expect(restored.p1.dx, closeTo(curve.p1.dx, 0.01));
      expect(restored.p1.dy, closeTo(curve.p1.dy, 0.01));
      expect(restored.p2.dx, closeTo(curve.p2.dx, 0.01));
      expect(restored.p2.dy, closeTo(curve.p2.dy, 0.01));
    });
  });
}
