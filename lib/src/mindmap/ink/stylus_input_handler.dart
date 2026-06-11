import 'package:flutter/gestures.dart';

/// Android Stylus 压感输入处理器。
///
/// 提供触控笔类型判断、压力值获取、手掌误触检测等功能。
/// 在手写模式下配合 [Listener] 使用，绕过 [GestureDetector] 的限制，
/// 直接从 [PointerEvent] 获取压感数据。
class StylusInputHandler {
  /// 判断是否为触控笔输入（包括橡皮擦端）。
  ///
  /// Android 平台上，触控笔的 `kind` 为 [PointerDeviceKind.stylus]
  /// 或 [PointerDeviceKind.invertedStylus]（橡皮擦端）。
  static bool isStylusPointer(PointerEvent event) {
    return event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
  }

  /// 获取压感值。
  ///
  /// 对于触控笔输入，返回 [event.pressure]（已 clamp 到 0.0-1.0）。
  /// 对于非触控笔输入（手指、鼠标），返回默认值 1.0。
  static double getPressure(PointerEvent event) {
    if (isStylusPointer(event)) {
      return event.pressure.clamp(0.0, 1.0);
    }
    return 1.0;
  }

  /// 检测是否为手掌误触。
  ///
  /// 手掌触控的特征：`kind` 为 [PointerDeviceKind.touch] 且 `size` 较大。
  /// 阈值 0.05 为经验值，可根据实际设备调整。
  static bool isPalmTouch(PointerEvent event) {
    return event.kind == PointerDeviceKind.touch && event.size > 0.05;
  }
}