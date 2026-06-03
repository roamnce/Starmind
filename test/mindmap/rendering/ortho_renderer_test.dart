import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/rendering/ortho_renderer.dart';
import 'package:starmind/src/mindmap/layout/layout_result.dart';
import 'dart:ui';

void main() {
  group('OrthoConnectionRenderer', () {
    late OrthoConnectionRenderer renderer;

    setUp(() {
      renderer = OrthoConnectionRenderer();
    });

    test('name returns Ortho', () {
      expect(renderer.name, 'Ortho');
    });

    test('createPath creates three-segment polyline', () {
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
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 50);
    });

    test('createPath handles horizontal connection', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 0),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 0),
      );

      final path = renderer.createPath(conn);
      final bounds = path.getBounds();

      expect(bounds.height, 0);
      expect(bounds.width, 100);
    });

    test('createPath handles vertical offset', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 100),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 100),
      );

      final path = renderer.createPath(conn);
      final bounds = path.getBounds();

      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 100);
    });
  });
}