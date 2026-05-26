// test/pdf/viewport_repaint_notifier_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/viewport_repaint_notifier.dart';

void main() {
  group('ViewportRepaintNotifier', () {
    test('initializes with default values', () {
      final notifier = ViewportRepaintNotifier();

      expect(notifier.zoom, 1.0);
      expect(notifier.panOffset, Offset.zero);
    });

    test('updateViewport notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var notified = false;

      notifier.addListener(() {
        notified = true;
      });

      notifier.updateViewport(const Offset(10, 20), 1.5);

      expect(notified, true);
      expect(notifier.zoom, 1.5);
      expect(notifier.panOffset, const Offset(10, 20));
    });

    test('setZoom notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var callCount = 0;

      notifier.addListener(() => callCount++);

      notifier.setZoom(2.0);

      expect(callCount, 1);
      expect(notifier.zoom, 2.0);
    });

    test('setPanOffset notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var callCount = 0;

      notifier.addListener(() => callCount++);

      notifier.setPanOffset(const Offset(100, 200));

      expect(callCount, 1);
      expect(notifier.panOffset, const Offset(100, 200));
    });

    test('getTransform returns Matrix4', () {
      final notifier = ViewportRepaintNotifier();
      notifier.setZoom(2.0);
      notifier.setPanOffset(const Offset(50, 100));

      final transform = notifier.getTransform();

      expect(transform, isA<Matrix4>());
      // 验证矩阵包含缩放和平移
      expect(transform.getMaxScaleOnAxis(), 2.0);
    });
  });
}
