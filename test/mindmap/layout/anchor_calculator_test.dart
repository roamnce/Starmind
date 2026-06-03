// test/mindmap/layout/anchor_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/layout/anchor_calculator.dart';
import 'dart:ui';

void main() {
  group('AnchorCalculator', () {
    test('calculateAnchorPoint returns right edge anchor for rightward connection', () {
      final anchor = AnchorCalculator.calculateAnchorPoint(
        nodeCenter: const Offset(0, 0),
        nodeSize: const Size(100, 40),
        targetCenter: const Offset(200, 0),
      );

      // 锚点应在右边缘中心：x = 0 + 100/2 = 50
      expect(anchor.dx, 50);
      expect(anchor.dy, 0);
    });

    test('calculateAnchorPoint returns left edge anchor for leftward connection', () {
      final anchor = AnchorCalculator.calculateAnchorPoint(
        nodeCenter: const Offset(200, 0),
        nodeSize: const Size(100, 40),
        targetCenter: const Offset(0, 0),
      );

      // 锚点应在左边缘中心：x = 200 - 100/2 = 150
      expect(anchor.dx, 150);
      expect(anchor.dy, 0);
    });

    test('calculateAnchorPoint handles vertical offset', () {
      final anchor = AnchorCalculator.calculateAnchorPoint(
        nodeCenter: const Offset(100, 100),
        nodeSize: const Size(120, 40),
        targetCenter: const Offset(300, 50),
      );

      // Y 坐标应为节点中心 Y
      expect(anchor.dy, 100);
      // X 应为右边缘
      expect(anchor.dx, 160); // 100 + 120/2
    });

    test('calculateAnchorPair returns correct anchor pair', () {
      final (startAnchor, endAnchor) = AnchorCalculator.calculateAnchorPair(
        fromCenter: const Offset(0, 0),
        fromSize: const Size(100, 40),
        toCenter: const Offset(200, 0),
        toSize: const Size(80, 30),
      );

      // 起点：右边缘
      expect(startAnchor.dx, 50);  // 0 + 100/2
      expect(startAnchor.dy, 0);

      // 终点：左边缘
      expect(endAnchor.dx, 160);  // 200 - 80/2
      expect(endAnchor.dy, 0);
    });

    test('calculateEdgeAnchors returns all four edge anchors', () {
      final anchors = AnchorCalculator.calculateEdgeAnchors(
        nodeCenter: const Offset(100, 50),
        nodeSize: const Size(120, 40),
      );

      // 左锚点：x = 100 - 60 = 40
      expect(anchors.left.dx, 40);
      expect(anchors.left.dy, 50);

      // 右锚点：x = 100 + 60 = 160
      expect(anchors.right.dx, 160);
      expect(anchors.right.dy, 50);

      // 上锚点：y = 50 - 20 = 30
      expect(anchors.top.dx, 100);
      expect(anchors.top.dy, 30);

      // 下锚点：y = 50 + 20 = 70
      expect(anchors.bottom.dx, 100);
      expect(anchors.bottom.dy, 70);
    });
  });
}