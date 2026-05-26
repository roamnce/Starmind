// lib/src/pdf/elastic_boundary.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// 弹性边界约束
///
/// 当 PDF 缩小到小于视口时，允许弹性拖动，
/// 拖出边界后有阻力，手势结束后回弹到合法位置。
class ElasticBoundary {
  /// 弹性阻力系数 (0.0 - 1.0)
  static const double elasticity = 0.3;

  /// 触发回弹的阈值（像素）
  static const double snapBackThreshold = 50.0;

  /// 回弹动画时长
  static const Duration snapBackDuration = Duration(milliseconds: 200);

  /// 计算弹性约束后的平移位置
  ///
  /// [pan] 当前平移偏移
  /// [boundary] PDF 边界矩形（在 baseScale 下）
  /// [viewport] 视口矩形
  static Offset constrain(Offset pan, Rect boundary, Rect viewport) {
    double dx = pan.dx;
    double dy = pan.dy;

    // 水平方向约束
    if (boundary.width < viewport.width) {
      // PDF 宽度小于视口，允许弹性拖动
      final centerOffset = (viewport.width - boundary.width) / 2;
      final excess = dx.abs() - centerOffset;
      if (excess > 0) {
        // 超出居中位置，应用弹性阻力
        dx = dx.sign * (centerOffset + excess * elasticity);
      }
    } else {
      // PDF 宽度大于视口，硬边界约束
      final minX = viewport.width - boundary.width;
      final maxX = 0.0;
      dx = dx.clamp(minX, maxX);
    }

    // 垂直方向约束
    if (boundary.height < viewport.height) {
      // PDF 高度小于视口，允许弹性拖动
      final centerOffset = (viewport.height - boundary.height) / 2;
      final excess = dy.abs() - centerOffset;
      if (excess > 0) {
        dy = dy.sign * (centerOffset + excess * elasticity);
      }
    } else {
      // PDF 高度大于视口，硬边界约束
      final minY = viewport.height - boundary.height;
      final maxY = 0.0;
      dy = dy.clamp(minY, maxY);
    }

    return Offset(dx, dy);
  }

  /// 手势结束后计算回弹目标位置
  ///
  /// 如果当前位置超出合法范围，返回需要回弹到的目标位置。
  /// 对于 PDF 小于视口的情况，回弹到居中位置。
  static Offset snapBack(Offset pan, Rect boundary, Rect viewport) {
    double dx = pan.dx;
    double dy = pan.dy;

    // 水平方向回弹
    if (boundary.width < viewport.width) {
      // PDF 宽度小于视口，回弹到居中范围
      final centerOffset = (viewport.width - boundary.width) / 2;
      dx = dx.clamp(-centerOffset, centerOffset);
    } else {
      // PDF 宽度大于视口，硬边界约束
      final minX = viewport.width - boundary.width;
      final maxX = 0.0;
      dx = dx.clamp(minX, maxX);
    }

    // 垂直方向回弹
    if (boundary.height < viewport.height) {
      // PDF 高度小于视口，回弹到居中范围
      final centerOffset = (viewport.height - boundary.height) / 2;
      dy = dy.clamp(-centerOffset, centerOffset);
    } else {
      // PDF 高度大于视口，硬边界约束
      final minY = viewport.height - boundary.height;
      final maxY = 0.0;
      dy = dy.clamp(minY, maxY);
    }

    return Offset(dx, dy);
  }

  /// 判断是否需要回弹动画
  static bool needsSnapBack(Offset pan, Rect boundary, Rect viewport) {
    final constrained = constrain(pan, boundary, viewport);
    return (constrained - pan).distance > snapBackThreshold;
  }
}
