# PDF 批注系统优化设计文档

**日期**: 2026-05-27
**版本**: 1.0
**状态**: 待实现

---

## 一、问题概述

### 1.1 当前问题

| 问题 | 描述 | 严重程度 |
|------|------|----------|
| PDF拖不动 | PDF缩小到小于视口时，平移手势失效 | 高 |
| 缩放卡顿 | 缩放时帧率低，有明显卡顿感 | 高 |
| 高分辨率渲染延迟 | 高清瓦片渲染延迟太大，用户等待时间长 | 中 |
| 批注位置偏移 | 缩放时批注位置发生错位 | 中 |
| 缩放范围不够 | 当前 0.5x-5x，需要更大范围 | 低 |
| 边界控制不自然 | 硬边界约束，缺乏弹性回弹 | 低 |

### 1.2 根因分析

1. **PDF拖不动**: `InteractiveCanvasViewer._matrixTranslate` 在 `boundaryRect < viewport` 时禁止所有平移
2. **缩放卡顿**: 每次缩放触发 Widget 重建 + Layout 计算，而非直接重绘
3. **渲染延迟**: 单一大瓦片渲染策略，未实现多级瓦片金字塔
4. **批注偏移**: 坐标转换逻辑在缩放时未正确处理 PDF↔Screen 映射

---

## 二、设计方案

### 2.1 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                     PdfViewportWidget                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐    ┌─────────────────────────────┐   │
│  │  GestureDispatcher   │    │ ViewportRepaintNotifier     │   │
│  │  (手势分发)           │───→│ (ValueNotifier直绘)          │   │
│  │  - isDrawGesture()   │    │ - zoom, panOffset           │   │
│  │  - multiTouchDetect  │    │ - 直接触发CustomPainter      │   │
│  └──────────────────────┘    └─────────────────────────────┘   │
│           │                              │                      │
│           ▼                              ▼                      │
│  ┌──────────────────────┐    ┌─────────────────────────────┐   │
│  │  InkCanvasLayer      │    │  PdfRenderLayer             │   │
│  │  (ChangeNotifier)    │    │  (ui.Picture缓存)            │   │
│  │  - StrokeStabilizer  │    │  - StaticPictureCache       │   │
│  │  - perfect_freehand  │    │  - TilePyramid              │   │
│  └──────────────────────┘    └─────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ElasticBoundary (弹性边界约束)                            │  │
│  │  - elasticity = 0.3                                      │  │
│  │  - snapBackThreshold = 50px                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

#### 2.2.1 GestureDispatcher（手势分发器）

**职责**: 区分绘制手势与导航手势，解决手势冲突

**实现要点**（参考 Saber `CanvasGestureDetector`）:
- 检测指针数量：单指=绘制/选择，双指=缩放/平移
- 检测设备类型：stylus 优先进入绘制模式
- 多指切换时取消当前绘制，转入导航模式

```dart
class GestureDispatcher {
  final Set<int> _activePointers = {};
  int? _drawingPointerId;
  bool _isDrawing = false;
  
  bool isDrawGesture(ScaleStartDetails details) {
    // 单指针 + stylus 或 批注模式激活
    return details.pointerCount == 1 && 
           (details.kind == PointerDeviceKind.stylus || _inkModeEnabled);
  }
  
  void onPointerDown(PointerDownEvent e) {
    _activePointers.add(e.pointer);
    
    if (_activePointers.length >= 2) {
      // 多指优先：取消绘制，转入导航
      _cancelDrawing();
      return;
    }
    
    if (_activePointers.length == 1 && isDrawGesture(e)) {
      _drawingPointerId = e.pointer;
      _startDrawing(e);
    }
  }
}
```

#### 2.2.2 ViewportRepaintNotifier（直绘通知器）

**职责**: 绑定 ValueNotifier 直接触发 CustomPainter 重绘，跳过 Widget/Layout

**实现要点**（参考 HandWriter `ActiveStrokeNotifier`）:

```dart
class ViewportRepaintNotifier extends ChangeNotifier {
  Offset _panOffset = Offset.zero;
  double _zoom = 1.0;
  
  void updateViewport(Offset pan, double zoom) {
    _panOffset = pan;
    _zoom = zoom;
    notifyListeners(); // 直接 notify → CustomPainter.repaint()
  }
  
  Offset get panOffset => _panOffset;
  double get zoom => _zoom;
}

// PdfPagePainter 绑定通知器
class PdfPagePainter extends CustomPainter {
  final ViewportRepaintNotifier repaintNotifier;
  
  PdfPagePainter({required this.repaintNotifier, ...}) {
    repaintNotifier.addListener(_onRepaint);
  }
  
  void _onRepaint() {
    // 不触发 setState，直接请求重绘
    _updateTransform();
  }
}
```

#### 2.2.3 ElasticBoundary（弹性边界）

**职责**: 修复"PDF小于视口时无法拖动"问题，实现弹性回弹

**实现要点**:

```dart
class ElasticBoundary {
  static const double elasticity = 0.3; // 拖出边界后30%阻力
  static const double snapBackThreshold = 50.0; // 回弹阈值
  static const Duration snapBackDuration = Duration(milliseconds: 200);
  
  /// 计算弹性约束后的平移位置
  static Offset constrain(Offset pan, Rect boundary, Rect viewport) {
    double dx = pan.dx;
    double dy = pan.dy;
    
    // PDF宽度小于视口时，允许弹性拖动
    if (boundary.width < viewport.width) {
      final centerOffset = (viewport.width - boundary.width) / 2;
      final excess = dx.abs() - centerOffset;
      if (excess > 0) {
        dx = dx.sign * (centerOffset + excess * elasticity);
      }
    } else {
      // PDF宽度大于视口，硬边界约束
      final minX = viewport.width - boundary.width;
      final maxX = 0.0;
      dx = dx.clamp(minX, maxX);
    }
    
    // 高度类似处理
    if (boundary.height < viewport.height) {
      final centerOffset = (viewport.height - boundary.height) / 2;
      final excess = dy.abs() - centerOffset;
      if (excess > 0) {
        dy = dy.sign * (centerOffset + excess * elasticity);
      }
    } else {
      final minY = viewport.height - boundary.height;
      final maxY = 0.0;
      dy = dy.clamp(minY, maxY);
    }
    
    return Offset(dx, dy);
  }
  
  /// 手势结束后回弹到合法位置
  static Offset snapBack(Offset pan, Rect boundary, Rect viewport) {
    final constrained = constrain(pan, boundary, viewport);
    if ((constrained - pan).distance > snapBackThreshold) {
      // 需要回弹动画
      return constrained;
    }
    return pan;
  }
}
```

#### 2.2.4 StaticPictureCache（Picture缓存）

**职责**: 缓存静态内容为 `ui.Picture`，避免每帧重绘

**实现要点**（参考 HandWriter `_StaticPictureCache`）:

```dart
class StaticPictureCache {
  static const int maxEntries = 6; // LRU 最大条目
  static const double zoomQuantum = 0.5; // 缩放分桶量子
  
  final Map<_CacheKey, ui.Picture> _cache = {};
  final List<_CacheKey> _lruOrder = [];
  
  ui.Picture? lookup(String pageId, double zoom) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);
    
    if (_cache.containsKey(key)) {
      _lruOrder.remove(key);
      _lruOrder.add(key); // LRU 更新
      return _cache[key];
    }
    return null;
  }
  
  void store(String pageId, double zoom, ui.Picture picture) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);
    
    // LRU 淘汰
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      final oldest = _lruOrder.removeAt(0);
      _cache.remove(oldest)?.dispose();
    }
    
    _cache[key] = picture;
    _lruOrder.add(key);
  }
  
  void dispose() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
    _lruOrder.clear();
  }
}

class _CacheKey {
  final String pageId;
  final int zoomBucket;
  
  _CacheKey(this.pageId, this.zoomBucket);
  
  @override
  bool operator ==(Object other) =>
      other is _CacheKey && pageId == other.pageId && zoomBucket == other.zoomBucket;
  
  @override
  int get hashCode => Object.hash(pageId, zoomBucket);
}
```

#### 2.2.5 TilePyramid（瓦片金字塔）

**职责**: 多级瓦片预渲染，解决高分辨率渲染延迟

**实现要点**:

```dart
class TilePyramid {
  // 缩放级别预渲染
  static const List<double> levels = [1.0, 1.5, 2.0, 3.0, 5.0, 10.0];
  
  final Map<double, List<_Tile>> _tiles = {};
  
  /// 获取最适合当前缩放的瓦片
  ui.Image? getTile(double zoom, Rect visibleRect) {
    final level = levels.firstWhere(
      (l) => zoom <= l,
      orElse: () => levels.last,
    );
    
    final tiles = _tiles[level];
    if (tiles == null) return null;
    
    // 查找覆盖可见区域的瓦片
    for (final tile in tiles) {
      if (tile.rect.contains(visibleRect)) {
        return tile.image;
      }
    }
    return null;
  }
  
  /// 预渲染瓦片（异步）
  Future<void> preRender(String docId, int pageIndex, Size pageSize) async {
    for (final level in levels) {
      final targetSize = pageSize * level;
      final tiles = _calculateTileGrid(targetSize);
      
      for (final tileRect in tiles) {
        final bytes = await PdfService().renderViewport(
          docId: docId,
          pageIndex: pageIndex,
          pdfLeft: tileRect.left / level,
          pdfTop: tileRect.top / level,
          pdfRight: tileRect.right / level,
          pdfBottom: tileRect.bottom / level,
          targetWidth: tileRect.width.round(),
          targetHeight: tileRect.height.round(),
        );
        
        final image = await _bytesToImage(bytes, tileRect.width.round(), tileRect.height.round());
        _tiles[level]?.add(_Tile(tileRect, image));
      }
    }
  }
}
```

#### 2.2.6 HighlightRenderer（高亮渲染器）

**职责**: 解决高亮笔重叠变色问题

**实现要点**（参考 Saber `_drawHighlighterStrokes`）:

```dart
void _drawHighlighterStrokes(Canvas canvas, Rect canvasRect, List<PdfHighlight> highlights) {
  final layerPaint = Paint()
    ..blendMode = BlendMode.darken // 关键：使用 darken 混合模式
    ..color = Colors.white.withAlpha(200);
  
  Color? lastColor;
  bool needRestore = false;
  
  for (final highlight in highlights) {
    final color = highlight.color;
    if (color != lastColor) {
      if (needRestore) canvas.restore();
      canvas.saveLayer(canvasRect, layerPaint); // 分层渲染
      needRestore = true;
      lastColor = color;
    }
    
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    for (final rect in highlight.rects) {
      canvas.drawRect(rect, paint);
    }
  }
  
  if (needRestore) canvas.restore();
}
```

---

## 三、实施计划

### 3.1 分阶段实施

| 阶段 | 内容 | 预估时间 |
|------|------|----------|
| 第一阶段 | 弹性边界修复 + PDF拖动问题 | 1-2天 |
| 第二阶段 | ValueNotifier直绘机制 | 2-3天 |
| 第三阶段 | Picture缓存 + 瓦片金字塔 | 3-4天 |
| 第四阶段 | 高亮渲染优化 + 缩放范围扩展 | 1-2天 |

### 3.2 文件修改清单

| 文件 | 修改内容 |
|------|----------|
| `lib/src/pdf/widgets/interactive_canvas_viewer.dart` | 添加 ElasticBoundary 支持 |
| `lib/src/pdf/widgets/pdf_viewport_widget.dart` | 集成 ViewportRepaintNotifier |
| `lib/src/pdf/pdf_viewport_controller.dart` | 扩展缩放范围至 0.3x-10x |
| `lib/src/pdf/widgets/ink_canvas_layer.dart` | 添加多指手势取消逻辑 |
| `lib/src/pdf/widgets/pdf_page_widget.dart` | 集成 StaticPictureCache |
| **新增** `lib/src/pdf/elastic_boundary.dart` | 弹性边界类 |
| **新增** `lib/src/pdf/static_picture_cache.dart` | Picture缓存类 |
| **新增** `lib/src/pdf/tile_pyramid.dart` | 瓦片金字塔类 |

---

## 四、参考项目

### 4.1 HandWriter (D:/product_study/HandWriter)

| 特性 | 文件位置 |
|------|----------|
| ValueNotifier直绘 | `lib/features/canvas/presentation/canvas_painter_notifiers.dart` |
| Picture缓存 | `lib/features/canvas/data/render_engine.dart` L111-127 |
| 弹性边界 | `lib/features/canvas/presentation/canvas_screen.dart` L3209-3304 |
| 设备自适应平滑 | `lib/features/canvas/presentation/canvas_painter_notifiers.dart` L62-192 |

### 4.2 Saber (D:/product_study/saber)

| 特性 | 文件位置 |
|------|----------|
| 手势分发 | `lib/components/canvas/canvas_gesture_detector.dart` |
| 高亮笔渲染 | `lib/components/canvas/_canvas_painter.dart` L80-105 |
| 双质量路径 | `lib/components/canvas/_stroke.dart` L223-251 |
| 页面虚拟化 | `lib/components/canvas/canvas_gesture_detector.dart` L600-655 |

---

## 五、验收标准

### 5.1 功能验收

- [ ] PDF缩小到小于视口时可以自由拖动
- [ ] 拖出边界后有弹性阻力，手势结束自动回弹
- [ ] 缩放操作帧率 ≥ 60fps（在标准设备上）
- [ ] 高分辨率瓦片渲染延迟 < 100ms
- [ ] 缩放时批注位置正确，无偏移
- [ ] 缩放范围 0.3x - 10x
- [ ] 高亮笔重叠区域颜色一致，不变深

### 5.2 性能验收

- [ ] 缩放时不触发 Widget rebuild（通过 ValueNotifier）
- [ ] Picture缓存命中率 ≥ 80%（正常使用场景）
- [ ] 内存增长可控（缓存条目限制）

---

## 六、风险与应对

| 风险 | 应对措施 |
|------|----------|
| Picture缓存内存占用 | 限制最大条目数，LRU淘汰策略 |
| 瓦片预渲染阻塞UI | 异步渲染，使用低分辨率先显示 |
| 手势分发复杂度增加 | 增加单元测试覆盖手势场景 |
| 坐标转换bug | 增加坐标转换单元测试 |

---

**设计完成，待用户批准后进入实现阶段。**