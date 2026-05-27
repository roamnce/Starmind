import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

void main() {
  group('PenConfig', () {
    test('fountainPen preset should have pressure enabled', () {
      final config = PenConfig.fountainPen();
      expect(config.pressureEnabled, isTrue);
      expect(config.pressureCurve, PressureCurve.soft);
    });

    test('highlighter preset should be semi-transparent', () {
      final config = PenConfig.highlighter();
      expect(config.opacity, closeTo(0.3, 0.01));
      expect(config.pressureEnabled, isFalse);
    });

    test('eraser preset should have correct type', () {
      final config = PenConfig.eraser();
      expect(config.type, PenType.eraser);
      expect(config.pressureEnabled, isFalse);
    });

    test('should serialize to JSON', () {
      final config = PenConfig(
        type: PenType.ballpointPen,
        color: Colors.blue,
        baseWidth: 2.0,
      );

      final json = config.toJson();
      expect(json['type'], 'ballpointPen');
      expect(json['baseWidth'], 2.0);
    });

    test('should deserialize from JSON', () {
      final json = {
        'type': 'fountainPen',
        'color': 0xFF000000,
        'baseWidth': 2.0,
        'opacity': 1.0,
        'stabilizerLevel': 3,
        'pressureEnabled': true,
      };

      final config = PenConfig.fromJson(json);
      expect(config.type, PenType.fountainPen);
      expect(config.baseWidth, 2.0);
    });

    test('ballpointPen preset should have medium stabilizer', () {
      final config = PenConfig.ballpointPen();
      expect(config.stabilizerLevel, greaterThanOrEqualTo(2));
      expect(config.stabilizerLevel, lessThanOrEqualTo(5));
    });

    test('pencil preset should have texture-like settings', () {
      final config = PenConfig.pencil();
      expect(config.type, PenType.pencil);
      expect(config.opacity, lessThan(1.0));
    });

    test('copyWith should create modified copy', () {
      final original = PenConfig.fountainPen();
      final modified = original.copyWith(baseWidth: 5.0, color: Colors.red);

      expect(modified.baseWidth, 5.0);
      expect(modified.color, Colors.red);
      expect(modified.type, original.type);
      expect(modified.pressureEnabled, original.pressureEnabled);
    });

    test('default constructor should have sensible defaults', () {
      final config = PenConfig();
      expect(config.type, PenType.ballpointPen);
      expect(config.color, Colors.black);
      expect(config.baseWidth, greaterThan(0));
      expect(config.opacity, 1.0);
    });

    test('JSON round-trip should preserve all properties', () {
      final original = PenConfig.fountainPen().copyWith(
        color: const Color(0xFF9B27B0), // Use Color instead of MaterialColor
        baseWidth: 3.5,
        stabilizerLevel: 7,
      );

      final json = original.toJson();
      final restored = PenConfig.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.color.toARGB32(), original.color.toARGB32());
      expect(restored.baseWidth, original.baseWidth);
      expect(restored.opacity, original.opacity);
      expect(restored.stabilizerLevel, original.stabilizerLevel);
      expect(restored.pressureEnabled, original.pressureEnabled);
    });
  });

  group('PenType', () {
    test('all pen types should have valid string representation', () {
      for (final type in PenType.values) {
        expect(type.name, isNotEmpty);
      }
    });

    test('PenType should parse from string', () {
      expect(PenType.fromString('fountainPen'), PenType.fountainPen);
      expect(PenType.fromString('ballpointPen'), PenType.ballpointPen);
      expect(PenType.fromString('pencil'), PenType.pencil);
      expect(PenType.fromString('highlighter'), PenType.highlighter);
      expect(PenType.fromString('eraser'), PenType.eraser);
    });

    test('PenType.fromString should return default for invalid input', () {
      expect(PenType.fromString('invalid'), PenType.ballpointPen);
      expect(PenType.fromString(''), PenType.ballpointPen);
      expect(PenType.fromString(null), PenType.ballpointPen);
    });
  });
}
