import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/rendering/bezier_renderer.dart';
import 'package:starmind/src/mindmap/layout/layout_result.dart';
import 'dart:ui';

void main() {
  group('BezierConnectionRenderer', () {
    late BezierConnectionRenderer renderer;

    setUp(() {
      renderer = BezierConnectionRenderer();
    });

    test('name returns Bezier', () {
      expect(renderer.name, 'Bezier');
    });

    test('createPath starts at startPoint', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 50),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 50),
      );

      final path = renderer.createPath(conn);
      final bounds = path.getBounds();

      expect(bounds.left, 0);
      expect(bounds.top, lessThanOrEqualTo(50));
    });

    test('createPath ends at endPoint', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 50),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 50),
      );

      final path = renderer.createPath(conn);
      final bounds = path.getBounds();

      expect(bounds.right, 100);
      expect(bounds.bottom, greaterThanOrEqualTo(0));
    });

    test('createPath creates smooth curve', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 0),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 0),
      );

      final path = renderer.createPath(conn);
      expect(path.computeMetrics().length, greaterThan(0));
    });

    test('createPath handles leftward connection', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(100, 0),
        endPoint: Offset(0, 0),
        fromCenter: Offset(100, 0),
        toCenter: Offset(0, 0),
      );

      final path = renderer.createPath(conn);
      final bounds = path.getBounds();

      expect(bounds.left, lessThanOrEqualTo(0));
      expect(bounds.right, greaterThanOrEqualTo(100));
    });
  });
}