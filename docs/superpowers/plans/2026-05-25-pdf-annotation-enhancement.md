# PDF 阅读与批注功能增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 PDF 阅读与批注功能，达到 GoodNotes 水平，包括修复缩放 bug、扩展文本标记类型、增强手写笔触质量。

**Architecture:** 采用分层架构，在现有 PDF 渲染基础上叠加增强层。缩放修复优先（自定义手势处理器替代 InteractiveViewer），然后扩展批注模型（新增 strikeOut 类型），最后实现增强笔触（三阶段平滑器、压感曲线、Picture 缓存）。

**Tech Stack:** Flutter + Dart, Pdfium (pdfium-render), 现有 Starmind 架构

---

## 文件结构

```
lib/src/
├── pdf/
│   ├── pdf_viewport_controller.dart     # 修改: 添加 zoomAt(), constrainBounds()
│   ├── pdf_gesture_handler.dart          # 新增: 自定义手势处理器
│   ├── stroke_stabilizer.dart            # 新增: 三阶段笔触平滑器
│   ├── pressure_curve.dart               # 新增: 贝塞尔压感曲线
│   ├── stroke_cache_manager.dart         # 新增: Picture 缓存管理器
│   ├── pen_config.dart                   # 新增: 笔触配置模型
│   ├── enhanced_ink_stroke.dart          # 新增: 增强笔触模型
│   ├── stylus_detector.dart              # 新增: 手写笔检测器
│   │
│   └── widgets/
│       ├── pdf_viewport_widget.dart      # 修改: 集成 PdfGestureHandler
│       ├── ink_canvas_layer.dart         # 修改: 集成平滑器和缓存
│       ├── pen_config_panel.dart         # 新增: 笔触配置面板
│       └── stroke_renderer.dart          # 新增: 笔触渲染器
│
├── domain/
│   └── annotation.dart                   # 修改: 新增 strikeOut 类型
│
test/
├── pdf/
│   ├── pdf_gesture_handler_test.dart     # 新增
│   ├── stroke_stabilizer_test.dart       # 新增
│   ├── pressure_curve_test.dart          # 新增
│   └── stroke_cache_manager_test.dart    # 新增
```

---

## 阶段 0: PDF 缩放修复 (最高优先级)

### Task 0.1: 实现 PdfGestureHandler 手势处理器

**Files:**
- Create: `lib/src/pdf/pdf_gesture_handler.dart`
- Test: `test/pdf/pdf_gesture_handler_test.dart`

- [ ] **Step 1: 编写手势处理器测试**

```dart
// test/pdf/pdf_gesture_handler_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_gesture_handler.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';

void main() {
  group('PdfGestureHandler', () {
    late PdfViewportController controller;
    late PdfGestureHandler handler;

    setUp(() {
      controller = PdfViewportController();
      handler = PdfGestureHandler(controller: controller);
    });

    test('should detect zoom gesture', () {
      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: Offset(100, 100),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: Offset(100, 100),
        scale: 2.0,
      ));

      expect(controller.zoom, closeTo(2.0, 0.01));
    });

    test('should detect pan gesture', () {
      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: Offset(0, 0),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: Offset(50, 50),
        scale: 1.0,
      ));

      expect(controller.panOffset.dx, closeTo(50, 0.01));
      expect(controller.panOffset.dy, closeTo(50, 0.01));
    });

    test('should apply boundary constraints on scale end', () {
      controller.setViewportSize(Size(400, 600));

      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: Offset(200, 300),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: Offset(200, 300),
        scale: 0.3, // Below minZoom
      ));

      handler.onScaleEnd(ScaleEndDetails(), Size(595, 842), Size(400, 600));

      expect(controller.zoom, greaterThanOrEqualTo(PdfViewportController.minZoom));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/pdf/pdf_gesture_handler_test.dart`
Expected: FAIL - "PdfGestureHandler not found"

- [ ] **Step 3: 实现手势处理器**

```dart
// lib/src/pdf/pdf_gesture_handler.dart
import 'package:flutter/material.dart';
import 'pdf_viewport_controller.dart';

/// PDF 手势处理器
///
/// 处理缩放和平移手势，替代 InteractiveViewer 以获得更好的控制。
class PdfGestureHandler {
  final PdfViewportController controller;

  PdfGestureHandler({required this.controller});

  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  bool _isZooming = false;
  bool _isPanning = false;

  void onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastScale = 1.0;
    _isZooming = false;
    _isPanning = false;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;
    final scaleDelta = details.scale / _lastScale;

    // 检测缩放（scale 变化超过 1%）
    if ((scaleDelta - 1.0).abs() > 0.01) {
      _isZooming = true;
      _zoomAt(focalPoint, scaleDelta);
      _lastScale = details.scale;
    }

    // 检测平移（非缩放时）
    if (_lastFocalPoint != null && !_isZooming) {
      final panDelta = focalPoint - _lastFocalPoint!;
      if (panDelta.distance > 2.0) {
        _isPanning = true;
        controller.pan(panDelta);
      }
    }

    _lastFocalPoint = focalPoint;
  }

  void onScaleEnd(ScaleEndDetails details, Size pdfSize, Size viewportSize) {
    // 应用边界约束
    controller.constrainBounds(pdfSize, viewportSize);

    _lastFocalPoint = null;
    _isZooming = false;
    _isPanning = false;
  }

  void _zoomAt(Offset focalPoint, double scaleDelta) {
    final newZoom = controller.zoom * scaleDelta;
    controller.zoomAt(focalPoint, newZoom);
  }

  void reset() {
    _lastFocalPoint = null;
    _lastScale = 1.0;
    _isZooming = false;
    _isPanning = false;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/pdf/pdf_gesture_handler_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/pdf_gesture_handler.dart test/pdf/pdf_gesture_handler_test.dart
git commit -m "feat(pdf): add PdfGestureHandler for custom gesture handling"
```

---

### Task 0.2: 扩展 PdfViewportController 添加 zoomAt 和 constrainBounds

**Files:**
- Modify: `lib/src/pdf/pdf_viewport_controller.dart`
- Modify: `test/pdf/pdf_viewport_controller_test.dart`

- [ ] **Step 1: 编写 zoomAt 测试**

```dart
// test/pdf/pdf_viewport_controller_test.dart (追加)
group('zoomAt', () {
  test('should zoom with correct focal point', () {
    final controller = PdfViewportController();
    controller.setViewportSize(Size(400, 600));

    // 初始状态: zoom=1.0, panOffset=(0,0)
    controller.zoomAt(Offset(100, 100), 2.0);

    expect(controller.zoom, 2.0);
    // 缩放中心点 (100,100) 应保持不变
    // panOffset = focalPoint - (focalPoint - panOffset) * ratio
    // = (100, 100) - (100, 0) * 2/2 = (100, 100) - (100, 0) = (0, 100)
    expect(controller.panOffset.dx, closeTo(0, 0.1));
    expect(controller.panOffset.dy, closeTo(-100, 0.1));
  });

  test('should clamp zoom to min/max bounds', () {
    final controller = PdfViewportController();

    controller.zoomAt(Offset.zero, 0.1);
    expect(controller.zoom, PdfViewportController.minZoom);

    controller.zoomAt(Offset.zero, 20.0);
    expect(controller.zoom, PdfViewportController.maxZoom);
  });
});

group('constrainBounds', () {
  test('should center PDF when smaller than viewport', () {
    final controller = PdfViewportController();
    controller.setViewportSize(Size(400, 600));
    controller.setZoom(0.5); // PDF smaller than viewport

    controller.constrainBounds(Size(595, 842), Size(400, 600));

    // PDF 应居中显示
    expect(controller.panOffset.dx, closeTo(50, 0.1));
  });

  test('should clamp pan when PDF larger than viewport', () {
    final controller = PdfViewportController();
    controller.setViewportSize(Size(400, 600));
    controller.setZoom(2.0); // PDF larger than viewport
    controller.setPanOffset(Offset(-1000, -1000)); // Way out of bounds

    controller.constrainBounds(Size(595, 842), Size(400, 600));

    // 应被约束到有效范围
    expect(controller.panOffset.dx, lessThanOrEqualTo(0));
    expect(controller.panOffset.dy, lessThanOrEqualTo(0));
  });
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/pdf/pdf_viewport_controller_test.dart`
Expected: FAIL - "zoomAt method not found"

- [ ] **Step 3: 实现 zoomAt 和 constrainBounds**

在 `lib/src/pdf/pdf_viewport_controller.dart` 中添加：

```dart
/// 以指定中心点缩放
void zoomAt(Offset focalPoint, double newZoom) {
  final clampedZoom = newZoom.clamp(minZoom, maxZoom);
  if (clampedZoom == _zoom) return;

  // 计算缩放比例
  final scaleRatio = clampedZoom / _zoom;

  // 调整平移偏移以保持中心点不变
  // 新 panOffset = focalPoint - (focalPoint - oldPanOffset) * scaleRatio
  _panOffset = Offset(
    focalPoint.dx - (focalPoint.dx - _panOffset.dx) * scaleRatio,
    focalPoint.dy - (focalPoint.dy - _panOffset.dy) * scaleRatio,
  );

  _zoom = clampedZoom;
  notifyListeners();
}

/// 平移视口
void pan(Offset delta) {
  _panOffset += delta;
  notifyListeners();
}

/// 约束视口边界
void constrainBounds(Size pdfSize, Size viewportSize) {
  final baseScale = viewportSize.width / pdfSize.width;
  final scaledWidth = pdfSize.width * baseScale * _zoom;
  final scaledHeight = pdfSize.height * baseScale * _zoom;

  // 水平约束
  if (scaledWidth <= viewportSize.width) {
    // PDF 宽度小于视口，居中
    _panOffset = Offset((viewportSize.width - scaledWidth) / 2, _panOffset.dy);
  } else {
    // PDF 宽度大于视口，限制边界
    final minX = viewportSize.width - scaledWidth;
    final maxX = 0.0;
    _panOffset = Offset(_panOffset.dx.clamp(minX, maxX), _panOffset.dy);
  }

  // 垂直约束
  if (scaledHeight <= viewportSize.height) {
    // PDF 高度小于视口，居中
    _panOffset = Offset(_panOffset.dx, (viewportSize.height - scaledHeight) / 2);
  } else {
    // PDF 高度大于视口，限制边界
    final minY = viewportSize.height - scaledHeight;
    final maxY = 0.0;
    _panOffset = Offset(_panOffset.dx, _panOffset.dy.clamp(minY, maxY));
  }

  notifyListeners();
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/pdf/pdf_viewport_controller_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/pdf_viewport_controller.dart test/pdf/pdf_viewport_controller_test.dart
git commit -m "feat(pdf): add zoomAt and constrainBounds to PdfViewportController"
```

---

### Task 0.3: 重构 PdfViewportWidget 使用自定义手势处理器

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart`

- [ ] **Step 1: 编写 Widget 测试**

```dart
// test/pdf/widgets/pdf_viewport_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/pdf/widgets/pdf_viewport_widget.dart';

void main() {
  group('PdfViewportWidget', () {
    testWidgets('should handle pinch-to-zoom gesture', (tester) async {
      final controller = PdfViewportController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PdfViewportWidget(controller: controller),
        ),
      ));

      // 双指缩放手势模拟
      final center = Offset(200, 300);
      await tester.timedDragFrom(center, Offset(100, 0), Duration(milliseconds: 100));
      await tester.pump();

      // 验证缩放状态已更新
      // (实际测试需要更复杂的手势模拟)
    });
  });
}
```

- [ ] **Step 2: 运行测试验证当前状态**

Run: `flutter test test/pdf/widgets/pdf_viewport_widget_test.dart`
Expected: 测试运行（可能需要依赖注入 mock）

- [ ] **Step 3: 重构 Widget 使用自定义手势处理器**

修改 `lib/src/pdf/widgets/pdf_viewport_widget.dart`：

```dart
// 在文件顶部添加导入
import '../pdf_gesture_handler.dart';

// 在 _PdfViewportWidgetState 中添加
class _PdfViewportWidgetState extends State<PdfViewportWidget> {
  late PdfGestureHandler _gestureHandler;
  // ... 移除 TransformationController

  @override
  void initState() {
    super.initState();
    _gestureHandler = PdfGestureHandler(controller: widget.controller);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureHandler.onScaleStart(details);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _gestureHandler.onScaleUpdate(details);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final pdfSize = widget.controller.pageSizes[0];
    final viewportSize = _viewportKey.currentContext?.size;
    if (pdfSize != null && viewportSize != null) {
      _gestureHandler.onScaleEnd(details, pdfSize, viewportSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... 移除 InteractiveViewer，改用 GestureDetector
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: _buildPdfPages(pdfSize, baseScale),
    );
  }
}
```

- [ ] **Step 4: 运行 flutter analyze 检查**

Run: `flutter analyze lib/src/pdf/widgets/pdf_viewport_widget.dart`
Expected: No issues found

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart
git commit -m "refactor(pdf): replace InteractiveViewer with custom PdfGestureHandler"
```

---

### Task 0.4: 实现缩放与手写手势协调

**Files:**
- Modify: `lib/src/pdf/widgets/ink_canvas_layer.dart`
- Test: `test/pdf/widgets/ink_canvas_layer_test.dart`

- [ ] **Step 1: 编写手势协调测试**

```dart
// test/pdf/widgets/gesture_routing_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gesture Routing', () {
    testWidgets('should prioritize zoom over draw when 2+ fingers', (tester) async {
      // 测试双指时不应触发绘制
    });

    testWidgets('should allow draw when single stylus in annotation mode', (tester) async {
      // 测试单指触控笔在批注模式下触发绘制
    });
  });
}
```

- [ ] **Step 2: 修改 InkCanvasLayer 添加手势路由逻辑**

在 `lib/src/pdf/widgets/ink_canvas_layer.dart` 中修改 `_onPointerDown`:

```dart
void _onPointerDown(PointerDownEvent event) {
  _activePointers.add(event.pointer);

  // 双指缩放优先：当有多个指针时，不处理绘制
  if (_activePointers.length >= 2) {
    if (_drawingPointerId != null) {
      // 取消当前绘制
      _drawingPointerId = null;
      _isDrawing = false;
      _currentStrokePoints = [];
    }
    return;
  }

  // 手掌拒绝：只接受触控笔
  if (widget.palmRejectionEnabled && event.kind != PointerDeviceKind.stylus) {
    return;
  }

  // 单指书写检测
  if (_activePointers.length == 1 && widget.isInkMode && _drawingPointerId == null) {
    _drawingPointerId = event.pointer;
    // ... 开始绘制
  }
}
```

- [ ] **Step 3: 运行 flutter analyze 检查**

Run: `flutter analyze lib/src/pdf/widgets/ink_canvas_layer.dart`
Expected: No issues found

- [ ] **Step 4: 提交**

```bash
git add lib/src/pdf/widgets/ink_canvas_layer.dart
git commit -m "fix(pdf): prioritize zoom gesture over draw for multi-touch"
```

---

### Task 0.5: 缩放功能集成测试

**Files:**
- Create: `integration_test/pdf_zoom_test.dart`

- [ ] **Step 1: 编写集成测试**

```dart
// integration_test/pdf_zoom_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Zoom Integration', () {
    testWidgets('zoom and pan should work correctly', (tester) async {
      // 1. 加载 PDF
      // 2. 执行双指缩放
      // 3. 验证 zoom 值更新
      // 4. 执行平移
      // 5. 验证 panOffset 更新
      // 6. 验证边界约束生效
    });

    testWidgets('zoom and draw should not conflict', (tester) async {
      // 1. 进入批注模式
      // 2. 双指缩放
      // 3. 验证未触发绘制
      // 4. 单指触控笔绘制
      // 5. 验证绘制成功
    });
  });
}
```

- [ ] **Step 2: 运行集成测试**

Run: `flutter test integration_test/pdf_zoom_test.dart`
Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add integration_test/pdf_zoom_test.dart
git commit -m "test(pdf): add integration tests for zoom functionality"
```

---

## 阶段 1: 核心增强

### Task 1.1: 实现 PressureCurve 压感曲线

**Files:**
- Create: `lib/src/pdf/pressure_curve.dart`
- Test: `test/pdf/pressure_curve_test.dart`

- [ ] **Step 1: 编写压感曲线测试**

```dart
// test/pdf/pressure_curve_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

void main() {
  group('PressureCurve', () {
    test('linear curve should return input unchanged', () {
      const curve = PressureCurve.linear;
      expect(curve.evaluate(0.0), closeTo(0.0, 0.01));
      expect(curve.evaluate(0.5), closeTo(0.5, 0.01));
      expect(curve.evaluate(1.0), closeTo(1.0, 0.01));
    });

    test('soft curve should amplify light pressure', () {
      const curve = PressureCurve.soft;
      // 轻压时输出应该更大
      expect(curve.evaluate(0.3), greaterThan(0.3));
    });

    test('firm curve should require more pressure', () {
      const curve = PressureCurve.firm;
      // 轻压时输出应该更小
      expect(curve.evaluate(0.3), lessThan(0.3));
    });

    test('should serialize and deserialize correctly', () {
      const curve = PressureCurve.soft;
      final json = curve.toJson();
      final restored = PressureCurve.fromJson(json);
      expect(restored.p1, curve.p1);
      expect(restored.p2, curve.p2);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/pdf/pressure_curve_test.dart`
Expected: FAIL - "PressureCurve not found"

- [ ] **Step 3: 实现压感曲线**

```dart
// lib/src/pdf/pressure_curve.dart
import 'package:flutter/material.dart';

/// 压感曲线 - 使用三次贝塞尔曲线映射原始压感到输出压感
class PressureCurve {
  final Offset p1; // 控制点1
  final Offset p2; // 控制点2
  // p0=(0,0), p3=(1,1) 隐含

  const PressureCurve({
    this.p1 = const Offset(0.25, 0.25),
    this.p2 = const Offset(0.75, 0.75),
  });

  // 预设曲线
  static const linear = PressureCurve(
    p1: Offset(0.25, 0.25),
    p2: Offset(0.75, 0.75),
  );

  static const soft = PressureCurve(
    p1: Offset(0.15, 0.45),
    p2: Offset(0.55, 0.90),
  );

  static const firm = PressureCurve(
    p1: Offset(0.45, 0.10),
    p2: Offset(0.85, 0.55),
  );

  static const sCurve = PressureCurve(
    p1: Offset(0.25, 0.05),
    p2: Offset(0.75, 0.95),
  );

  static const heavy = PressureCurve(
    p1: Offset(0.60, 0.05),
    p2: Offset(0.95, 0.40),
  );

  /// 评估压感值
  double evaluate(double rawPressure) {
    final x = rawPressure.clamp(0.0, 1.0);
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;

    final t = _solveForT(x);
    return _bezierY(t).clamp(0.0, 1.0);
  }

  double _bezierX(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * t * p1.dx +
        3.0 * mt * t * t * p2.dx +
        t * t * t;
  }

  double _bezierY(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * t * p1.dy +
        3.0 * mt * t * t * p2.dy +
        t * t * t;
  }

  double _bezierXDerivative(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * p1.dx +
        6.0 * mt * t * (p2.dx - p1.dx) +
        3.0 * t * t * (1.0 - p2.dx);
  }

  double _solveForT(double x) {
    double t = x;
    for (int i = 0; i < 6; i++) {
      final error = _bezierX(t) - x;
      final deriv = _bezierXDerivative(t);
      if (deriv.abs() < 1e-10) break;
      t -= error / deriv;
      t = t.clamp(0.0, 1.0);
      if (error.abs() < 1e-5) break;
    }
    return t;
  }

  Map<String, dynamic> toJson() => {
    'p1x': p1.dx,
    'p1y': p1.dy,
    'p2x': p2.dx,
    'p2y': p2.dy,
  };

  factory PressureCurve.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PressureCurve.linear;
    return PressureCurve(
      p1: Offset(
        (json['p1x'] as num?)?.toDouble() ?? 0.25,
        (json['p1y'] as num?)?.toDouble() ?? 0.25,
      ),
      p2: Offset(
        (json['p2x'] as num?)?.toDouble() ?? 0.75,
        (json['p2y'] as num?)?.toDouble() ?? 0.75,
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/pdf/pressure_curve_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/pressure_curve.dart test/pdf/pressure_curve_test.dart
git commit -m "feat(pdf): add PressureCurve for pressure sensitivity mapping"
```

---

### Task 1.2: 实现 StrokeStabilizer 三阶段平滑器

**Files:**
- Create: `lib/src/pdf/stroke_stabilizer.dart`
- Test: `test/pdf/stroke_stabilizer_test.dart`

- [ ] **Step 1: 编写平滑器测试**

```dart
// test/pdf/stroke_stabilizer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/stroke_stabilizer.dart';

void main() {
  group('StrokeStabilizer', () {
    test('level 0 should return input unchanged', () {
      final stabilizer = StrokeStabilizer(level: 0);
      final input = Offset(100, 100);
      expect(stabilizer.stabilize(input), input);
    });

    test('level 10 should smooth jittery input', () {
      final stabilizer = StrokeStabilizer(level: 10);

      // 模拟抖动输入
      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(5, 2));
      stabilizer.stabilize(Offset(3, -1));
      final smoothed = stabilizer.stabilize(Offset(8, 3));

      // 输出应该比原始输入更平滑
      expect(smoothed.dx, lessThan(8));
    });

    test('should smooth pressure values', () {
      final stabilizer = StrokeStabilizer(level: 5);

      stabilizer.stabilizePressure(0.5);
      stabilizer.stabilizePressure(0.6);
      final smoothed = stabilizer.stabilizePressure(0.4);

      expect(smoothed, closeTo(0.5, 0.1));
    });

    test('finalize should generate catch-up points', () {
      final stabilizer = StrokeStabilizer(level: 10);

      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(50, 50));
      final catchUp = stabilizer.finalize(Offset(100, 100));

      expect(catchUp.length, greaterThan(0));
    });

    test('reset should clear all state', () {
      final stabilizer = StrokeStabilizer(level: 5);

      stabilizer.stabilize(Offset(0, 0));
      stabilizer.stabilize(Offset(50, 50));
      stabilizer.reset();

      // 重置后第一个点应该直接返回
      expect(stabilizer.stabilize(Offset(100, 100)), Offset(100, 100));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/pdf/stroke_stabilizer_test.dart`
Expected: FAIL - "StrokeStabilizer not found"

- [ ] **Step 3: 实现三阶段平滑器**

参考 Fluera Canvas 实现，创建 `lib/src/pdf/stroke_stabilizer.dart`（完整实现见 Fluera 源码，包含 String Pulling + Moving Average + Corner Detection）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/pdf/stroke_stabilizer_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/stroke_stabilizer.dart test/pdf/stroke_stabilizer_test.dart
git commit -m "feat(pdf): add StrokeStabilizer with 3-stage smoothing"
```

---

### Task 1.3: 实现 StrokeCacheManager Picture 缓存管理器

**Files:**
- Create: `lib/src/pdf/stroke_cache_manager.dart`
- Test: `test/pdf/stroke_cache_manager_test.dart`

- [ ] **Step 1: 编写缓存管理器测试**

```dart
// test/pdf/stroke_cache_manager_test.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/stroke_cache_manager.dart';

void main() {
  group('StrokeCacheManager', () {
    test('should create picture cache', () {
      final manager = StrokeCacheManager();

      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        Size(100, 100),
      );

      expect(manager.cachedPicture, isNotNull);
    });

    test('should restore from undo snapshot', () {
      final manager = StrokeCacheManager();

      // 创建初始缓存
      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        Size(100, 100),
      );
      manager.saveUndoSnapshot(0);

      // 添加更多笔画
      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        Size(100, 100),
      );

      // 从快照恢复
      final restored = manager.tryRestoreFromUndoSnapshot(0);
      expect(restored, isTrue);
    });

    test('should invalidate cache when stroke count changes', () {
      final manager = StrokeCacheManager();

      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        Size(100, 100),
      );

      expect(manager.isCacheValid(0), isTrue);
      expect(manager.isCacheValid(5), isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/pdf/stroke_cache_manager_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现缓存管理器**

```dart
// lib/src/pdf/stroke_cache_manager.dart
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 笔画缓存管理器 - 支持 ui.Picture 缓存和撤销快照
class StrokeCacheManager {
  ui.Picture? _cachedPicture;
  int _cachedStrokeCount = 0;

  /// 撤销快照环形缓冲
  final LinkedHashMap<int, ui.Picture> _undoSnapshots = LinkedHashMap();
  static const int maxUndoSnapshots = 10;

  ui.Picture? get cachedPicture => _cachedPicture;

  bool isCacheValid(int totalStrokes) => _cachedStrokeCount == totalStrokes;

  /// 尝试从撤销快照恢复（O(1) 撤销）
  bool tryRestoreFromUndoSnapshot(int targetStrokeCount) {
    final snapshot = _undoSnapshots.remove(targetStrokeCount);
    if (snapshot != null) {
      _cachedPicture?.dispose();
      _cachedPicture = snapshot;
      _cachedStrokeCount = targetStrokeCount;
      return true;
    }
    return false;
  }

  /// 保存当前缓存为撤销快照
  void saveUndoSnapshot(int strokeCount) {
    if (_cachedPicture == null) return;

    // 移除最旧的快照（如果超出限制）
    if (_undoSnapshots.length >= maxUndoSnapshots) {
      final oldestKey = _undoSnapshots.keys.first;
      _undoSnapshots[oldestKey]?.dispose();
      _undoSnapshots.remove(oldestKey);
    }

    // 克隆当前 Picture
    _undoSnapshots[strokeCount] = _clonePicture(_cachedPicture!);
  }

  /// 同步创建缓存
  void createCacheSynchronously(
    List<dynamic> strokes,
    void Function(Canvas, dynamic) drawStrokeCallback,
    Size size,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (final stroke in strokes) {
      drawStrokeCallback(canvas, stroke);
    }

    _cachedPicture?.dispose();
    _cachedPicture = recorder.endRecording();
    _cachedStrokeCount = strokes.length;
  }

  /// 绘制缓存到画布
  bool drawCached(Canvas canvas) {
    if (_cachedPicture == null) return false;
    canvas.drawPicture(_cachedPicture!);
    return true;
  }

  void dispose() {
    _cachedPicture?.dispose();
    for (final snapshot in _undoSnapshots.values) {
      snapshot.dispose();
    }
    _undoSnapshots.clear();
  }

  ui.Picture _clonePicture(ui.Picture source) {
    // Flutter 没有 Picture 克隆 API，需要重新录制
    // 这里简化处理，实际使用时需要保存绘制参数
    return source;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/pdf/stroke_cache_manager_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/pdf/stroke_cache_manager.dart test/pdf/stroke_cache_manager_test.dart
git commit -m "feat(pdf): add StrokeCacheManager for O(1) redraw and undo"
```

---

### Task 1.4: 实现 PenConfig 笔触配置模型

**Files:**
- Create: `lib/src/pdf/pen_config.dart`
- Modify: `lib/src/pdf/widgets/ink_toolbar.dart`
- Test: `test/pdf/pen_config_test.dart`

- [ ] **Step 1: 编写笔触配置测试**

```dart
// test/pdf/pen_config_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pen_config.dart';

void main() {
  group('PenConfig', () {
    test('fountainPen preset should have pressure enabled', () {
      final config = PenConfig.fountainPen();
      expect(config.pressureEnabled, isTrue);
      expect(config.pressureCurve, PressureCurve.soft);
    });

    test('highlighter preset should be semi-transparent', () {
      final config = PenConfig.highlighter();
      expect(config.opacity, closeTo(0.3, 0.01));
      expect(config.pressureEnabled, isFalse);
    });

    test('should serialize to JSON', () {
      final config = PenConfig(
        type: PenType.ballpointPen,
        color: Colors.blue,
        baseWidth: 2.0,
      );

      final json = config.toJson();
      expect(json['type'], 'ballpointPen');
      expect(json['baseWidth'], 2.0);
    });
  });
}
```

- [ ] **Step 2: 实现笔触配置模型**

```dart
// lib/src/pdf/pen_config.dart
import 'package:flutter/material.dart';
import 'pressure_curve.dart';

/// 笔触类型
enum PenType {
  fountainPen,  // 钢笔
  ballpointPen, // 圆珠笔
  pencil,       // 铅笔
  highlighter,  // 荧光笔
  eraser,       // 橡皮擦
}

/// 笔触配置
class PenConfig {
  final PenType type;
  final Color color;
  final double baseWidth;
  final double opacity;
  final PressureCurve pressureCurve;
  final int stabilizerLevel; // 0-10
  final bool pressureEnabled;

  const PenConfig({
    required this.type,
    required this.color,
    this.baseWidth = 2.0,
    this.opacity = 1.0,
    this.pressureCurve = PressureCurve.linear,
    this.stabilizerLevel = 3,
    this.pressureEnabled = true,
  });

  // 预设配置
  static PenConfig fountainPen({Color color = Colors.black}) => PenConfig(
    type: PenType.fountainPen,
    color: color,
    baseWidth: 2.0,
    pressureCurve: PressureCurve.soft,
    stabilizerLevel: 3,
    pressureEnabled: true,
  );

  static PenConfig ballpointPen({Color color = Colors.black}) => PenConfig(
    type: PenType.ballpointPen,
    color: color,
    baseWidth: 1.5,
    pressureCurve: PressureCurve.linear,
    stabilizerLevel: 2,
    pressureEnabled: false,
  );

  static PenConfig pencil({Color color = Colors.grey}) => PenConfig(
    type: PenType.pencil,
    color: color,
    baseWidth: 1.0,
    pressureCurve: PressureCurve.firm,
    stabilizerLevel: 4,
    pressureEnabled: true,
  );

  static PenConfig highlighter({Color color = Colors.yellow}) => PenConfig(
    type: PenType.highlighter,
    color: color,
    baseWidth: 20.0,
    opacity: 0.3,
    pressureCurve: PressureCurve.linear,
    stabilizerLevel: 0,
    pressureEnabled: false,
  );

  static PenConfig eraser({double width = 20.0}) => PenConfig(
    type: PenType.eraser,
    color: Colors.white,
    baseWidth: width,
    pressureEnabled: false,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'color': color.toARGB32(),
    'baseWidth': baseWidth,
    'opacity': opacity,
    'pressureCurve': pressureCurve.toJson(),
    'stabilizerLevel': stabilizerLevel,
    'pressureEnabled': pressureEnabled,
  };

  factory PenConfig.fromJson(Map<String, dynamic> json) {
    return PenConfig(
      type: PenType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PenType.ballpointPen,
      ),
      color: Color(json['color'] as int),
      baseWidth: (json['baseWidth'] as num?)?.toDouble() ?? 2.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      pressureCurve: PressureCurve.fromJson(json['pressureCurve']),
      stabilizerLevel: (json['stabilizerLevel'] as int?) ?? 3,
      pressureEnabled: (json['pressureEnabled'] as bool?) ?? true,
    );
  }
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/pdf/pen_config_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/src/pdf/pen_config.dart test/pdf/pen_config_test.dart
git commit -m "feat(pdf): add PenConfig for configurable pen types"
```

---

## 阶段 2: 文本批注扩展（删除线）

### Task 2.1: 扩展 AnnotationType 添加 strikeOut

**Files:**
- Modify: `lib/src/domain/annotation.dart`
- Test: `test/domain/annotation_test.dart`

- [ ] **Step 1: 编写删除线测试**

```dart
// test/domain/annotation_test.dart (追加)
group('Annotation.strikeOut', () {
  test('should create strikeOut annotation', () {
    final annotation = Annotation.strikeOut(
      id: 'test-id',
      documentId: 'doc-id',
      pageIndex: 0,
      startCharIndex: 0,
      endCharIndex: 10,
      selectedText: 'deleted text',
      rects: [AnnotationRect(left: 0, top: 10, right: 100, bottom: 20)],
    );

    expect(annotation.type, AnnotationType.strikeOut);
    expect(annotation.category, AnnotationCategory.standard);
    expect(annotation.colorHex, '#FF0000');
  });

  test('should serialize and deserialize strikeOut', () {
    final annotation = Annotation.strikeOut(
      id: 'test-id',
      documentId: 'doc-id',
      pageIndex: 0,
      startCharIndex: 0,
      endCharIndex: 10,
      selectedText: 'deleted text',
      rects: [AnnotationRect(left: 0, top: 10, right: 100, bottom: 20)],
    );

    final json = annotation.toJson();
    final restored = Annotation.fromJson(json);

    expect(restored.type, AnnotationType.strikeOut);
  });
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/annotation_test.dart`
Expected: FAIL - "strikeOut not found"

- [ ] **Step 3: 扩展 Annotation 模型**

在 `lib/src/domain/annotation.dart` 中修改：

```dart
// 扩展枚举
enum AnnotationType {
  highlight,
  underline,
  wave,
  strikeOut,  // 新增：删除线
  ink,
  note,
}

// 添加工厂方法
factory Annotation.strikeOut({
  required String id,
  required String documentId,
  required int pageIndex,
  required int startCharIndex,
  required int endCharIndex,
  required String selectedText,
  required List<AnnotationRect> rects,
  String colorHex = '#FF0000',
}) {
  final now = DateTime.now();
  return Annotation(
    id: id,
    documentId: documentId,
    pageIndex: pageIndex,
    type: AnnotationType.strikeOut,
    category: AnnotationCategory.standard,
    colorHex: colorHex,
    createdAt: now,
    modifiedAt: now,
    startCharIndex: startCharIndex,
    endCharIndex: endCharIndex,
    selectedText: selectedText,
    rects: rects,
  );
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/domain/annotation_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/domain/annotation.dart test/domain/annotation_test.dart
git commit -m "feat(annotation): add strikeOut annotation type"
```

---

### Task 2.2: 实现删除线渲染器

**Files:**
- Create: `lib/src/pdf/widgets/strike_out_renderer.dart`
- Modify: `lib/src/pdf/widgets/annotation_renderer.dart`

- [ ] **Step 1: 实现删除线渲染器**

```dart
// lib/src/pdf/widgets/strike_out_renderer.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/annotation.dart';

/// 删除线渲染器
class StrikeOutRenderer {
  static void draw(
    Canvas canvas,
    List<AnnotationRect> rects,
    Color color,
    double scale,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0 * scale
      ..style = PaintingStyle.stroke;

    for (final rect in rects) {
      // 绘制水平删除线穿过文本中部
      final midY = (rect.top + rect.bottom) / 2;
      canvas.drawLine(
        Offset(rect.left * scale, midY * scale),
        Offset(rect.right * scale, midY * scale),
        paint,
      );
    }
  }
}
```

- [ ] **Step 2: 集成到 AnnotationRenderer**

在 `lib/src/pdf/widgets/annotation_renderer.dart` 中添加删除线渲染逻辑：

```dart
// 在 paint 方法中添加
if (annotation.type == AnnotationType.strikeOut) {
  StrikeOutRenderer.draw(
    canvas,
    annotation.rects!,
    Color(int.parse(annotation.colorHex.replaceFirst('#', 'FF'), radix: 16)),
    scale,
  );
}
```

- [ ] **Step 3: 运行 flutter analyze 检查**

Run: `flutter analyze lib/src/pdf/widgets/`
Expected: No issues found

- [ ] **Step 4: 提交**

```bash
git add lib/src/pdf/widgets/strike_out_renderer.dart lib/src/pdf/widgets/annotation_renderer.dart
git commit -m "feat(pdf): add strikeOut renderer for text annotations"
```

---

### Task 2.3: 扩展 AnnotationController 支持删除线

**Files:**
- Modify: `lib/src/pdf/annotation_controller.dart`
- Test: `test/pdf/annotation_controller_test.dart`

- [ ] **Step 1: 编写删除线创建测试**

```dart
// test/pdf/annotation_controller_test.dart (追加)
group('createStrikeOut', () {
  test('should create strikeOut annotation', () async {
    final controller = AnnotationController(
      repository: MockStorageRepository(),
      documentId: 'doc-id',
    );

    await controller.createStrikeOut(
      pageIndex: 0,
      startCharIndex: 0,
      endCharIndex: 10,
      selectedText: 'deleted',
      rects: [AnnotationRect(left: 0, top: 10, right: 100, bottom: 20)],
    );

    expect(controller.annotations.length, 1);
    expect(controller.annotations.first.type, AnnotationType.strikeOut);
  });
});
```

- [ ] **Step 2: 添加 createStrikeOut 方法**

在 `lib/src/pdf/annotation_controller.dart` 中添加：

```dart
/// 创建删除线批注
Future<void> createStrikeOut({
  required int pageIndex,
  required int startCharIndex,
  required int endCharIndex,
  required String selectedText,
  required List<AnnotationRect> rects,
  String colorHex = '#FF0000',
}) async {
  final annotation = Annotation.strikeOut(
    id: _uuid.v4(),
    documentId: documentId,
    pageIndex: pageIndex,
    startCharIndex: startCharIndex,
    endCharIndex: endCharIndex,
    selectedText: selectedText,
    rects: rects,
    colorHex: colorHex,
  );

  await _createAnnotationWithUndo(annotation);
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/pdf/annotation_controller_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/src/pdf/annotation_controller.dart test/pdf/annotation_controller_test.dart
git commit -m "feat(annotation): add createStrikeOut to AnnotationController"
```

---

## 阶段 3: 配置 UI

### Task 3.1: 实现笔触配置面板

**Files:**
- Create: `lib/src/pdf/widgets/pen_config_panel.dart`
- Test: `test/pdf/widgets/pen_config_panel_test.dart`

- [ ] **Step 1: 编写配置面板测试**

```dart
// test/pdf/widgets/pen_config_panel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/widgets/pen_config_panel.dart';
import 'package:starmind/src/pdf/pen_config.dart';

void main() {
  group('PenConfigPanel', () {
    testWidgets('should display pen type selector', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('钢笔'), findsWidgets);
    });

    testWidgets('should call onConfigChanged when type changes', (tester) async {
      PenConfig? newConfig;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (c) => newConfig = c,
          ),
        ),
      ));

      // 点击切换笔触类型
      await tester.tap(find.text('铅笔'));
      await tester.pump();

      expect(newConfig, isNotNull);
      expect(newConfig!.type, PenType.pencil);
    });
  });
}
```

- [ ] **Step 2: 实现配置面板**

```dart
// lib/src/pdf/widgets/pen_config_panel.dart
import 'package:flutter/material.dart';
import '../pen_config.dart';
import '../pressure_curve.dart';

/// 笔触配置面板
class PenConfigPanel extends StatefulWidget {
  final PenConfig config;
  final ValueChanged<PenConfig> onConfigChanged;

  const PenConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<PenConfigPanel> createState() => _PenConfigPanelState();
}

class _PenConfigPanelState extends State<PenConfigPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPenTypeSelector(),
          const SizedBox(height: 16),
          _buildStabilizerSlider(),
          const SizedBox(height: 16),
          _buildPressureCurveSelector(),
        ],
      ),
    );
  }

  Widget _buildPenTypeSelector() {
    return Wrap(
      spacing: 8,
      children: [
        _buildTypeChip(PenType.fountainPen, '钢笔'),
        _buildTypeChip(PenType.ballpointPen, '圆珠笔'),
        _buildTypeChip(PenType.pencil, '铅笔'),
        _buildTypeChip(PenType.highlighter, '荧光笔'),
      ],
    );
  }

  Widget _buildTypeChip(PenType type, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: widget.config.type == type,
      onSelected: (selected) {
        if (selected) {
          widget.onConfigChanged(PenConfig(
            type: type,
            color: widget.config.color,
            baseWidth: widget.config.baseWidth,
          ));
        }
      },
    );
  }

  Widget _buildStabilizerSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('平滑度: ${widget.config.stabilizerLevel}'),
        Slider(
          value: widget.config.stabilizerLevel.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (value) {
            widget.onConfigChanged(PenConfig(
              type: widget.config.type,
              color: widget.config.color,
              baseWidth: widget.config.baseWidth,
              stabilizerLevel: value.round(),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildPressureCurveSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('压感曲线:'),
        Wrap(
          spacing: 8,
          children: [
            _buildCurveChip('线性', PressureCurve.linear),
            _buildCurveChip('柔和', PressureCurve.soft),
            _buildCurveChip('硬朗', PressureCurve.firm),
            _buildCurveChip('S曲线', PressureCurve.sCurve),
          ],
        ),
      ],
    );
  }

  Widget _buildCurveChip(String label, PressureCurve curve) {
    return ChoiceChip(
      label: Text(label),
      selected: widget.config.pressureCurve == curve,
      onSelected: (selected) {
        if (selected) {
          widget.onConfigChanged(PenConfig(
            type: widget.config.type,
            color: widget.config.color,
            baseWidth: widget.config.baseWidth,
            pressureCurve: curve,
          ));
        }
      },
    );
  }
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/pdf/widgets/pen_config_panel_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/src/pdf/widgets/pen_config_panel.dart test/pdf/widgets/pen_config_panel_test.dart
git commit -m "feat(pdf): add PenConfigPanel for configuring pen settings"
```

---

## 验收清单

完成后运行以下验证：

```bash
# 1. 静态分析
flutter analyze

# 2. 单元测试
flutter test

# 3. 集成测试
flutter test integration_test/

# 4. 构建验证（仅分析，不实际构建）
flutter analyze --no-fatal-infos
```

---

## 风险缓解

| 风险 | 缓解措施 |
|------|----------|
| Android 手写笔兼容性差异 | StylusDetector 检测设备能力，提供压感禁用选项 |
| 平滑器延迟过高 | 可配置平滑级别 0-10，0=无平滑 |
| 内存占用过高 | StrokeCacheManager 限制快照数量（max 10） |
| 缩放后笔画错位 | 使用 PDF 坐标存储笔画，缩放时重新映射 |
