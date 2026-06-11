import 'dart:math' show min;
import 'package:flutter/material.dart';

/// 视口状态与操作。
///
/// 管理缩放、平移、适应屏幕等视口相关功能。
/// 深度模块：小接口，大实现（缩放限制、适应算法）。
class MindMapViewportController extends ChangeNotifier {
  /// 缩放限制
  static const double minScale = 0.1;
  static const double maxScale = 4.0;
  static const double zoomStep = 1.2;

  double _scale = 1.0;
  Offset _offset = Offset.zero;

  double get scale => _scale;
  Offset get offset => _offset;

  /// 放大
  void zoomIn() {
    _scale = (_scale * zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 缩小
  void zoomOut() {
    _scale = (_scale / zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 设置缩放
  void setZoom(double value) {
    _scale = value.clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 平移
  void pan(Offset delta) {
    _offset = _offset + delta;
    notifyListeners();
  }

  /// 设置偏移
  void setOffset(Offset value) {
    _offset = value;
    notifyListeners();
  }

  /// 重置视口
  void reset() {
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// 适应屏幕（根据边界框计算合适的缩放和偏移）
  void fitToScreen(Size screenSize, Rect contentBounds) {
    if (contentBounds.isEmpty) return;

    final scaleX = screenSize.width / contentBounds.width;
    final scaleY = screenSize.height / contentBounds.height;
    _scale = min(scaleX, scaleY) * 0.9; // 留 10% 边距

    // 确保缩放比例在有效范围内
    _scale = _scale.clamp(minScale, maxScale);

    // 居中
    _offset = Offset(
      (screenSize.width - contentBounds.width * _scale) / 2,
      (screenSize.height - contentBounds.height * _scale) / 2,
    );

    notifyListeners();
  }
}
