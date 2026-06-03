// test/mindmap/utils/color_utils_test.dart
//
// ColorUtils 工具类单元测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/utils/color_utils.dart';

void main() {
  group('ColorUtils', () {
    group('parseColor', () {
      test('parses hex color #RRGGBB', () {
        const colorStr = '#FF5733';
        final color = ColorUtils.parseColor(colorStr);

        expect(color.red, equals(255));
        expect(color.green, equals(87));
        expect(color.blue, equals(51));
        expect(color.alpha, equals(255));
      });

      test('parses hex color #AARRGGBB', () {
        const colorStr = '#80FF5733';
        final color = ColorUtils.parseColor(colorStr);

        expect(color.alpha, equals(128));
        expect(color.red, equals(255));
        expect(color.green, equals(87));
        expect(color.blue, equals(51));
      });

      test('parses rgba color', () {
        const colorStr = 'rgba(255, 87, 51, 0.50)';
        final color = ColorUtils.parseColor(colorStr);

        expect(color.red, equals(255));
        expect(color.green, equals(87));
        expect(color.blue, equals(51));
        expect(color.alpha, closeTo(128, 1)); // 0.50 * 255 = 127.5
      });

      test('returns transparent for invalid format', () {
        const colorStr = 'invalid';
        final color = ColorUtils.parseColor(colorStr);

        expect(color, equals(Colors.transparent));
      });
    });

    group('toHex', () {
      test('converts color to hex string', () {
        const color = Color(0xFFFF5733);
        final hex = ColorUtils.toHex(color);

        expect(hex, equals('#ff5733'));
      });

      test('handles alpha correctly', () {
        const color = Color(0x80FF5733);
        final hex = ColorUtils.toHex(color);

        // toHex ignores alpha, only outputs RGB
        expect(hex, equals('#ff5733'));
      });
    });

    group('toRgba', () {
      test('converts color to rgba string', () {
        const color = Color.fromARGB(255, 255, 87, 51);
        final rgba = ColorUtils.toRgba(color);

        expect(rgba, contains('rgba(255, 87, 51,'));
        expect(rgba, contains('1.00'));
      });

      test('handles semi-transparent color', () {
        const color = Color.fromARGB(128, 255, 87, 51);
        final rgba = ColorUtils.toRgba(color);

        expect(rgba, contains('rgba(255, 87, 51,'));
        expect(rgba, contains('0.50'));
      });
    });

    group('round-trip', () {
      test('hex round-trip preserves color', () {
        const original = Color(0xFFFF5733);
        final hex = ColorUtils.toHex(original);
        final parsed = ColorUtils.parseColor(hex);

        // toHex loses alpha, so we compare RGB only
        expect(parsed.red, equals(original.red));
        expect(parsed.green, equals(original.green));
        expect(parsed.blue, equals(original.blue));
      });

      test('rgba round-trip preserves color', () {
        const original = Color.fromARGB(128, 255, 87, 51);
        final rgba = ColorUtils.toRgba(original);
        final parsed = ColorUtils.parseColor(rgba);

        expect(parsed.red, equals(original.red));
        expect(parsed.green, equals(original.green));
        expect(parsed.blue, equals(original.blue));
        expect(parsed.alpha, closeTo(original.alpha, 2)); // Allow small rounding error
      });
    });
  });
}