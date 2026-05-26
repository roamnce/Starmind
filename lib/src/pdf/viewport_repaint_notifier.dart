import 'package:flutter/material.dart';

/// 视口重绘通知器
///
/// 使用 ValueNotifier 直接触发 CustomPainter 重绘，
/// 跳过 Widget 重建和 Layout 计算，提升缩放/平移性能。
///
/// 参考：HandWriter ActiveStrokeNotifier
class ViewportRepaintNotifier extends ChangeNotifier {
  Offset _panOffset = Offset.zero;
  double _zoom = 1.0;

  /// 当前缩放级别
  double get zoom => _zoom;

  /// 当前平移偏移
  Offset get panOffset => _panOffset;

  /// 更新视口状态并通知监听器
  void updateViewport(Offset pan, double zoom) {
    _panOffset = pan;
    _zoom = zoom;
    notifyListeners();
  }

  /// 设置缩放级别
  void setZoom(double value) {
    if (_zoom != value) {
      _zoom = value;
      notifyListeners();
    }
  }

  /// 设置平移偏移
  void setPanOffset(Offset value) {
    if (_panOffset != value) {
      _panOffset = value;
      notifyListeners();
    }
  }

  /// 获取变换矩阵
  Matrix4 getTransform() {
    return Matrix4.identity()
      ..translate(_panOffset.dx, _panOffset.dy)
      ..scale(_zoom, _zoom);
  }

  /// 重置为默认状态
  void reset() {
    _panOffset = Offset.zero;
    _zoom = 1.0;
    notifyListeners();
  }
}
