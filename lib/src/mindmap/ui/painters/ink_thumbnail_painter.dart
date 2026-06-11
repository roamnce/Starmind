// lib/src/mindmap/ui/painters/ink_thumbnail_painter.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../ink/ink_layer.dart';
import '../../ink/stroke_renderer.dart';

/// 墨迹缩略图绘制器。
///
/// 将 [InkLayer] 的笔画渲染到 48x48 的 [ui.Image] 中，
/// 用于节点卡片上的手写墨迹缩略图显示。
class InkThumbnailPainter {
  const InkThumbnailPainter._();

  /// 缩略图尺寸。
  static const double thumbnailSize = 48.0;

  /// 将 [InkLayer] 渲染为缩略图 [ui.Image]。
  ///
  /// 渲染流程：
  /// 1. 计算所有笔画的边界矩形
  /// 2. 创建 [ui.PictureRecorder]
  /// 3. 缩放和平移笔画到 48x48 视口
  /// 4. 调用 [StrokeRenderer.drawStroke] 渲染每条笔画
  /// 5. 将 [ui.Picture] 转为 [ui.Image]
  ///
  /// @param layer 包含笔画的墨迹层。
  /// @return 48x48 的缩略图 [ui.Image]。
  static Future<ui.Image> buildThumbnail(InkLayer layer) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 计算所有笔画的边界
    final bounds = _calculateBounds(layer.strokes);

    // 如果没有笔画，返回空白透明图像
    if (bounds.isEmpty || layer.strokes.isEmpty) {
      final picture = recorder.endRecording();
      return picture.toImage(48, 48);
    }

    // 计算缩放因子，使笔画填满缩略图视口（留 4px 边距）
    final padding = 4.0;
    final scaleX = (thumbnailSize - 2 * padding) / bounds.width;
    final scaleY = (thumbnailSize - 2 * padding) / bounds.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // 计算平移，使笔画居中
    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;
    final offsetX = padding + (thumbnailSize - 2 * padding - scaledWidth) / 2;
    final offsetY = padding + (thumbnailSize - 2 * padding - scaledHeight) / 2;

    // 应用变换：先平移到原点，再缩放，再平移到视口中心
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);
    canvas.translate(-bounds.left, -bounds.top);

    // 渲染所有笔画
    for (final stroke in layer.strokes) {
      StrokeRenderer.drawStroke(canvas, stroke);
    }

    final picture = recorder.endRecording();
    return picture.toImage(48, 48);
  }

  /// 计算所有笔画的合并边界矩形。
  ///
  /// @param strokes 笔画列表。
  /// @return 所有笔画的合并边界；无笔画时返回 [Rect.zero]。
  static Rect _calculateBounds(List<InkStroke> strokes) {
    if (strokes.isEmpty) return Rect.zero;

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final stroke in strokes) {
      final strokeBounds = stroke.bounds;
      if (strokeBounds.isEmpty) continue;
      if (strokeBounds.left < left) left = strokeBounds.left;
      if (strokeBounds.top < top) top = strokeBounds.top;
      if (strokeBounds.right > right) right = strokeBounds.right;
      if (strokeBounds.bottom > bottom) bottom = strokeBounds.bottom;
    }

    if (left == double.infinity) return Rect.zero;
    return Rect.fromLTRB(left, top, right, bottom);
  }
}