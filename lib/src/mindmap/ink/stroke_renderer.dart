import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'ink_layer.dart';

/// Catmull-Rom + 变宽笔画的离线渲染器。
///
/// 输入是 [InkStroke] 的原始点序列，输出是一条已平滑、可填充或描边的 [Path]。
/// 渲染流水线为：filterPoints → smoothPoints → spline 采样 → 变宽包围。
///
/// 设计目标是 GoodNotes 级别的视觉体验：抖动点过滤、加权移动平均平滑、
/// Catmull-Rom 样条插值、首尾压感渐变。所有方法都是无状态静态方法，便于
/// 直接在 [CustomPainter.paint] 里复用。
class StrokeRenderer {
  const StrokeRenderer._();

  /// 过滤距上一保留点 < 0.5px 的抖动点。
  ///
  /// 用于抑制硬件采样的颤动，避免 Catmull-Rom 样条在密集点上产生折角。
  ///
  /// @param points 原始点序列。
  /// @return 过滤后的点序列；输入为空时返回空列表。
  static List<InkPoint> filterPoints(List<InkPoint> points) {
    if (points.isEmpty) return const [];
    final filtered = <InkPoint>[points.first];
    for (int i = 1; i < points.length; i++) {
      final dist = (points[i].offset - filtered.last.offset).distance;
      if (dist > 0.5) filtered.add(points[i]);
    }
    return filtered;
  }

  /// 对内部点做 0.25 / 0.5 / 0.25 加权移动平均。
  ///
  /// 首尾点不变。压感同步平滑。点数 < 3 时直接原样返回。
  static List<InkPoint> smoothPoints(List<InkPoint> pts) {
    if (pts.length < 3) return List<InkPoint>.unmodifiable(pts);
    final smoothed = <InkPoint>[pts.first];
    for (int i = 1; i < pts.length - 1; i++) {
      final x = pts[i - 1].x * 0.25 + pts[i].x * 0.5 + pts[i + 1].x * 0.25;
      final y = pts[i - 1].y * 0.25 + pts[i].y * 0.5 + pts[i + 1].y * 0.25;
      final p = pts[i - 1].pressure * 0.25 +
          pts[i].pressure * 0.5 +
          pts[i + 1].pressure * 0.25;
      smoothed.add(InkPoint(x, y, pressure: p));
    }
    smoothed.add(pts.last);
    return smoothed;
  }

  /// 用 Catmull-Rom 样条生成等弧长采样的路径（用于荧光笔等等宽渲染）。
  ///
  /// 点数 < 4 时退化为 `moveTo + lineTo`。采样密度 = max(64, totalDist / 0.5)。
  static Path catmullRomPath(List<InkPoint> points, double baseWidth) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length < 4) {
      path.moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      return path;
    }

    final spline = CatmullRomSpline(points.map((p) => p.offset).toList());
    final totalDist = _totalDistance(points);
    final samples = math.max(64, (totalDist / 0.5).round());

    path.moveTo(points.first.x, points.first.y);
    for (int i = 1; i <= samples; i++) {
      final t = i / samples;
      final p = spline.transform(t);
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// 用 Catmull-Rom 中线 + 法向偏移构建变宽笔画的闭合多边形。
  ///
  /// 首尾 20% 区段做压感渐变，避免笔尖突起。点数 < 4 时退化为简单
  /// 变宽多边形（[_simpleVariablePath]）。
  static Path variableWidthPath(List<InkPoint> points, double baseWidth) {
    if (points.length < 4) {
      return _simpleVariablePath(points, baseWidth);
    }

    final processed = smoothPoints(filterPoints(points));
    if (processed.length < 4) {
      return _simpleVariablePath(processed, baseWidth);
    }

    final spline = CatmullRomSpline(processed.map((p) => p.offset).toList());
    final totalDist = _totalDistance(processed);
    final samples = math.max(64, (totalDist / 0.5).round());

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    final taperSamples = math.max(1, (samples * 0.2).round());

    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final point = spline.transform(t);

      // 沿 processed 数组定位压感
      final segIdx =
          (t * (processed.length - 1)).floor().clamp(0, processed.length - 2);
      final localT =
          (t * (processed.length - 1) - segIdx).clamp(0.0, 1.0);
      var width = lerpDouble(
            processed[segIdx].pressure * baseWidth,
            processed[segIdx + 1].pressure * baseWidth,
            localT,
          ) ??
          baseWidth;

      // 首尾渐变
      if (i < taperSamples) {
        width *= i / taperSamples;
      } else if (i > samples - taperSamples) {
        width *= (samples - i) / taperSamples;
      }
      if (width < 0.1) width = 0.1;

      // 切向 → 法向
      final Offset tangent;
      if (i == 0) {
        tangent = spline.transform(1 / samples) - point;
      } else if (i == samples) {
        tangent = point - spline.transform((samples - 1) / samples);
      } else {
        tangent =
            spline.transform((i + 1) / samples) - spline.transform((i - 1) / samples);
      }
      final len = tangent.distance;
      final normal =
          len < 0.0001 ? Offset.zero : Offset(-tangent.dy, tangent.dx) / len;

      leftPoints.add(point + normal * (width / 2));
      rightPoints.add(point - normal * (width / 2));
    }

    final path = Path()..moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (final p in leftPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in rightPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  /// 点数 < 4 时的退化变宽实现：用线段端点法向构建简易四边形条带。
  static Path _simpleVariablePath(List<InkPoint> points, double baseWidth) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      final p = points.first.offset;
      final r = (baseWidth * points.first.pressure) / 2;
      path.addOval(Rect.fromCircle(center: p, radius: math.max(0.5, r)));
      return path;
    }

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i].offset;
      final Offset tangent;
      if (i == 0) {
        tangent = points[1].offset - p;
      } else if (i == points.length - 1) {
        tangent = p - points[i - 1].offset;
      } else {
        tangent = points[i + 1].offset - points[i - 1].offset;
      }
      final len = tangent.distance;
      final normal =
          len < 0.0001 ? Offset.zero : Offset(-tangent.dy, tangent.dx) / len;
      final width = (baseWidth * points[i].pressure).clamp(0.5, baseWidth * 2);
      leftPoints.add(p + normal * (width / 2));
      rightPoints.add(p - normal * (width / 2));
    }

    path.moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (final p in leftPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in rightPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  static double _totalDistance(List<InkPoint> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i + 1].offset - points[i].offset).distance;
    }
    return total;
  }

  /// 在 [canvas] 上按 [stroke] 的工具类型选择渲染策略。
  ///
  /// - [InkTool.pen]：变宽填充多边形 + 0.5px 同色描边消除多边形锯齿。
  /// - [InkTool.highlighter]：Catmull-Rom 折线 + 半透明粗线 + srcOver。
  /// - [InkTool.eraser]：BlendMode.clear 的变宽多边形。
  /// - [InkTool.lasso]：作为选择手势，不由本方法绘制。
  ///
  /// 点数 < 2 时不绘制。
  static void drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.length < 2) return;

    final processed = smoothPoints(filterPoints(stroke.points));

    switch (stroke.tool) {
      case InkTool.highlighter:
        final paint = Paint()
          ..color = Color(stroke.color).withValues(alpha: 0.35)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..blendMode = BlendMode.srcOver
          ..strokeWidth = stroke.width;
        canvas.drawPath(catmullRomPath(processed, stroke.width), paint);
        break;
      case InkTool.eraser:
        final paint = Paint()
          ..color = const Color(0xFF000000)
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.clear;
        canvas.drawPath(variableWidthPath(processed, stroke.width * 2), paint);
        break;
      case InkTool.pen:
        final fillPaint = Paint()
          ..color = Color(stroke.color)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..style = PaintingStyle.fill;
        final path = variableWidthPath(processed, stroke.width);
        canvas.drawPath(path, fillPaint);
        final edgePaint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = 0.5
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, edgePaint);
        break;
      case InkTool.lasso:
        // 套索是选择手势，由 UI 层 LassoSelector 负责，不在此渲染。
        break;
    }
  }
}
