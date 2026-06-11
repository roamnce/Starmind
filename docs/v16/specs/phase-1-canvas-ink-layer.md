# Phase 1: 手写画布层集成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按 task 推进。所有 Step 用 `- [ ]` checkbox 跟踪。

**Goal:** 在思维导图画布上集成 GoodNotes 级别的手写体验：Catmull-Rom 平滑、输入稳定、Android Stylus 压感、实时持久化、节点级入口。

**Architecture:** 沿用现有 `lib/src/mindmap/ink/` 结构（`InkLayer` / `InkStroke` / `InkLayerController` 已就绪，`FfiInkLayerRepository` + Rust `ink_layers` 表 + `mindmap_save_ink_layer` FFI 已实现），本 Phase 在此之上做：（1）渲染算法升级到 Catmull-Rom + 变宽笔画；（2）`InkLayerController` 注入 `StrokeStabilizer`；（3）`Listener` 替换 GestureDetector 拿到压感；（4）`MindMapController.interactMode` 扩出 `ink`（**单一状态，不引入 `_isInkMode` 副本**）；（5）endStroke 后通过 `FfiInkLayerRepository.saveInkLayer` 实时落库（**不重建 schema**）；（6）`NodeWidget` 长按悬浮菜单接入节点级手写。

**Tech Stack:** Flutter + `flutter_rust_bridge` 2.12，`CatmullRomSpline` (`dart:ui`)，`Listener`/`PointerEvent`，已有 `rusqlite` ink_layers 表。

---

## 背景

现有 `ink_layer.dart` 已定义基础模型：
- `InkStroke`: 单条笔画（点序列 + 工具 + 颜色 + 宽度）
- `InkLayer`: 手写层（归属 canvas 或 node）
- `InkTool`: 笔/荧光笔/橡皮/套索

但渲染使用直线连接，体验粗糙。需升级为 Catmull-Rom 样条 + 变宽笔画。

## 设计决策

### 入口位置（用户确认）
- **全局手写**：底部工具栏新增「笔」按钮，类似「拖动」「套索」
- **节点级手写**：选中节点后长按弹出悬浮菜单

### 渲染算法（用户确认）
- 使用 **Catmull-Rom 样条** 插值
- 参考 `scribe_canvas` 的 `StrokeRendererUtil`
- 参考 `fluera_canvas` 的 `StrokeStabilizer`

### 持久化（用户确认）
- 实时保存：笔画完成立即写入数据库

### 压感平台（用户确认）
- 仅支持 Android Stylus

## 文件结构

```
lib/src/mindmap/
├── ink/
│   ├── ink_layer.dart                  # 现有，扩展
│   ├── ink_layer_controller.dart       # 现有，扩展
│   ├── canvas_ink_layer.dart           # 现有，重写渲染
│   ├── stroke_renderer.dart            # 新增，渲染算法
│   ├── stroke_stabilizer.dart          # 新增，输入稳定
│   └── stylus_input_handler.dart       # 新增，压感处理
├── ui/
│   ├── mindmap_page.dart               # 修改，集成手写层
│   ├── bottom_action_bar.dart          # 修改，新增「笔」按钮
│   ├── components/
│   │   ├── ink_toolbar.dart            # 新增，手写工具栏
│   │   └── node_context_menu.dart      # 新增，节点悬浮菜单
│   └── painters/
│       └── ink_painter.dart            # 新增，墨迹绘制器
└── storage/
    └── ink_layer_repository.dart       # 现有，扩展实时保存

rust/src/storage/
├── db.rs                               # 修改，新增 ink_layers 表
└── ink.rs                              # 新增，存储操作
```

## Phase 拆分

由于本 Phase 涉及多个子系统，拆分为独立 Plan：

1. **Plan 1-A**: 墨迹渲染升级（Catmull-Rom + 变宽笔画）
2. **Plan 1-B**: 输入稳定器（String Pulling + Moving Average）
3. **Plan 1-C**: 压感支持（Android Stylus）
4. **Plan 1-D**: 工具栏集成（全局手写入口）
5. **Plan 1-E**: 持久化（实时保存）
6. **Plan 1-F**: 节点级手写入口

每个 Plan 可独立实现和测试。

---

## Plan 1-A: 墨迹渲染升级

**文件:**
- 创建: `lib/src/mindmap/ink/stroke_renderer.dart`
- 修改: `lib/src/mindmap/ink/canvas_ink_layer.dart:54-80`
- 测试: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/mindmap/ink/stroke_renderer_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/stroke_renderer.dart';

void main() {
  group('StrokeRenderer', () {
    test('filterPoints removes duplicate points', () {
      final points = [
        const InkPoint(0, 0),
        const InkPoint(0.3, 0.3), // 抖动点，会被过滤
        const InkPoint(1, 1),
        const InkPoint(2, 2),
      ];
      final filtered = StrokeRenderer.filterPoints(points);
      expect(filtered.length, 3);
      expect(filtered[0].offset, const Offset(0, 0));
      expect(filtered[1].offset, const Offset(1, 1));
    });

    test('smoothPoints applies weighted average', () {
      final points = [
        const InkPoint(0, 0),
        const InkPoint(10, 10),
        const InkPoint(20, 0),
      ];
      final smoothed = StrokeRenderer.smoothPoints(points);
      expect(smoothed.length, 3);
      expect(smoothed[1].x, closeTo(10.0, 0.1));
    });

    test('catmullRomPath generates smooth curve', () {
      final points = [
        const InkPoint(0, 0),
        const InkPoint(50, 100),
        const InkPoint(100, 50),
        const InkPoint(150, 150),
      ];
      final path = StrokeRenderer.catmullRomPath(points, 2.0);
      expect(path.getBounds().width, greaterThan(100));
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:starmind/src/mindmap/ink/stroke_renderer.dart'`（或类似）

- [ ] **Step 3: 创建 StrokeRenderer 类**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'ink_layer.dart';

class StrokeRenderer {
  /// 过滤抖动点（距离 < 0.5px 的重复点）
  static List<InkPoint> filterPoints(List<InkPoint> points) {
    if (points.isEmpty) return [];
    final filtered = [points.first];
    for (int i = 1; i < points.length; i++) {
      final dist = (points[i].offset - filtered.last.offset).distance;
      if (dist > 0.5) filtered.add(points[i]);
    }
    return filtered;
  }

  /// 加权移动平均平滑
  static List<InkPoint> smoothPoints(List<InkPoint> pts) {
    if (pts.length < 3) return pts;
    final smoothed = [pts.first];
    for (int i = 1; i < pts.length - 1; i++) {
      final x = pts[i-1].x * 0.25 + pts[i].x * 0.5 + pts[i+1].x * 0.25;
      final y = pts[i-1].y * 0.25 + pts[i].y * 0.5 + pts[i+1].y * 0.25;
      final p = pts[i-1].pressure * 0.25 + pts[i].pressure * 0.5 + pts[i+1].pressure * 0.25;
      smoothed.add(InkPoint(x, y, pressure: p));
    }
    smoothed.add(pts.last);
    return smoothed;
  }

  /// Catmull-Rom 样条路径生成
  static Path catmullRomPath(List<InkPoint> points, double baseWidth) {
    if (points.length < 4) {
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      return path;
    }

    final spline = CatmullRomSpline(
      points.map((p) => p.offset).toList(),
    );

    final totalDist = _totalDistance(points);
    final samples = math.max(64, (totalDist / 0.5).round());

    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (int i = 1; i <= samples; i++) {
      final t = i / samples;
      final p = spline.transform(t);
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static double _totalDistance(List<InkPoint> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i+1].offset - points[i].offset).distance;
    }
    return total;
  }

  /// 变宽笔画多边形包围（压感笔画）
  static Path variableWidthPath(List<InkPoint> points, double baseWidth) {
    if (points.length < 4) {
      return _simpleVariablePath(points, baseWidth);
    }

    final processed = smoothPoints(filterPoints(points));
    final spline = CatmullRomSpline(
      processed.map((p) => p.offset).toList(),
    );

    final totalDist = _totalDistance(processed);
    final samples = math.max(64, (totalDist / 0.5).round());

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    // 首尾渐变（20% 区域）
    final taperSamples = (samples * 0.2).round();

    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final point = spline.transform(t);

      // 计算当前宽度（基于压感）
      final segIdx = (t * (processed.length - 1)).floor().clamp(0, processed.length - 2);
      final localT = (t * (processed.length - 1) - segIdx).clamp(0.0, 1.0);
      var width = lerpDouble(
        processed[segIdx].pressure * baseWidth,
        processed[segIdx + 1].pressure * baseWidth,
        localT,
      ) ?? baseWidth;

      // 首尾渐变
      if (i < taperSamples) {
        width *= i / taperSamples;
      } else if (i > samples - taperSamples) {
        width *= (samples - i) / taperSamples;
      }

      // 计算法向量
      Offset tangent;
      if (i == 0) {
        tangent = spline.transform(1/samples) - point;
      } else if (i == samples) {
        tangent = point - spline.transform((samples-1)/samples);
      } else {
        tangent = spline.transform((i+1)/samples) - spline.transform((i-1)/samples);
      }
      final len = tangent.distance;
      final normal = len < 0.0001 ? Offset.zero : Offset(-tangent.dy, tangent.dx) / len;

      leftPoints.add(point + normal * (width / 2));
      rightPoints.add(point - normal * (width / 2));
    }

    // 构建闭合路径
    final path = Path();
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

  static Path _simpleVariablePath(List<InkPoint> points, double baseWidth) {
    if (points.isEmpty) return Path();
    // 简单实现：直线连接
    final path = Path();
    // ... 省略
    return path;
  }

  /// 绘制笔画
  static void drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.length < 2) return;

    final processed = smoothPoints(filterPoints(stroke.points));

    final paint = Paint()
      ..color = Color(stroke.color)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = stroke.tool == InkTool.highlighter 
          ? PaintingStyle.stroke 
          : PaintingStyle.fill;

    if (stroke.tool == InkTool.highlighter) {
      paint.blendMode = BlendMode.srcOver;
      paint.color = Color(stroke.color).withOpacity(0.35);
      paint.strokeWidth = stroke.width * 3;
      final path = catmullRomPath(processed, stroke.width);
      canvas.drawPath(path, paint);
    } else if (stroke.tool == InkTool.eraser) {
      paint.blendMode = BlendMode.clear;
      final path = variableWidthPath(processed, stroke.width * 2);
      canvas.drawPath(path, paint);
    } else {
      // 笔：变宽笔画
      final path = variableWidthPath(processed, stroke.width);
      canvas.drawPath(path, paint);
      
      // 细线描边消除多边形锯齿
      final strokePaint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = 0.5
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, strokePaint);
    }
  }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: 重写 CanvasInkPainter**

```dart
// lib/src/mindmap/ink/canvas_ink_layer.dart:54-80
class CanvasInkPainter extends CustomPainter {
  const CanvasInkPainter({required this.strokes});

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      StrokeRenderer.drawStroke(canvas, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasInkPainter old) => 
      old.strokes != strokes;
}
```

- [ ] **Step 6: 跑一次完整测试 + graphify**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart && /graphify`
Expected: PASS + `graphify-out/manifest.json` 包含 `stroke_renderer.dart`

- [ ] **Step 7: Commit**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart \
        lib/src/mindmap/ink/canvas_ink_layer.dart \
        test/mindmap/ink/stroke_renderer_test.dart \
        graphify-out/
git commit -m "feat(ink): upgrade to Catmull-Rom spline rendering"
```

---

## Plan 1-B: 输入稳定器

**文件:**
- 创建: `lib/src/mindmap/ink/stroke_stabilizer.dart`
- 修改: `lib/src/mindmap/ink/ink_layer_controller.dart:55-72`
- 测试: `test/mindmap/ink/stroke_stabilizer_test.dart`

**说明：** `stabilize()` 核心逻辑直接整段复制自 `<repo-root>/reference/fluera_canvas/lib/canvas/stroke_stabilizer.dart` 的同名方法（String Pulling + Moving Average + Corner Detection），不做改动；如该参考目录不存在，向用户索取源文件后再开始。

- [ ] **Step 1: 写失败测试**

```dart
// test/mindmap/ink/stroke_stabilizer_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/stroke_stabilizer.dart';

void main() {
  group('StrokeStabilizer', () {
    test('level 0 returns raw point', () {
      final stabilizer = StrokeStabilizer(level: 0);
      final result = stabilizer.stabilize(const Offset(100, 100));
      expect(result, const Offset(100, 100));
    });

    test('level > 0 stabilizes jitter', () {
      final stabilizer = StrokeStabilizer(level: 5);
      stabilizer.stabilize(const Offset(0, 0));
      stabilizer.stabilize(const Offset(1, 1)); // 微小抖动
      final result = stabilizer.stabilize(const Offset(50, 50));
      expect(result.dx, greaterThan(0));
      expect(result.dx, lessThan(50));
    });

    test('reset clears internal state', () {
      final stabilizer = StrokeStabilizer(level: 5);
      stabilizer.stabilize(const Offset(100, 100));
      stabilizer.reset();
      final result = stabilizer.stabilize(const Offset(200, 200));
      expect(result, const Offset(200, 200));
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/mindmap/ink/stroke_stabilizer_test.dart`
Expected: FAIL with `Target of URI doesn't exist: '.../stroke_stabilizer.dart'`

- [ ] **Step 3: 创建 StrokeStabilizer 类**

```dart
// lib/src/mindmap/ink/stroke_stabilizer.dart
import 'dart:math' as math;
import 'dart:ui';

/// 手写输入稳定器 — String Pulling + Moving Average + Corner Detection
///
/// 参考 fluera_canvas StrokeStabilizer 实现
class StrokeStabilizer {
  int _level;
  Offset? _lastStabilized;
  Offset? _previousRaw;
  int? _previousTimestamp;
  double _lastSpeed = 0.0;
  int _pointCount = 0;
  final List<Offset> _maBuffer = [];
  final List<double> _pressureBuffer = [];
  Offset? _lastDirection;

  int get _maWindow => (_level <= 3) ? 3 : (_level <= 6) ? 4 : 5;

  double get _stringLength {
    if (_level == 0) return 0.0;
    final base = _level * 4.0;
    final velocityFactor = 1.0 - (_lastSpeed / 1200.0).clamp(0.0, 0.6);
    return base * velocityFactor;
  }

  double get _catchup {
    final linear = 0.70 - (_level * 0.035).clamp(0.0, 0.35);
    final t = linear;
    return t * t * (3.0 - 2.0 * t);
  }

  StrokeStabilizer({int level = 0}) : _level = level.clamp(0, 10);

  int get level => _level;
  set level(int value) => _level = value.clamp(0, 10);

  /// 整段复制 `reference/fluera_canvas/lib/canvas/stroke_stabilizer.dart` 的
  /// `stabilize()` 方法体（包含 string-pulling 内圈、moving-average buffer、
  /// corner-detection 急转弯保护、catch-up 因子）。不要重写或简化逻辑。
  /// 若 reference 路径不存在，本 Step 阻塞，回头向用户索取源文件。
  Offset stabilize(Offset rawPoint, {int? timestampUs}) {
    if (_level == 0) return rawPoint;
    throw UnimplementedError('Paste fluera_canvas stabilize() body here.');
  }

  double stabilizePressure(double rawPressure) {
    if (_level == 0) return rawPressure;
    _pressureBuffer.add(rawPressure);
    final window = _maWindow;
    if (_pressureBuffer.length > window) {
      _pressureBuffer.removeAt(0);
    }
    double sum = 0, sumW = 0;
    for (int i = 0; i < _pressureBuffer.length; i++) {
      final w = (i + 1).toDouble();
      sum += _pressureBuffer[i] * w;
      sumW += w;
    }
    return sum / sumW;
  }

  List<Offset> finalize(Offset finalRawPoint, {int steps = 4}) {
    if (_level == 0 || _lastStabilized == null) return [];
    final from = _lastStabilized!;
    final dx = finalRawPoint.dx - from.dx;
    final dy = finalRawPoint.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 2.0) return [];
    final points = <Offset>[];
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final ease = 1.0 - (1.0 - t) * (1.0 - t);
      points.add(Offset(from.dx + dx * ease, from.dy + dy * ease));
    }
    return points;
  }

  void reset() {
    _lastStabilized = null;
    _previousRaw = null;
    _previousTimestamp = null;
    _lastSpeed = 0.0;
    _pointCount = 0;
    _maBuffer.clear();
    _pressureBuffer.clear();
    _lastDirection = null;
  }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/mindmap/ink/stroke_stabilizer_test.dart`
Expected: PASS

- [ ] **Step 5: 集成到 InkLayerController**

```dart
// lib/src/mindmap/ink/ink_layer_controller.dart
// 新增字段和方法
class InkLayerController extends ChangeNotifier {
  // ... 现有字段
  
  StrokeStabilizer _stabilizer = StrokeStabilizer(level: 3);
  int get stabilizerLevel => _stabilizer.level;
  
  void setStabilizerLevel(int level) {
    _stabilizer.level = level;
    notifyListeners();
  }

  void beginStroke(InkLayerOwnerType ownerType, String ownerId, Offset point, {double pressure = 1}) {
    ensureLayer(ownerType, ownerId);
    _stabilizer.reset();
    final stabilized = _stabilizer.stabilize(point);
    final stabilizedPressure = _stabilizer.stabilizePressure(pressure);
    _currentStroke = InkStroke(
      id: _idFactory() ?? 'stroke-${DateTime.now().microsecondsSinceEpoch}',
      tool: _tool,
      color: _tool == InkTool.highlighter ? Colors.yellow.withValues(alpha: 0.35).value : _color,
      width: _tool == InkTool.highlighter ? _width * 3 : _width,
      points: [InkPoint(stabilized.dx, stabilized.dy, pressure: stabilizedPressure)],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  void appendPoint(Offset point, {double pressure = 1}) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    final stabilized = _stabilizer.stabilize(point);
    final stabilizedPressure = _stabilizer.stabilizePressure(pressure);
    _currentStroke = stroke.copyWith(
      points: [...stroke.points, InkPoint(stabilized.dx, stabilized.dy, pressure: stabilizedPressure)],
    );
    notifyListeners();
  }

  InkStroke? endStroke(InkLayerOwnerType ownerType, String ownerId) {
    final stroke = _currentStroke;
    _currentStroke = null;
    if (stroke == null || stroke.points.length < 2) {
      notifyListeners();
      return null;
    }
    // 添加 catch-up points
    final catchUpPoints = _stabilizer.finalize(stroke.points.last.offset);
    final finalStroke = catchUpPoints.isNotEmpty 
        ? stroke.copyWith(points: [...stroke.points, ...catchUpPoints.map((p) => InkPoint(p.dx, p.dy))])
        : stroke;
    
    final key = _key(ownerType, ownerId);
    final layer = ensureLayer(ownerType, ownerId);
    _layers[key] = layer.addStroke(finalStroke);
    notifyListeners();
    return finalStroke;
  }
}
```

- [ ] **Step 6: 跑集成回归 + graphify**

Run: `flutter test test/mindmap/ink/ && /graphify`
Expected: 所有现有 ink 测试 PASS；`manifest.json` 包含 `stroke_stabilizer.dart` 与变更后的 `ink_layer_controller.dart`

- [ ] **Step 7: Commit**

```bash
git add lib/src/mindmap/ink/stroke_stabilizer.dart \
        lib/src/mindmap/ink/ink_layer_controller.dart \
        test/mindmap/ink/stroke_stabilizer_test.dart \
        graphify-out/
git commit -m "feat(ink): add stroke stabilizer (string pulling + MA)"
```

---

## Plan 1-C: Android Stylus 压感支持

**文件:**
- 创建: `lib/src/mindmap/ink/stylus_input_handler.dart`
- 修改: `lib/src/mindmap/ui/mindmap_page.dart`
- 测试: `test/mindmap/ink/stylus_input_test.dart`

- [ ] **Step 1: 创建 StylusInputHandler**

```dart
// lib/src/mindmap/ink/stylus_input_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android Stylus 压感输入处理器
class StylusInputHandler {
  static bool _isStylusPointer(PointerEvent event) {
    // Android: pointer.type == PointerDeviceKind.stylus 或 invertedStylus
    return event.kind == PointerDeviceKind.stylus ||
           event.kind == PointerDeviceKind.invertedStylus;
  }

  static double getPressure(PointerEvent event) {
    if (_isStylusPointer(event)) {
      return event.pressure.clamp(0.0, 1.0);
    }
    return 1.0; // 默认压力
  }

  static bool isPalmTouch(PointerEvent event) {
    // 手掌触控通常面积较大
    return event.kind == PointerDeviceKind.touch &&
           event.size > 0.05; // 阈值可调整
  }
}
```

- [ ] **Step 2: 在 MindMapPage 中使用 Listener 替代 GestureDetector**

```dart
// lib/src/mindmap/ui/mindmap_page.dart
// 在手写模式下使用 Listener 获取压感数据

Widget _buildInkLayer() {
  return Listener(
    onPointerDown: (event) {
      if (!_isInkMode) return;
      if (StylusInputHandler.isPalmTouch(event)) {
        // 手掌触控：忽略，交由 InteractiveViewer 处理
        return;
      }
      final pressure = StylusInputHandler.getPressure(event);
      _inkLayerController.beginStroke(
        InkLayerOwnerType.canvas,
        _currentTopicId!,
        event.localPosition,
        pressure: pressure,
      );
    },
    onPointerMove: (event) {
      if (!_isInkMode || _inkLayerController.currentStroke == null) return;
      if (StylusInputHandler.isPalmTouch(event)) return;
      final pressure = StylusInputHandler.getPressure(event);
      _inkLayerController.appendPoint(
        event.localPosition,
        pressure: pressure,
      );
    },
    onPointerUp: (event) {
      if (!_isInkMode) return;
      final stroke = _inkLayerController.endStroke(
        InkLayerOwnerType.canvas,
        _currentTopicId!,
      );
      if (stroke != null) {
        _saveInkStroke(stroke);
      }
    },
    child: CanvasInkLayer(
      controller: _inkLayerController,
      ownerType: InkLayerOwnerType.canvas,
      ownerId: _currentTopicId!,
      enabled: _isInkMode,
    ),
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/src/mindmap/ink/stylus_input_handler.dart \
        lib/src/mindmap/ui/mindmap_page.dart
git commit -m "feat(ink): add Android stylus pressure support"
```

---

## Plan 1-D: 工具栏集成

**文件:**
- 创建: `lib/src/mindmap/ui/components/ink_toolbar.dart`
- 修改: `lib/src/mindmap/ui/bottom_action_bar.dart:90-150`
- 修改: `lib/src/mindmap/ui/mindmap_controller.dart:77-78`
- 测试: `test/mindmap/ui/bottom_action_bar_test.dart`

- [ ] **Step 1: 扩展 MindMapController（单一状态源）**

**注意：** 现有 `mindmap_controller.dart:22` 已有 `enum CanvasInteractMode { drag, lasso }`，**只追加 `ink` 一个枚举值，不要新增 `_isInkMode` 布尔字段**。所有"是否在手写态"的判断走 `interactMode == CanvasInteractMode.ink`。这样避免两套状态机互相同步出脏状态。

```dart
// lib/src/mindmap/ui/mindmap_controller.dart
// 1) 修改 enum
enum CanvasInteractMode { drag, lasso, ink }

// 2) 新增 ink 工具状态（这个与 interactMode 正交，可独立存）
InkTool _inkTool = InkTool.pen;
InkTool get inkTool => _inkTool;

// 3) 派生 getter，便于 UI 读取
bool get isInkMode => _interactMode == CanvasInteractMode.ink;

void setInkTool(InkTool tool) {
  _inkTool = tool;
  notifyListeners();
}

// 4) 入口/退出 ink 模式复用已有 setInteractMode（mindmap_controller.dart:1082）
//    例如底部按钮调用：
//    controller.setInteractMode(
//      controller.isInkMode ? CanvasInteractMode.drag : CanvasInteractMode.ink,
//    );
```

**禁止做：** 不要新增 `_isInkMode` 字段；不要新增 `setInkMode(bool)`，复用 `setInteractMode`。

- [ ] **Step 2: 修改 BottomActionBar**

```dart
// lib/src/mindmap/ui/bottom_action_bar.dart
// 在现有按钮后添加「笔」按钮

// 新增按钮构建方法
Widget _buildInkButton(BuildContext context) {
  final isInkMode = controller.interactMode == CanvasInteractMode.ink;
  return _ActionButton(
    icon: Icons.edit,
    isActive: isInkMode,
    onTap: () => controller.setInteractMode(
      isInkMode ? CanvasInteractMode.drag : CanvasInteractMode.ink,
    ),
  );
}

// 修改 build 方法，在拖动按钮后插入
Row(
  children: [
    _buildDragButton(),
    _buildLassoButton(),
    _buildInkButton(), // 新增
    _buildSeparator(),
    // ... 其他按钮
  ],
)
```

- [ ] **Step 3: 创建 InkToolbar 子组件**

```dart
// lib/src/mindmap/ui/components/ink_toolbar.dart
import 'package:flutter/material.dart';
import '../../ink/ink_layer.dart';

class InkToolbar extends StatelessWidget {
  final InkTool currentTool;
  final void Function(InkTool) onToolChanged;
  final int currentColor;
  final void Function(int) onColorChanged;

  const InkToolbar({
    super.key,
    required this.currentTool,
    required this.onToolChanged,
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB814100C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.edit,
            tool: InkTool.pen,
            isActive: currentTool == InkTool.pen,
            onTap: () => onToolChanged(InkTool.pen),
          ),
          _ToolButton(
            icon: Icons.highlight,
            tool: InkTool.highlighter,
            isActive: currentTool == InkTool.highlighter,
            onTap: () => onToolChanged(InkTool.highlighter),
          ),
          _ToolButton(
            icon: Icons.cleaning_services,
            tool: InkTool.eraser,
            isActive: currentTool == InkTool.eraser,
            onTap: () => onToolChanged(InkTool.eraser),
          ),
          const SizedBox(width: 8),
          _ColorPicker(
            currentColor: currentColor,
            onColorChanged: onColorChanged,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 在 MindMapPage 中显示 InkToolbar**

```dart
// lib/src/mindmap/ui/mindmap_page.dart
// 当 isInkMode 时，在底部显示 InkToolbar

if (controller.isInkMode)
  Positioned(
    bottom: 80,
    left: 0,
    right: 0,
    child: Center(
      child: InkToolbar(
        currentTool: controller.inkTool,
        onToolChanged: (t) {
          controller.setInkTool(t);
          _inkLayerController.setTool(t); // 同步给 InkLayerController
        },
        currentColor: _inkLayerController.color,
        onColorChanged: (c) => _inkLayerController.setStyle(color: c),
      ),
    ),
  ),
```

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart \
        lib/src/mindmap/ui/bottom_action_bar.dart \
        lib/src/mindmap/ui/components/ink_toolbar.dart \
        lib/src/mindmap/ui/mindmap_page.dart \
        test/mindmap/ui/bottom_action_bar_test.dart
git commit -m "feat(ink): add ink mode toggle in bottom action bar"
```

---

## Plan 1-E: 持久化（接入已有 ink_layers，不重建）

> **现状盘点（动手前必读）：**
> - 表 `ink_layers` 已在 `rust/src/storage/db.rs:267` 建好（**表名是 `ink_layers`，不是 `mindmap_ink_layers`**，键约束是 `UNIQUE(owner_id, type)`）。
> - Rust 端 `rust/src/storage/ink_layers.rs` 已暴露 `save_ink_layer / get_ink_layer / delete_ink_layer`，使用 `ON CONFLICT(owner_id, type) DO UPDATE` upsert。
> - FFI `mindmap_save_ink_layer` / `mindmap_get_ink_layer` / `mindmap_delete_ink_layer` 已在 `rust/src/api/storage.rs:252-260` 暴露。
> - Dart 端 `FfiInkLayerRepository`（`lib/src/mindmap/ink/ink_layer_repository.dart`）已是完整实现。
> - **本 Plan 不再建表，不新建 `rust/src/storage/ink.rs`，不重写仓库**。仅做：① 把 `FfiInkLayerRepository` 注入 `_WorkspacePageState`；② endStroke 后实时保存；③ 进入页面时 loadInkLayer 回填到 `InkLayerController`。

**文件:**
- 修改: `lib/src/mindmap/ui/mindmap_page.dart`（注入 repository、保存回调、加载回填）
- 修改: `lib/src/home/workspace_page.dart`（构造时传入 `FfiInkLayerRepository`，与 `MindMapService` 同一注入点）
- 测试: `test/mindmap/ink/ink_persistence_test.dart`（用 `InMemoryInkLayerRepository` 验证保存 + 重载闭环）

- [ ] **Step 1: 写失败测试 — endStroke 后自动 save，重新进入页面后 load 回 InkLayerController**

```dart
// test/mindmap/ink/ink_persistence_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_controller.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_repository.dart';
import 'package:starmind/src/mindmap/ink/ink_persistence.dart';

void main() {
  test('endStroke triggers repository.saveInkLayer with current layer', () async {
    final repo = InMemoryInkLayerRepository();
    final controller = InkLayerController();
    final persistence = InkLayerPersistence(repository: repo, controller: controller);

    controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
    controller.appendPoint(const Offset(10, 10));
    final stroke = controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
    await persistence.onStrokeEnded(InkLayerOwnerType.canvas, 'topic-1');

    final saved = await repo.loadInkLayer('topic-1', InkLayerOwnerType.canvas);
    expect(saved, isNotNull);
    expect(saved!.strokes.length, 1);
    expect(stroke, isNotNull);
  });

  test('hydrate loads existing layer into controller', () async {
    final repo = InMemoryInkLayerRepository();
    final now = DateTime.now();
    await repo.saveInkLayer(InkLayer(
      id: 'l1', ownerType: InkLayerOwnerType.canvas, ownerId: 'topic-1',
      strokes: const [], createdAt: now, updatedAt: now,
    ));
    final controller = InkLayerController();
    final persistence = InkLayerPersistence(repository: repo, controller: controller);

    await persistence.hydrate(InkLayerOwnerType.canvas, 'topic-1');
    expect(controller.getLayer(InkLayerOwnerType.canvas, 'topic-1'), isNotNull);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/mindmap/ink/ink_persistence_test.dart`
Expected: FAIL with `Target of URI doesn't exist: '.../ink_persistence.dart'`

- [ ] **Step 3: 创建 InkLayerPersistence 桥接类**

```dart
// lib/src/mindmap/ink/ink_persistence.dart
import 'ink_layer.dart';
import 'ink_layer_controller.dart';
import 'ink_layer_repository.dart';

/// 把 InkLayerController 的内存层与 InkLayerRepository 桥接：
/// - hydrate: 进入页面时从仓库读到 controller
/// - onStrokeEnded: endStroke 后实时落库
class InkLayerPersistence {
  InkLayerPersistence({required this.repository, required this.controller});

  final InkLayerRepository repository;
  final InkLayerController controller;

  Future<void> hydrate(InkLayerOwnerType ownerType, String ownerId) async {
    final layer = await repository.loadInkLayer(ownerId, ownerType);
    if (layer != null) controller.loadLayer(layer);
  }

  Future<void> onStrokeEnded(InkLayerOwnerType ownerType, String ownerId) async {
    final layer = controller.getLayer(ownerType, ownerId);
    if (layer == null) return;
    await repository.saveInkLayer(layer);
  }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/mindmap/ink/ink_persistence_test.dart`
Expected: PASS

- [ ] **Step 5: 注入到 MindMapPage**

`mindmap_page.dart` 持有 `InkLayerPersistence` 实例（通过构造参数从 `WorkspacePage` 注入 `FfiInkLayerRepository`）。在 `initState` 中调用 `persistence.hydrate(InkLayerOwnerType.canvas, topicId)`；Listener 的 `onPointerUp` 流程在 `endStroke` 返回非空 stroke 后调用 `persistence.onStrokeEnded(...)`。

不要在 mindmap_page.dart 里直接 `import 'package:starmind/src/rust/...'` —— 走 repository 接口（**RULES.md §1.5 FFI 类型不外泄**）。

- [ ] **Step 6: WorkspacePage 注入**

```dart
// lib/src/home/workspace_page.dart
// 与 MindMapService 同一构造段，新增：
final _inkLayerRepository = const FfiInkLayerRepository();
// 传给每个 MindMapPage 的构造函数
```

- [ ] **Step 7: 跑完整测试 + graphify**

Run: `flutter test test/mindmap/ && /graphify`
Expected: 所有 mindmap 测试 PASS；`manifest.json` 含 `ink_persistence.dart`

- [ ] **Step 8: Commit**

```bash
git add lib/src/mindmap/ink/ink_persistence.dart \
        lib/src/mindmap/ui/mindmap_page.dart \
        lib/src/home/workspace_page.dart \
        test/mindmap/ink/ink_persistence_test.dart \
        graphify-out/
git commit -m "feat(ink): wire FfiInkLayerRepository for real-time persistence"
```

---

## Plan 1-F: 节点级手写入口

**文件:**
- 创建: `lib/src/mindmap/ui/components/node_context_menu.dart`
- 修改: `lib/src/mindmap/ui/node_widget.dart`
- 测试: `test/mindmap/ui/node_context_menu_test.dart`

- [ ] **Step 1: 创建节点悬浮菜单**

```dart
// lib/src/mindmap/ui/components/node_context_menu.dart
import 'package:flutter/material.dart';

class NodeContextMenu extends StatelessWidget {
  final Note note;
  final VoidCallback onEditInk;
  final VoidCallback onDelete;

  const NodeContextMenu({
    super.key,
    required this.note,
    required this.onEditInk,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB814100C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xB3FFF8E6)),
            onPressed: onEditInk,
            tooltip: '手写批注',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Color(0xB3FFF8E6)),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 在 NodeWidget 中集成长按菜单**

```dart
// lib/src/mindmap/ui/node_widget.dart
// 添加长按手势触发悬浮菜单

GestureDetector(
  onLongPress: () => _showContextMenu(context),
  // ... 其他手势
)

void _showContextMenu(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => NodeContextMenu(
      note: note,
      onEditInk: () {
        Navigator.pop(context);
        _openInkEditor();
      },
      onDelete: () {
        Navigator.pop(context);
        controller.deleteNote(note.id);
      },
    ),
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/src/mindmap/ui/components/node_context_menu.dart \
        lib/src/mindmap/ui/node_widget.dart \
        test/mindmap/ui/node_context_menu_test.dart
git commit -m "feat(ink): add node-level ink entry via long-press menu"
```

---

## 验收标准

- [ ] 点击「笔」按钮后，单指绘制产生墨迹
- [ ] 墨迹平滑，GoodNotes 级别体验
- [ ] 双指可平移/缩放画布，不影响墨迹
- [ ] 切换到橡皮后，可擦除墨迹
- [ ] 切换到荧光笔后，墨迹半透明叠加
- [ ] Android Stylus 压感生效，线宽随压力变化
- [ ] 退出页面后重新进入，墨迹保留
- [ ] 长按节点弹出悬浮菜单，可进入节点手写

## 依赖

- v15 Phase 1-3（基础交互）
- scribe_canvas 渲染算法（已阅读）
- fluera_canvas 稳定器（已阅读）

## 执行选项

**Plan 完整并保存。两个执行选项：**

1. **Subagent-Driven** - 每个 Plan 派发独立 subagent
2. **Inline Execution** - 在当前会话中顺序执行

**选择哪种方式？**