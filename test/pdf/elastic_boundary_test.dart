// test/pdf/elastic_boundary_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/elastic_boundary.dart';

void main() {
  group('ElasticBoundary', () {
    test('constrains pan when PDF width smaller than viewport', () {
      // PDF 宽度 400，视口宽度 800
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);

      // 允许居中偏移，但有弹性阻力
      final pan = Offset(100, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);

      // 预期：居中偏移 200 是允许的，超出部分有弹性阻力
      // 100 < 200，所以应该允许
      expect(result.dx, lessThanOrEqualTo(200));
    });

    test('applies elastic resistance when pan exceeds center offset', () {
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);

      // 超出居中偏移 200
      final pan = Offset(300, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);

      // 预期：200 + (300-200) * 0.3 = 230
      expect(result.dx, closeTo(230, 1));
    });

    test('hard constraint when PDF width larger than viewport', () {
      final boundary = Rect.fromLTWH(0, 0, 1200, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);

      final pan = Offset(100, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);

      // 硬边界：minX = 800 - 1200 = -400, maxX = 0
      expect(result.dx, inInclusiveRange(-400, 0));
    });

    test('snapBack returns constrained position', () {
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);

      // 拖出边界
      final pan = Offset(500, 0);
      final result = ElasticBoundary.snapBack(pan, boundary, viewport);

      // 应该回弹到合法位置
      final centerOffset = (viewport.width - boundary.width) / 2;
      expect(result.dx.abs(), lessThanOrEqualTo(centerOffset));
    });

    test('vertical constraint works similarly', () {
      final boundary = Rect.fromLTWH(0, 0, 600, 400);
      final viewport = Rect.fromLTWH(0, 0, 600, 800);

      final pan = Offset(0, 300);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);

      final centerOffset = (viewport.height - boundary.height) / 2;
      expect(result.dy.abs(), lessThanOrEqualTo(centerOffset * 1.5));
    });
  });
}
