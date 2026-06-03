// test/pdf/gesture_dispatcher_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/gesture_dispatcher.dart';

void main() {
  group('GestureDispatcher', () {
    late GestureDispatcher dispatcher;

    setUp(() {
      dispatcher = GestureDispatcher();
    });

    test('identifies draw gesture for single stylus', () {
      final details = ScaleStartDetails(
        localFocalPoint: Offset.zero,
        focalPoint: Offset.zero,
        pointerCount: 1,
      );

      dispatcher.inkModeEnabled = true;
      final isDraw = dispatcher.isDrawGesture(details, PointerDeviceKind.stylus);

      expect(isDraw, true);
    });

    test('identifies navigation gesture for two fingers', () {
      final details = ScaleStartDetails(
        localFocalPoint: Offset.zero,
        focalPoint: Offset.zero,
        pointerCount: 2,
      );

      dispatcher.inkModeEnabled = true;
      final isDraw = dispatcher.isDrawGesture(details, PointerDeviceKind.touch);

      expect(isDraw, false);
    });

    test('cancels drawing when second finger added', () {
      dispatcher.inkModeEnabled = true;

      // 第一个手指按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, true);
      expect(dispatcher.drawingPointerId, 0);

      // 第二个手指按下
      dispatcher.onPointerDown(1, PointerDeviceKind.touch, const Offset(100, 100));

      // 应该取消绘制
      expect(dispatcher.isDrawing, false);
      expect(dispatcher.drawingPointerId, isNull);
    });

    test('resumes drawing after all fingers lifted', () {
      dispatcher.inkModeEnabled = true;

      // 两个手指按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      dispatcher.onPointerDown(1, PointerDeviceKind.touch, const Offset(100, 100));

      // 第一个手指抬起
      dispatcher.onPointerUp(1);
      expect(dispatcher.activePointerCount, 1);

      // 第二个手指抬起
      dispatcher.onPointerUp(0);
      expect(dispatcher.activePointerCount, 0);
      expect(dispatcher.isDrawing, false);

      // 再次按下可以开始绘制
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, true);
    });

    test('stylus takes priority over touch', () {
      dispatcher.inkModeEnabled = true;
      dispatcher.palmRejectionEnabled = true;

      // 触摸按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, false); // palm rejection

      // 触控笔按下
      dispatcher.onPointerDown(1, PointerDeviceKind.stylus, const Offset(100, 100));
      expect(dispatcher.isDrawing, true);
      expect(dispatcher.drawingPointerId, 1);
    });
  });
}
