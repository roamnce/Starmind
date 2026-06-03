import 'package:flutter/gestures.dart';

/// 手势分发器
///
/// 区分绘制手势与导航手势，解决多指手势冲突。
///
/// 规则：
/// - 单指 + 批注模式 = 绘制手势
/// - 双指 = 缩放/平移手势（导航）
/// - 多指切换时取消当前绘制
/// - 触控笔优先（palm rejection）
///
/// 参考：Saber CanvasGestureDetector
class GestureDispatcher {
  /// 活跃的指针集合
  final Set<int> _activePointers = {};

  /// 正在绘制的指针 ID
  int? _drawingPointerId;

  /// 是否正在绘制
  bool _isDrawing = false;

  /// 是否启用手写批注模式
  bool inkModeEnabled = false;

  /// 是否启用手掌拒绝（仅接受触控笔）
  bool palmRejectionEnabled = false;

  /// 当前活跃指针数量
  int get activePointerCount => _activePointers.length;

  /// 是否正在绘制
  bool get isDrawing => _isDrawing;

  /// 正在绘制的指针 ID
  int? get drawingPointerId => _drawingPointerId;

  /// 判断是否为绘制手势
  bool isDrawGesture(ScaleStartDetails details, PointerDeviceKind deviceKind) {
    // 多指不是绘制手势
    if (details.pointerCount >= 2) return false;

    // 批注模式未开启，不是绘制手势
    if (!inkModeEnabled) return false;

    // 手掌拒绝模式下，仅接受触控笔
    if (palmRejectionEnabled && deviceKind != PointerDeviceKind.stylus) {
      return false;
    }

    return true;
  }

  /// 指针按下
  void onPointerDown(int pointerId, PointerDeviceKind kind, Offset position) {
    _activePointers.add(pointerId);

    // 触控笔优先：如果启用手掌拒绝且当前是触控笔，强制切换到触控笔绘制
    if (palmRejectionEnabled && kind == PointerDeviceKind.stylus) {
      _drawingPointerId = pointerId;
      _isDrawing = true;
      return;
    }

    // 多指优先：当有2+指针时，取消绘制
    if (_activePointers.length >= 2) {
      if (_drawingPointerId != null) {
        _cancelDrawing();
      }
      return;
    }

    // 单指针且在批注模式，开始绘制
    if (_activePointers.length == 1 &&
        inkModeEnabled &&
        _drawingPointerId == null) {
      // 手掌拒绝检查
      if (palmRejectionEnabled && kind != PointerDeviceKind.stylus) {
        return;
      }

      _drawingPointerId = pointerId;
      _isDrawing = true;
    }
  }

  /// 指针移动
  bool onPointerMove(int pointerId, Offset position) {
    return _drawingPointerId == pointerId && _isDrawing;
  }

  /// 指针抬起
  void onPointerUp(int pointerId) {
    _activePointers.remove(pointerId);

    if (_drawingPointerId == pointerId) {
      _drawingPointerId = null;
      _isDrawing = false;
    }
  }

  /// 指针取消
  void onPointerCancel(int pointerId) {
    _activePointers.remove(pointerId);

    if (_drawingPointerId == pointerId) {
      _cancelDrawing();
    }
  }

  /// 取消绘制
  void _cancelDrawing() {
    _drawingPointerId = null;
    _isDrawing = false;
  }

  /// 重置状态
  void reset() {
    _activePointers.clear();
    _drawingPointerId = null;
    _isDrawing = false;
  }
}
