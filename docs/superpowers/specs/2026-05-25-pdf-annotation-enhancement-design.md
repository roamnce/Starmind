# PDF 阅读与批注功能增强设计文档

> 📅 创建日期：2026-05-25
> 🎯 目标：完善 PDF 阅读与批注功能，达到 GoodNotes 水平

---

## 1. 执行摘要

### 1.1 背景

Starmind 项目已有基础的 PDF 阅读和批注功能，但手写批注体验远未达到 GoodNotes 等专业笔记应用的水平。本设计旨在：

1. 增强手写批注的流畅度和笔触质量
2. 扩展 PDF 文本标记类型
3. 提供可配置的笔触参数

### 1.2 目标平台

| 平台         | 设备           | 手写笔                  |
| ------------ | -------------- | ----------------------- |
| Windows 桌面 | Surface Pro 等 | Surface Pen、通用触控笔 |
| Android 平板 | 华为 MatePad等 | 华为 M-Pencil           |

### 1.3 核心需求

| 类别         | 需求                                      |
| ------------ | ----------------------------------------- |
| **PDF 缩放** | 修复现有缩放 bug，实现流畅的双指缩放/平移 |
| PDF 文本标记 | 高亮、下划线、波浪线、删除线（4种）       |
| 手写笔触     | 钢笔、圆珠笔、铅笔、荧光笔、橡皮擦（5种） |
| 笔触配置     | 压感曲线、平滑度可自定义                  |
| 性能目标     | 手写延迟 < 16ms（60fps）                  |
| 暂不实现     | 导出功能、形状识别、AI 手写识别、拼写检查 |

### 1.4 设计原则

1. **保持 PDF 渲染质量**：不改变 Starmind 现有的 Pdfium 动态视口渲染
2. **保持文本选择能力**：现有的 `PdfTextSelectionManager` 继续工作
3. **渐进增强**：在现有架构上叠加增强，不破坏现有功能
4. **借鉴成熟实现**：吸收 Saber、Scribe Canvas、Fluera Canvas 的精华

---

## 2. PDF 缩放功能修复

### 2.1 当前问题分析

经过代码审查，发现 Starmind 现有的 PDF 缩放实现存在以下问题：

| 问题             | 现象                                                      | 根因                                                        |
| ---------------- | --------------------------------------------------------- | ----------------------------------------------------------- |
| 缩放不同步       | `InteractiveViewer` 与 `PdfViewportController` 状态不一致 | `_transformController` 与 `_zoom`/`_panOffset` 双向同步缺失 |
| 平移偏移计算错误 | 放大后平移距离不正确                                      | `panX = matrix.entry(0, 3) / zoom` 计算逻辑有误             |
| 缩放中心点漂移   | 双指缩放时视图跳动                                        | 未正确计算缩放中心点变换                                    |
| 边界约束缺失     | 缩小后 PDF 可移出视口                                     | `_applyCenteringIfNeeded()` 只处理水平方向                  |

### 2.2 修复方案

借鉴 Saber 的 `CanvasGestureDetector` 和 pdfrx 的 `PdfViewer` 实现：

```dart
/// PDF 视口控制器（修复版）
class PdfViewportController extends ChangeNotifier {
  // ── 视口状态 ──
  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;
  Size _viewportSize = Size.zero;

  // 缩放范围
  static const double minZoom = 0.3;
  static const double maxZoom = 10.0;

  /// 以指定中心点缩放
  void zoomAt(Offset focalPoint, double newZoom) {
    final clampedZoom = newZoom.clamp(minZoom, maxZoom);
    if (clampedZoom == _zoom) return;

    // 计算缩放中心点相对于 PDF 的位置
    final scaleRatio = clampedZoom / _zoom;

    // 调整平移偏移以保持中心点不变
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
    final scaledWidth = pdfSize.width * _zoom;
    final scaledHeight = pdfSize.height * _zoom;

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

    // 垂直约束（类似）
    if (scaledHeight <= viewportSize.height) {
      _panOffset = Offset(_panOffset.dx, (viewportSize.height - scaledHeight) / 2);
    } else {
      final minY = viewportSize.height - scaledHeight;
      final maxY = 0.0;
      _panOffset = Offset(_panOffset.dx, _panOffset.dy.clamp(minY, maxY));
    }

    notifyListeners();
  }
}
```

### 2.3 手势处理改进

```dart
/// PDF 手势处理器
class PdfGestureHandler {
  final PdfViewportController controller;

  // 手势状态
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

    // 检测缩放
    if ((scaleDelta - 1.0).abs() > 0.01) {
      _isZooming = true;
      controller.zoomAt(focalPoint, controller.zoom * scaleDelta);
      _lastScale = details.scale;
    }

    // 检测平移
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

    // 惯性滑动（可选）
    if (_isPanning && details.velocity.pixelsPerSecond.distance > 100) {
      _applyMomentum(details.velocity);
    }

    _lastFocalPoint = null;
  }
}
```

### 2.4 InteractiveViewer 替代方案

当前使用 `InteractiveViewer` 存在以下限制：

- 缩放/平移状态同步复杂
- 边界控制不灵活
- 与手写手势冲突

**推荐方案**：使用自定义手势处理器替代 `InteractiveViewer`：

```dart
/// PDF 视口组件（重构版）
class PdfViewportWidget extends StatefulWidget {
  @override
  State<PdfViewportWidget> createState() => _PdfViewportWidgetState();
}

class _PdfViewportWidgetState extends State<PdfViewportWidget> {
  final PdfGestureHandler _gestureHandler = PdfGestureHandler(...);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _gestureHandler.onScaleStart,
      onScaleUpdate: _gestureHandler.onScaleUpdate,
      onScaleEnd: (details) => _gestureHandler.onScaleEnd(
        details,
        _pdfSize,
        _viewportSize,
      ),
      child: CustomPaint(
        painter: PdfPagePainter(
          zoom: widget.controller.zoom,
          panOffset: widget.controller.panOffset,
          // ...
        ),
      ),
    );
  }
}
```

### 2.5 缩放与手写的协调

```dart
/// 手势路由器（更新版）
class GestureRouterDelegate {
  final bool isAnnotationMode;
  final bool palmRejectionEnabled;

  // 手势优先级
  // 1. 缩放：双指手势
  // 2. 平移：双指拖动（非缩放时）
  // 3. 书写：单指（批注模式 + 触控笔）

  void onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);

    // 双指缩放优先
    if (_activePointers.length >= 2) {
      _mode = GestureMode.zoom;
      return;
    }

    // 单指书写（批注模式 + 触控笔）
    if (isAnnotationMode && _isStylus(event)) {
      _mode = GestureMode.draw;
      _startStroke(event);
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    switch (_mode) {
      case GestureMode.zoom:
        _updateZoom(event);
        break;
      case GestureMode.draw:
        _updateStroke(event);
        break;
      case GestureMode.none:
        break;
    }
  }
}
```

---

## 3. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      PDF Viewport Widget                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ PDF Background Layer (Pdfium 视口裁剪渲染)                 │   │
│  │ - 动态 DPI 适配                                           │   │
│  │ - 视口裁剪渲染                                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ PDF Text Selection Layer                                  │   │
│  │ - 文本选择高亮                                            │   │
│  │ - 选择手柄                                                │   │
│  │ - 上下文菜单                                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Text Annotation Layer                                     │   │
│  │ - 高亮 (Highlight)                                        │   │
│  │ - 下划线 (Underline)                                      │   │
│  │ - 波浪线 (Wave/Squiggly)                                  │   │
│  │ - 删除线 (StrikeOut) ← 新增                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Committed Ink Layer                                       │   │
│  │ - ui.Picture 缓存                                         │   │
│  │ - 增量更新                                                │   │
│  │ - 撤销快照环形缓冲                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Active Stroke Layer                                       │   │
│  │ - 实时笔触绘制                                            │   │
│  │ - 笔触平滑器                                              │   │
│  │ - 双缓冲渲染                                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Gesture Router                                            │   │
│  │ - 单指书写检测                                            │   │
│  │ - 双指缩放/平移                                           │   │
│  │ - 手掌拒绝                                                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
用户输入 (PointerEvent)
    │
    ▼
┌────────────────────┐
│ Gesture Router     │ ← 路由：书写 vs 缩放/平移
└────────┬───────────┘
         │
         ▼ (书写模式)
┌────────────────────┐
│ Stroke Stabilizer  │ ← 三阶段平滑
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Pressure Curve     │ ← 压感曲线映射
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Active Stroke      │ ← 实时绘制
│ Layer              │
└────────┬───────────┘
         │ (笔画完成)
         ▼
┌────────────────────┐
│ Stroke Cache       │ ← 增量缓存 + 撤销快照
│ Manager            │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Annotation         │ ← 持久化
│ Controller         │
└────────────────────┘
```

---

## 3. 核心组件设计

### 3.1 EnhancedInkStroke（增强笔触模型）

```dart
/// 笔触类型
enum PenType {
  fountainPen,   // 钢笔 - 流畅、有压感变化
  ballpointPen,  // 圆珠笔 - 均匀、无压感
  pencil,        // 铅笔 - 纹理、轻压感
  highlighter,   // 荧光笔 - 半透明、宽笔触
  eraser,        // 橡皮擦 - 擦除模式
}

/// 笔触配置
class PenConfig {
  final PenType type;
  final Color color;
  final double baseWidth;
  final double opacity;
  final PressureCurve pressureCurve;
  final int stabilizerLevel;  // 0-10
  final bool pressureEnabled;

  // 预设配置
  static PenConfig fountainPen({Color color = Colors.black}) => PenConfig(
    type: PenType.fountainPen,
    color: color,
    baseWidth: 2.0,
    pressureCurve: PressureCurve.soft,
    stabilizerLevel: 3,
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

  // ... 其他预设
}

/// 增强笔触数据模型
class EnhancedInkStroke {
  final String id;
  final int pageIndex;
  final List<StrokePoint> points;
  final List<double> widths;  // 变宽笔触
  final PenConfig config;
  final DateTime createdAt;

  /// 精确命中检测（用于橡皮擦和选择）
  bool isPointNear(Offset point, double threshold) {
    // 快速边界框剔除
    if (!bounds.inflate(threshold).contains(point)) return false;

    // 精确线段检测
    for (int i = 0; i < points.length - 1; i++) {
      if (_distToSegment(point, points[i].offset, points[i + 1].offset) <= threshold) {
        return true;
      }
    }
    return false;
  }

  Rect get bounds { /* 计算边界 */ }

  Map<String, dynamic> toJson() { /* 序列化 */ }
  factory EnhancedInkStroke.fromJson(Map<String, dynamic> json) { /* 反序列化 */ }
}

/// 笔触点（带压感）
class StrokePoint {
  final Offset offset;
  final double pressure;
  final int timestamp;  // 微秒，用于速度计算
}
```

### 3.2 StrokeStabilizer（笔触平滑器）

借鉴 Fluera Canvas 的三阶段平滑算法：

```
原始输入点
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: String Pulling (拉线平滑)                              │
│ - 过滤手部抖动                                                  │
│ - 要求最小移动距离后才响应                                       │
│ - 弹性字符串长度（快速移动时缩短）                                │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: Weighted Moving Average (加权移动平均)                 │
│ - 滑动窗口平滑                                                  │
│ - 最新点权重最高                                                │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: Corner Detection (转角检测)                            │
│ - 检测方向突变                                                  │
│ - 在转角处减少平滑以保留锐利角落                                 │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
平滑后的输出点
```

```dart
class StrokeStabilizer {
  int level;  // 0-10，0=无平滑，10=最大平滑
  bool elasticEnabled;

  /// 平滑位置
  Offset stabilize(Offset rawPoint, {int? timestampUs});

  /// 平滑压感
  double stabilizePressure(double rawPressure);

  /// 笔画结束时生成补偿点（闭合稳定器造成的间隙）
  List<Offset> finalize(Offset finalRawPoint, {int steps = 4});

  /// 重置状态
  void reset();
}
```

### 3.3 PressureCurve（压感曲线）

借鉴 Fluera Canvas 的贝塞尔曲线压感映射：

```dart
/// 压感曲线 - 使用三次贝塞尔曲线映射原始压感到输出压感
class PressureCurve {
  final Offset p1;  // 控制点1
  final Offset p2;  // 控制点2
  // p0=(0,0), p3=(1,1) 隐含

  // 预设曲线
  static const linear = PressureCurve(p1: Offset(0.25, 0.25), p2: Offset(0.75, 0.75));
  static const soft = PressureCurve(p1: Offset(0.15, 0.45), p2: Offset(0.55, 0.90));
  static const firm = PressureCurve(p1: Offset(0.45, 0.10), p2: Offset(0.85, 0.55));
  static const sCurve = PressureCurve(p1: Offset(0.25, 0.05), p2: Offset(0.75, 0.95));
  static const heavy = PressureCurve(p1: Offset(0.60, 0.05), p2: Offset(0.95, 0.40));

  /// 评估压感值
  double evaluate(double rawPressure);
}
```

### 3.4 StrokeCacheManager（笔画缓存管理器）

借鉴 Scribe Canvas 和 Fluera Canvas：

```dart
/// 笔画缓存管理器 - 支持增量更新和撤销快照
class StrokeCacheManager {
  ui.Picture? _cachedPicture;
  int _cachedStrokeCount = 0;

  /// 撤销快照环形缓冲
  final LinkedHashMap<int, ui.Picture> _undoSnapshots = LinkedHashMap();
  static const int maxUndoSnapshots = 10;

  /// 获取当前缓存
  ui.Picture? get cachedPicture;

  /// 检查缓存是否有效
  bool isCacheValid(int totalStrokes);

  /// 尝试从撤销快照恢复（O(1) 撤销）
  bool tryRestoreFromUndoSnapshot(int targetStrokeCount);

  /// 同步创建缓存
  void createCacheSynchronously(
    List<EnhancedInkStroke> strokes,
    void Function(Canvas, EnhancedInkStroke) drawStrokeCallback,
    Size size,
  );

  /// 增量更新缓存（只添加新笔画）
  void updateCache(
    List<EnhancedInkStroke> newStrokes,
    void Function(Canvas, EnhancedInkStroke) drawStrokeCallback,
  );

  /// 绘制缓存到画布
  bool drawCached(Canvas canvas);

  /// 清理资源
  void dispose();
}
```

### 3.5 AnnotationController 扩展

扩展现有的 `AnnotationController`：

```dart
class AnnotationController extends ChangeNotifier {
  // ... 现有实现 ...

  // 新增：笔画缓存管理器（每页一个）
  final Map<int, StrokeCacheManager> _pageCacheManagers = {};

  // 新增：创建手写批注（增强版）
  Future<void> createEnhancedInk({
    required int pageIndex,
    required EnhancedInkStroke stroke,
  });

  // 新增：删除线批注
  Future<void> createStrikeOut({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  });

  // 新增：获取页面笔画缓存
  StrokeCacheManager getCacheManager(int pageIndex);
}
```

---

## 4. 渲染层设计

### 4.1 分层渲染

```dart
/// PDF 视口组件（增强版）
class EnhancedPdfViewport extends StatefulWidget {
  final PdfDocument document;
  final AnnotationController annotationController;
  final PenConfig currentPen;
  final bool isAnnotationMode;

  @override
  State<EnhancedPdfViewport> createState() => _EnhancedPdfViewportState();
}

class _EnhancedPdfViewportState extends State<EnhancedPdfViewport> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: PDF 背景（保持现有实现）
        PdfBackgroundLayer(document: widget.document),

        // Layer 2: 文本选择层（保持现有实现）
        PdfTextSelectionLayer(document: widget.document),

        // Layer 3: 文本批注层（扩展：支持删除线）
        TextAnnotationLayer(
          annotations: _textAnnotations,
          pageIndex: _currentPageIndex,
        ),

        // Layer 4: 已提交笔画层（增强：ui.Picture 缓存）
        CommittedInkLayer(
          cacheManager: _strokeCacheManager,
          pageIndex: _currentPageIndex,
        ),

        // Layer 5: 活跃笔画层（增强：平滑器 + 双缓冲）
        ActiveInkLayer(
          currentStroke: _currentStroke,
          stabilizer: _stabilizer,
        ),

        // Layer 6: 手势路由层
        GestureRouterLayer(
          onStrokeStart: _onStrokeStart,
          onStrokeUpdate: _onStrokeUpdate,
          onStrokeEnd: _onStrokeEnd,
          onZoom: _onZoom,
          onPan: _onPan,
        ),
      ],
    );
  }
}
```

### 4.2 活跃笔画渲染（双缓冲）

```dart
/// 活跃笔画渲染器
class ActiveInkPainter extends CustomPainter {
  final EnhancedInkStroke? currentStroke;
  final StrokeStabilizer stabilizer;
  final double scale;

  // 双缓冲
  ui.Picture? _bufferedPicture;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制已缓存的笔画
    if (_bufferedPicture != null) {
      canvas.drawPicture(_bufferedPicture!);
    }

    // 2. 绘制当前笔画（实时）
    if (currentStroke != null && !currentStroke!.isEmpty) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, EnhancedInkStroke stroke) {
    final paint = _createPaint(stroke.config);
    final path = _createPath(stroke);
    canvas.drawPath(path, paint);
  }

  /// 笔画完成时更新缓存
  void commitStroke(EnhancedInkStroke stroke) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 重绘已有缓存
    if (_bufferedPicture != null) {
      canvas.drawPicture(_bufferedPicture!);
    }

    // 添加新笔画
    _drawStroke(canvas, stroke);

    _bufferedPicture?.dispose();
    _bufferedPicture = recorder.endRecording();
  }
}
```

---

## 5. 手势路由设计

### 5.1 手势检测逻辑

```dart
/// 手势路由器
class GestureRouterDelegate {
  final bool isAnnotationMode;
  final bool palmRejectionEnabled;

  // 活跃指针追踪
  final Set<int> _activePointers = {};
  int? _drawingPointerId;

  void onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);

    // 手掌拒绝：只接受触控笔
    if (palmRejectionEnabled && event.kind != PointerDeviceKind.stylus) {
      return;
    }

    // 单指书写检测
    if (_activePointers.length == 1 && isAnnotationMode) {
      _drawingPointerId = event.pointer;
      _startStroke(event.localPosition, event.pressure);
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    // 只处理绘制指针
    if (_drawingPointerId != event.pointer) return;

    _updateStroke(event.localPosition, event.pressure, event.timeStamp);
  }

  void onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);

    if (_drawingPointerId == event.pointer) {
      _drawingPointerId = null;
      _endStroke();
    }
  }

  // 双指缩放/平移在父级处理
}
```

### 5.2 Android 手写笔兼容

```dart
/// 手写笔检测器
class StylusDetector {
  /// 检测是否为有效手写笔
  static bool isStylus(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.stylus ||
           kind == PointerDeviceKind.invertedStylus;
  }

  /// 检测是否支持压感
  static bool hasPressure(PointerEvent event) {
    return event.pressure > 0 && event.pressure < 1.0;
  }

  /// 获取规范化压感值
  static double normalizePressure(PointerEvent event) {
    // 不同设备的压感范围可能不同
    return event.pressure.clamp(0.0, 1.0);
  }
788
```

---

## 6. 文本批注扩展

### 6.1 删除线批注

扩展现有 `AnnotationType` 枚举：

```dart
enum AnnotationType {
  highlight,
  underline,
  wave,
  strikeOut,  // 新增：删除线
  ink,
  note,
}

// Annotation 类中新增工厂方法
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
    category: AnnotationCategory.standard,  // 标准批注，可导出
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

### 6.2 删除线渲染

```dart
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
      // 绘制水平删除线穿过文本
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

---

## 7. 性能优化策略

### 7.1 渲染优化

| 优化点   | 策略                  | 效果          |
| -------- | --------------------- | ------------- |
| 笔画缓存 | `ui.Picture` 离屏录制 | O(1) 重绘     |
| 增量更新 | 只渲染新笔画          | 减少 GPU 负载 |
| 撤销快照 | 环形缓冲缓存          | O(1) 撤销     |
| 双缓冲   | 活跃笔画独立缓冲      | 避免 UI 卡顿  |
| 视口裁剪 | 只渲染可见区域        | 减少渲染面积  |

### 7.2 输入优化

| 优化点     | 策略               | 效果               |
| ---------- | ------------------ | ------------------ |
| 手掌拒绝   | 只接受 stylus 事件 | 避免误触           |
| 笔触简化   | RDP 算法压缩点数   | 减少存储和渲染开销 |
| 平滑器级别 | 0-10 可配置        | 平衡延迟和平滑度   |

### 7.3 预期性能指标

| 指标     | 目标值          |
| -------- | --------------- |
| 手写延迟 | < 16ms（60fps） |
| 撤销响应 | < 5ms           |
| 页面切换 | < 100ms         |
| 内存占用 | 每页 < 10MB     |

---

## 8. 文件结构

```
lib/src/
├── domain/
│   ├── annotation.dart          # 扩展：新增 strikeOut 类型
│   ├── ink_stroke.dart          # 简化版，保留兼容
│   └── enhanced_ink_stroke.dart # 新增：增强笔触模型
│
├── pdf/
│   ├── annotation_controller.dart  # 扩展：删除线支持
│   ├── stroke_stabilizer.dart      # 新增：笔触平滑器
│   ├── pressure_curve.dart         # 新增：压感曲线
│   ├── stroke_cache_manager.dart   # 新增：笔画缓存
│   ├── pen_config.dart             # 新增：笔触配置
│   ├── stylus_detector.dart        # 新增：手写笔检测
│   │
│   └── widgets/
│       ├── enhanced_pdf_viewport.dart    # 新增：增强视口
│       ├── committed_ink_layer.dart       # 新增：已提交笔画层
│       ├── active_ink_layer.dart         # 新增：活跃笔画层
│       ├── text_annotation_layer.dart    # 扩展：删除线渲染
│       ├── gesture_router_delegate.dart  # 新增：手势路由
│       ├── pen_config_panel.dart         # 新增：笔触配置面板
│       └── stroke_renderer.dart          # 新增：笔触渲染器
│
└── rust/
    └── storage/
        └── annotations.dart      # 扩展：存储删除线
```

---

## 9. 实施阶段

### 阶段 0：PDF 缩放修复（1 周）⭐ 最高优先级

缩放是手写与批注的基础，必须首先修复。

- [ ] 重构 `PdfViewportController`
  - [ ] 实现 `zoomAt()` 方法（以指定中心点缩放）
  - [ ] 修复平移偏移计算逻辑
  - [ ] 实现完整的边界约束（水平 + 垂直）
- [ ] 实现 `PdfGestureHandler`
  - [ ] 替代 `InteractiveViewer` 的自定义手势处理
  - [ ] 缩放/平移手势检测与分离
  - [ ] 惯性滑动支持（可选）
- [ ] 更新 `PdfViewportWidget`
  - [ ] 移除 `InteractiveViewer` 依赖
  - [ ] 集成自定义手势处理器
  - [ ] 与 `PdfViewportController` 状态同步
- [ ] 缩放与手写手势协调
  - [ ] 双指缩放优先级最高
  - [ ] 单指书写检测（批注模式 + 触控笔）
  - [ ] 手势模式切换无冲突
- [ ] 测试验证
  - [ ] 缩放中心点正确性
  - [ ] 边界约束完整性
  - [ ] 缩放/平移/书写无冲突

---

### 阶段 1：核心增强（2 周）

- [ ] 实现 `EnhancedInkStroke` 数据模型
- [ ] 实现 `StrokeStabilizer` 平滑器
- [ ] 实现 `PressureCurve` 压感曲线
- [ ] 实现 `StrokeCacheManager` 缓存管理器

### 阶段 2：渲染层重构（2 周）

- [ ] 实现 `CommittedInkLayer`
- [ ] 实现 `ActiveInkLayer`（双缓冲）
- [ ] 实现 `StrokeRenderer`
- [ ] 集成到 PDF 视口

### 阶段 3：手势与交互（1 周）

- [ ] 实现 `GestureRouterDelegate`
- [ ] 实现 `StylusDetector`
- [ ] 手掌拒绝测试

### 阶段 4：文本批注扩展（1 周）

- [ ] 扩展 `AnnotationType.strikeOut`
- [ ] 实现删除线渲染
- [ ] 更新 `AnnotationController`

### 阶段 5：配置 UI（1 周）

- [ ] 实现 `PenConfigPanel`
- [ ] 压感曲线编辑器
- [ ] 平滑度滑块

### 阶段 6：测试与优化（1 周）

- [ ] 性能测试
- [ ] 多设备兼容测试
- [ ] 边界情况处理

---

## 10. 风险与缓解

| 风险                     | 影响               | 缓解措施                   |
| ------------------------ | ------------------ | -------------------------- |
| Android 手写笔兼容性差异 | 部分设备压感不可用 | 提供压感禁用选项           |
| 平滑器延迟过高           | 书写不跟手         | 可配置平滑级别（0=无平滑） |
| 内存占用过高             | 页面过多时崩溃     | 惰性加载 + LRU 缓存淘汰    |
| PDF 缩放后笔画错位       | 坐标系统不一致     | 使用 PDF 坐标存储笔画      |

---

## 11. 验收标准

| 功能       | 验收标准                       |
| ---------- | ------------------------------ |
| 手写流畅度 | 快速书写时无明显延迟，笔画平滑 |
| 压感响应   | 压感变化能正确反映在笔画宽度上 |
| 橡皮擦     | 能精确擦除笔画，不误删         |
| 删除线     | 能正确添加和渲染删除线批注     |
| 撤销/重做  | O(1) 响应，无明显卡顿          |
| 多页文档   | 翻页后批注正确显示             |

---

## 12. 参考资料

### 借鉴项目

| 项目              | 借鉴内容                                                                  |
| ----------------- | ------------------------------------------------------------------------- |
| **Saber**         | `Stroke` 模型、`perfect_freehand` 平滑、分层渲染架构                      |
| **Scribe Canvas** | `ui.Picture` 缓存、`isPointNear()` 命中检测、增量更新                     |
| **Fluera Canvas** | `PressureCurve` 压感曲线、`StrokeStabilizer` 三阶段平滑、撤销快照环形缓冲 |

### 相关文件

- `lib/src/domain/annotation.dart` - 现有批注模型
- `lib/src/pdf/annotation_controller.dart` - 现有批注控制器
- `lib/src/pdf/widgets/ink_canvas_layer.dart` - 现有手写层
- `lib/components/canvas/_stroke.dart` (Saber) - 笔触模型参考
- `lib/components/canvas/_canvas_painter.dart` (Saber) - 渲染器参考
