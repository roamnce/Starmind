// test/mindmap/layout/layout_config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/layout/layout_config.dart';
import 'package:starmind/src/mindmap/layout/layout_result.dart';
import 'dart:ui';

void main() {
  group('LayoutConfig', () {
    test('default config has correct values', () {
      const config = LayoutConfig.defaultConfig;

      expect(config.strategy, LayoutStrategy.bothSides);
      expect(config.nodeWidth, 120.0);
      expect(config.nodeHeight, 40.0);
      expect(config.horizontalSpacing, 60.0);
      expect(config.verticalSpacing, 30.0);
    });

    test('getNodeSize returns custom size when provided', () {
      final customSizes = {'node-1': const Size(200, 60)};
      final config = LayoutConfig(customNodeSizes: customSizes);

      expect(config.getNodeSize('node-1'), const Size(200, 60));
      expect(config.getNodeSize('node-2'), const Size(120, 40));
    });

    test('copyWith creates modified copy', () {
      const original = LayoutConfig.defaultConfig;
      final modified = original.copyWith(nodeWidth: 150.0);

      expect(modified.nodeWidth, 150.0);
      expect(modified.nodeHeight, original.nodeHeight);
    });
  });

  group('ConnectionData', () {
    test('isRightward returns true for rightward connection', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(0, 0),
        endPoint: Offset(100, 0),
        fromCenter: Offset(0, 0),
        toCenter: Offset(100, 0),
      );

      expect(conn.isRightward, isTrue);
      expect(conn.isLeftward, isFalse);
    });

    test('isLeftward returns true for leftward connection', () {
      const conn = ConnectionData(
        fromId: 'a',
        toId: 'b',
        startPoint: Offset(100, 0),
        endPoint: Offset(0, 0),
        fromCenter: Offset(100, 0),
        toCenter: Offset(0, 0),
      );

      expect(conn.isLeftward, isTrue);
      expect(conn.isRightward, isFalse);
    });
  });

  group('LayoutResult', () {
    test('empty result has no nodes', () {
      expect(LayoutResult.empty.nodePositions, isEmpty);
      expect(LayoutResult.empty.nodeSizes, isEmpty);
      expect(LayoutResult.empty.connections, isEmpty);
    });

    test('getNodeRect returns correct rect', () {
      final result = LayoutResult(
        nodePositions: {'node-1': const Offset(100, 50)},
        nodeSizes: {'node-1': const Size(120, 40)},
        connections: [],
        contentBounds: Rect.zero,
      );

      final rect = result.getNodeRect('node-1');
      expect(rect, isNotNull);
      expect(rect!.left, 40);  // 100 - 120/2
      expect(rect.top, 30);    // 50 - 40/2
      expect(rect.right, 160); // 100 + 120/2
      expect(rect.bottom, 70); // 50 + 40/2
    });
  });
}