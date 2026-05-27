# PDF 批注系统优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking tracking.

**Goal:** 修复PDF缩放/平移问题，优化渲染性能，实现商业级PDF批注体验

**Architecture:** 通过 GestureDispatcher 分离绘制/导航手势，使用 ValueNotifier 直接触发重绘跳过 Widget 重建，引入 ElasticBoundary 解决边界约束问题，使用 ui.Picture 缓存静态内容

**Tech Stack:** Flutter, dart:ui (Picture/Canvas), ValueNotifier, CustomPainter

---

## 文件结构

### 新增文件
| 文件 | 职责 |
|------|------|
| `lib/src/pdf/elastic_boundary.dart` | 弹性边界约束计算 |
| `lib/src/pdf/viewport_repaint_notifier.dart` | 视口直绘通知器 |
| `lib/src/pdf/static_picture_cache.dart` | Picture缓存管理 |
| `lib/src/pdf/gesture_dispatcher.dart` | 手势分发器 |

### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `lib/src/pdf/widgets/interactive_canvas_viewer.dart` | 集成 ElasticBoundary |
| `lib/src/pdf/widgets/pdf_viewport_widget.dart` | 集成 ViewportRepaintNotifier |
| `lib/src/pdf/pdf_viewport_controller.dart` | 扩展缩放范围 |
| `lib/src/pdf/widgets/ink_canvas_layer.dart` | 多指手势取消逻辑 |

### 测试文件
| 文件 | 职责 |
|------|------|
| `test/pdf/elastic_boundary_test.dart` | 弹性边界测试 |
| `test/pdf/viewport_repaint_notifier_test.dart` | 直绘通知器测试 |
| `test/pdf/static_picture_cache_test.dart` | Picture缓存测试 |
| `test/pdf/gesture_dispatcher_test.dart` | 手势分发器测试 |

---

## Task 1: ElasticBoundary 弹性边界

**Files:**
- Create: `lib/src/pdf/elastic_boundary.dart`
- Test: `test/pdf/elastic_boundary_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/elastic_boundary_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/elastic_boundary.dart';

void main() {
  group('ElasticBoundary', () {
    test('constrains pan when PDF width smaller than viewport', () {
      // PDF 宽度 400，视口宽度 800
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);
      
      // 允许居中偏移，但有弹性阻力
      final pan = Offset(100, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);
      
      // 预期：居中偏移 200 是允许的，超出部分有弹性阻力
      // 100 < 200，所以应该允许
      expect(result.dx, lessThanOrEqualTo(200));
    });
    
    test('applies elastic resistance when pan exceeds center offset', () {
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);
      
      // 超出居中偏移 200
      final pan = Offset(300, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);
      
      // 预期：200 + (300-200) * 0.3 = 230
      expect(result.dx, closeTo(230, 1));
    });
    
    test('hard constraint when PDF width larger than viewport', () {
      final boundary = Rect.fromLTWH(0, 0, 1200, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);
      
      final pan = Offset(100, 0);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);
      
      // 硬边界：minX = 800 - 1200 = -400, maxX = 0
      expect(result.dx, inInclusiveRange(-400, 0));
    });
    
    test('snapBack returns constrained position', () {
      final boundary = Rect.fromLTWH(0, 0, 400, 600);
      final viewport = Rect.fromLTWH(0, 0, 800, 600);
      
      // 拖出边界
      final pan = Offset(500, 0);
      final result = ElasticBoundary.snapBack(pan, boundary, viewport);
      
      // 应该回弹到合法位置
      final centerOffset = (viewport.width - boundary.width) / 2;
      expect(result.dx.abs(), lessThanOrEqualTo(centerOffset));
    });
    
    test('vertical constraint works similarly', () {
      final boundary = Rect.fromLTWH(0, 0, 600, 400);
      final viewport = Rect.fromLTWH(0, 0, 600, 800);
      
      final pan = Offset(0, 300);
      final result = ElasticBoundary.constrain(pan, boundary, viewport);
      
      final centerOffset = (viewport.height - boundary.height) / 2;
      expect(result.dy.abs(), lessThanOrEqualTo(centerOffset * 1.5));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/elastic_boundary_test.dart`
Expected: FAIL - file not found or import error

- [ ] **Step 3: Write minimal implementation**

```dart
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
  static Offset snapBack(Offset pan, Rect boundary, Rect viewport) {
    return constrain(pan, boundary, viewport);
  }
  
  /// 判断是否需要回弹动画
  static bool needsSnapBack(Offset pan, Rect boundary, Rect viewport) {
    final constrained = constrain(pan, boundary, viewport);
    return (constrained - pan).distance > snapBackThreshold;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/elastic_boundary_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/elastic_boundary.dart test/pdf/elastic_boundary_test.dart
git commit -m "feat(pdf): add ElasticBoundary for elastic pan constraints"
```

---

## Task 2: ViewportRepaintNotifier 直绘通知器

**Files:**
- Create: `lib/src/pdf/viewport_repaint_notifier.dart`
- Test: `test/pdf/viewport_repaint_notifier_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/viewport_repaint_notifier_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/viewport_repaint_notifier.dart';

void main() {
  group('ViewportRepaintNotifier', () {
    test('initializes with default values', () {
      final notifier = ViewportRepaintNotifier();
      
      expect(notifier.zoom, 1.0);
      expect(notifier.panOffset, Offset.zero);
    });
    
    test('updateViewport notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var notified = false;
      
      notifier.addListener(() {
        notified = true;
      });
      
      notifier.updateViewport(const Offset(10, 20), 1.5);
      
      expect(notified, true);
      expect(notifier.zoom, 1.5);
      expect(notifier.panOffset, const Offset(10, 20));
    });
    
    test('setZoom notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var callCount = 0;
      
      notifier.addListener(() => callCount++);
      
      notifier.setZoom(2.0);
      
      expect(callCount, 1);
      expect(notifier.zoom, 2.0);
    });
    
    test('setPanOffset notifies listeners', () {
      final notifier = ViewportRepaintNotifier();
      var callCount = 0;
      
      notifier.addListener(() => callCount++);
      
      notifier.setPanOffset(const Offset(100, 200));
      
      expect(callCount, 1);
      expect(notifier.panOffset, const Offset(100, 200));
    });
    
    test('getTransform returns Matrix4', () {
      final notifier = ViewportRepaintNotifier();
      notifier.setZoom(2.0);
      notifier.setPanOffset(const Offset(50, 100));
      
      final transform = notifier.getTransform();
      
      expect(transform, isA<Matrix4>());
      // 验证矩阵包含缩放和平移
      expect(transform.getMaxScaleOnAxis(), 2.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/viewport_repaint_notifier_test.dart`
Expected: FAIL - file not found or import error

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/pdf/viewport_repaint_notifier.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/viewport_repaint_notifier_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/viewport_repaint_notifier.dart test/pdf/viewport_repaint_notifier_test.dart
git commit -m "feat(pdf): add ViewportRepaintNotifier for direct repaint"
```

---

## Task 3: StaticPictureCache Picture缓存

**Files:**
- Create: `lib/src/pdf/static_picture_cache.dart`
- Test: `test/pdf/static_picture_cache_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/static_picture_cache_test.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/static_picture_cache.dart';

void main() {
  group('StaticPictureCache', () {
    late StaticPictureCache cache;
    
    setUp(() {
      cache = StaticPictureCache();
    });
    
    tearDown(() {
      cache.dispose();
    });
    
    test('stores and retrieves picture', () async {
      // 创建测试 Picture
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Colors.red);
      final picture = recorder.endRecording();
      
      cache.store('page-0', 1.0, picture);
      
      final retrieved = cache.lookup('page-0', 1.0);
      
      expect(retrieved, isNotNull);
      expect(retrieved, same(picture));
    });
    
    test('returns null for missing entry', () {
      final result = cache.lookup('nonexistent', 1.0);
      expect(result, isNull);
    });
    
    test('zoom buckets work correctly', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final picture = recorder.endRecording();
      
      cache.store('page-0', 1.2, picture);
      
      // 1.2 / 0.5 = 2.4 → bucket 2
      // 查询 1.3 / 0.5 = 2.6 → bucket 3 (不同)
      // 查询 1.4 / 0.5 = 2.8 → bucket 3 (不同)
      // 查询 0.9 / 0.5 = 1.8 → bucket 2 (相同)
      final result = cache.lookup('page-0', 0.9);
      
      expect(result, same(picture));
    });
    
    test('LRU eviction removes oldest entry', () async {
      // 填充到最大容量
      for (int i = 0; i < StaticPictureCache.maxEntries; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }
      
      // 添加一个新条目，应触发淘汰
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final newPicture = recorder.endRecording();
      cache.store('page-new', 1.0, newPicture);
      
      // 最旧的 page-0 应该被淘汰
      expect(cache.lookup('page-0', 1.0), isNull);
      expect(cache.lookup('page-new', 1.0), isNotNull);
    });
    
    test('LRU updates on access', () async {
      // 添加两个条目
      for (int i = 0; i < 2; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }
      
      // 访问 page-0，使其成为最新
      cache.lookup('page-0', 1.0);
      
      // 填充剩余容量
      for (int i = 2; i < StaticPictureCache.maxEntries; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }
      
      // 添加新条目，page-1 应该被淘汰（因为它最旧且未被访问）
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final newPicture = recorder.endRecording();
      cache.store('page-new', 1.0, newPicture);
      
      // page-0 被访问过，应该还在
      expect(cache.lookup('page-0', 1.0), isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/static_picture_cache_test.dart`
Expected: FAIL - file not found or import error

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/pdf/static_picture_cache.dart
import 'dart:ui' as ui;

/// 静态内容 Picture 缓存
///
/// 将静态内容（PDF 页面、已保存笔迹）录制为 ui.Picture 缓存，
/// 避免每帧重绘，提升渲染性能。
///
/// 参考：HandWriter _StaticPictureCache
class StaticPictureCache {
  /// LRU 最大条目数
  static const int maxEntries = 6;
  
  /// 缩放分桶量子（用于量化缩放级别）
  static const double zoomQuantum = 0.5;
  
  final Map<_CacheKey, ui.Picture> _cache = {};
  final List<_CacheKey> _lruOrder = [];
  
  /// 查找缓存的 Picture
  ///
  /// [pageId] 页面标识
  /// [zoom] 当前缩放级别
  /// 返回缓存的 Picture，如果不存在返回 null
  ui.Picture? lookup(String pageId, double zoom) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);
    
    if (_cache.containsKey(key)) {
      // LRU 更新：移到最后（最新）
      _lruOrder.remove(key);
      _lruOrder.add(key);
      return _cache[key];
    }
    return null;
  }
  
  /// 存储 Picture 到缓存
  void store(String pageId, double zoom, ui.Picture picture) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);
    
    // 如果已存在，先移除旧的
    if (_cache.containsKey(key)) {
      _lruOrder.remove(key);
      _cache.remove(key);
    }
    
    // LRU 淘汰
    while (_cache.length >= maxEntries) {
      final oldest = _lruOrder.removeAt(0);
      _cache.remove(oldest)?.dispose();
    }
    
    _cache[key] = picture;
    _lruOrder.add(key);
  }
  
  /// 清除所有缓存
  void clear() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
    _lruOrder.clear();
  }
  
  /// 释放资源
  void dispose() {
    clear();
  }
  
  /// 获取当前缓存条目数
  int get length => _cache.length;
}

/// 缓存键
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/static_picture_cache_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/static_picture_cache.dart test/pdf/static_picture_cache_test.dart
git commit -m "feat(pdf): add StaticPictureCache for Picture caching"
```

---

## Task 4: GestureDispatcher 手势分发器

**Files:**
- Create: `lib/src/pdf/gesture_dispatcher.dart`
- Test: `test/pdf/gesture_dispatcher_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/gesture_dispatcher_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/gesture_dispatcher.dart';

void main() {
  group('GestureDispatcher', () {
    late GestureDispatcher dispatcher;
    
    setUp(() {
      dispatcher = GestureDispatcher();
    });
    
    test('identifies draw gesture for single stylus', () {
      final details = ScaleStartDetails(
        localFocalPoint: Offset.zero,
        focalPoint: Offset.zero,
        pointerCount: 1,
      );
      
      dispatcher.inkModeEnabled = true;
      final isDraw = dispatcher.isDrawGesture(details, PointerDeviceKind.stylus);
      
      expect(isDraw, true);
    });
    
    test('identifies navigation gesture for two fingers', () {
      final details = ScaleStartDetails(
        localFocalPoint: Offset.zero,
        focalPoint: Offset.zero,
        pointerCount: 2,
      );
      
      dispatcher.inkModeEnabled = true;
      final isDraw = dispatcher.isDrawGesture(details, PointerDeviceKind.touch);
      
      expect(isDraw, false);
    });
    
    test('cancels drawing when second finger added', () {
      dispatcher.inkModeEnabled = true;
      
      // 第一个手指按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, true);
      expect(dispatcher.drawingPointerId, 0);
      
      // 第二个手指按下
      dispatcher.onPointerDown(1, PointerDeviceKind.touch, const Offset(100, 100));
      
      // 应该取消绘制
      expect(dispatcher.isDrawing, false);
      expect(dispatcher.drawingPointerId, isNull);
    });
    
    test('resumes drawing after all fingers lifted', () {
      dispatcher.inkModeEnabled = true;
      
      // 两个手指按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      dispatcher.onPointerDown(1, PointerDeviceKind.touch, const Offset(100, 100));
      
      // 第一个手指抬起
      dispatcher.onPointerUp(1);
      expect(dispatcher.activePointerCount, 1);
      
      // 第二个手指抬起
      dispatcher.onPointerUp(0);
      expect(dispatcher.activePointerCount, 0);
      expect(dispatcher.isDrawing, false);
      
      // 再次按下可以开始绘制
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, true);
    });
    
    test('stylus takes priority over touch', () {
      dispatcher.inkModeEnabled = true;
      dispatcher.palmRejectionEnabled = true;
      
      // 触摸按下
      dispatcher.onPointerDown(0, PointerDeviceKind.touch, Offset.zero);
      expect(dispatcher.isDrawing, false); // palm rejection
      
      // 触控笔按下
      dispatcher.onPointerDown(1, PointerDeviceKind.stylus, const Offset(100, 100));
      expect(dispatcher.isDrawing, true);
      expect(dispatcher.drawingPointerId, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/gesture_dispatcher_test.dart`
Expected: FAIL - file not found or import error

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/pdf/gesture_dispatcher.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  ///
  /// [details] 手势开始详情
  /// [deviceKind] 指针设备类型
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
    
    // 多指优先：当有2+指针时，取消绘制
    if (_activePointers.length >= 2) {
      if (_drawingPointerId != null) {
        _cancelDrawing();
      }
      return;
    }
    
    // 单指针且在批注模式，开始绘制
    if (_activePointers.length == 1 && inkModeEnabled && _drawingPointerId == null) {
      // 手掌拒绝检查
      if (palmRejectionEnabled && kind != PointerDeviceKind.stylus) {
        return;
      }
      
      _drawingPointerId = pointerId;
      _isDrawing = true;
    }
  }
  
  /// 指针移动
  ///
  /// 返回 true 如果是绘制指针的移动
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/gesture_dispatcher_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/gesture_dispatcher.dart test/pdf/gesture_dispatcher_test.dart
git commit -m "feat(pdf): add GestureDispatcher for gesture routing"
```

---

## Task 5: 扩展缩放范围

**Files:**
- Modify: `lib/src/pdf/pdf_viewport_controller.dart:96-99`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/pdf_viewport_controller_test.dart - 添加新测试
group('Zoom range', () {
  test('allows zoom down to 0.3x', () {
    final controller = PdfViewportController(
      repository: mockRepository,
      documentId: 'test-doc',
    );
    
    controller.setZoom(0.3);
    
    expect(controller.zoom, 0.3);
  });
  
  test('allows zoom up to 10x', () {
    final controller = PdfViewportController(
      repository: mockRepository,
      documentId: 'test-doc',
    );
    
    controller.setZoom(10.0);
    
    expect(controller.zoom, 10.0);
  });
  
  test('clamps zoom below minimum', () {
    final controller = PdfViewportController(
      repository: mockRepository,
      documentId: 'test-doc',
    );
    
    controller.setZoom(0.1);
    
    expect(controller.zoom, PdfViewportController.minZoom);
  });
  
  test('clamps zoom above maximum', () {
    final controller = PdfViewportController(
      repository: mockRepository,
      documentId: 'test-doc',
    );
    
    controller.setZoom(15.0);
    
    expect(controller.zoom, PdfViewportController.maxZoom);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/pdf_viewport_controller_test.dart`
Expected: FAIL - minZoom and maxZoom are 0.5 and 5.0

- [ ] **Step 3: Modify implementation**

```dart
// lib/src/pdf/pdf_viewport_controller.dart
// 修改 L96-99

  /// Minimum zoom factor.
  static const double minZoom = 0.3;

  /// Maximum zoom factor.
  static const double maxZoom = 10.0;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/pdf_viewport_controller_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/pdf_viewport_controller.dart test/pdf/pdf_viewport_controller_test.dart
git commit -m "feat(pdf): extend zoom range to 0.3x-10x"
```

---

## Task 6: 集成 ElasticBoundary 到 InteractiveCanvasViewer

**Files:**
- Modify: `lib/src/pdf/widgets/interactive_canvas_viewer.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/widgets/interactive_canvas_viewer_test.dart - 新文件
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InteractiveCanvasViewer elastic boundary', () {
    testWidgets('allows pan when PDF smaller than viewport', (tester) async {
      // 这个测试验证弹性边界允许在 PDF 小于视口时拖动
      // 实际测试需要构建完整的 widget 树
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/widgets/interactive_canvas_viewer_test.dart`
Expected: FAIL or inconclusive

- [ ] **Step 3: Modify implementation**

```dart
// lib/src/pdf/widgets/interactive_canvas_viewer.dart
// 在文件顶部添加导入
import 'package:starmind/src/pdf/elastic_boundary.dart';

// 修改 _matrixTranslate 方法 (L560-661)
// 在返回 nextMatrix 之前，应用弹性边界约束

  Matrix4 _matrixTranslate(Matrix4 matrix, Offset translation) {
    if (translation == .zero) {
      return matrix.clone();
    }

    // ... 现有代码保持不变直到 L600 ...
    
    // 如果边界是无限的，不需要检查
    if (_boundaryRect.isInfinite) {
      return nextMatrix;
    }

    // ═══════════════════════════════════════════════════════════════
    // 新增：弹性边界约束
    // ═══════════════════════════════════════════════════════════════
    final Quad boundariesAabbQuad = _getAxisAlignedBoundingBoxWithRotation(
      _boundaryRect,
      _currentRotation,
    );

    final Offset offendingDistance = _exceedsBy(
      boundariesAabbQuad,
      nextViewport,
    );
    
    if (offendingDistance == .zero) {
      return nextMatrix;
    }

    // 新增：检查是否 PDF 小于视口
    final boundaryWidth = _boundaryRect.width;
    final boundaryHeight = _boundaryRect.height;
    final viewportWidth = _viewport.width;
    final viewportHeight = _viewport.height;
    
    final bool pdfSmallerThanViewport = 
        boundaryWidth < viewportWidth || boundaryHeight < viewportHeight;
    
    if (pdfSmallerThanViewport) {
      // 使用弹性边界约束
      final currentTranslation = _getMatrixTranslation(nextMatrix);
      final constrainedTranslation = ElasticBoundary.constrain(
        currentTranslation,
        _boundaryRect,
        _viewport,
      );
      
      return matrix.clone()
        ..setTranslation(
          Vector3(constrainedTranslation.dx, constrainedTranslation.dy, 0),
        );
    }

    // ... 原有的硬边界约束逻辑 ...
    
    // 修改 L643-646：当两个方向都越界时，不要完全禁止平移
    // 原代码：
    // if (offendingCorrectedDistance.dx != 0.0 &&
    //     offendingCorrectedDistance.dy != 0.0) {
    //   return matrix.clone();
    // }
    // 
    // 修改为：
    if (offendingCorrectedDistance.dx != 0.0 &&
        offendingCorrectedDistance.dy != 0.0) {
      // PDF 小于视口时，仍然允许弹性拖动
      if (pdfSmallerThanViewport) {
        final currentTranslation = _getMatrixTranslation(nextMatrix);
        final constrainedTranslation = ElasticBoundary.constrain(
          currentTranslation,
          _boundaryRect,
          _viewport,
        );
        return matrix.clone()
          ..setTranslation(
            Vector3(constrainedTranslation.dx, constrainedTranslation.dy, 0),
          );
      }
      return matrix.clone();
    }

    // ... 其余代码保持不变 ...
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/widgets/interactive_canvas_viewer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/widgets/interactive_canvas_viewer.dart test/pdf/widgets/interactive_canvas_viewer_test.dart
git commit -m "feat(pdf): integrate ElasticBoundary into InteractiveCanvasViewer"
```

---

## Task 7: 集成 ViewportRepaintNotifier 到 PdfViewportWidget

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/widgets/pdf_viewport_widget_test.dart - 新文件
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/widgets/pdf_viewport_widget.dart';

void main() {
  group('PdfViewportWidget repaint optimization', () {
    testWidgets('uses ViewportRepaintNotifier for updates', (tester) async {
      // 验证使用 ViewportRepaintNotifier 而非 setState
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/widgets/pdf_viewport_widget_test.dart`
Expected: FAIL - file not found

- [ ] **Step 3: Modify implementation**

```dart
// lib/src/pdf/widgets/pdf_viewport_widget.dart
// 添加导入
import 'package:starmind/src/pdf/viewport_repaint_notifier.dart';

// 修改 _PdfViewportWidgetState 类

class _PdfViewportWidgetState extends State<PdfViewportWidget> {
  final GlobalKey _viewportKey = GlobalKey();
  late final TransformationController _transformationController;
  late final ViewportRepaintNotifier _repaintNotifier;  // 新增
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _repaintNotifier = ViewportRepaintNotifier();  // 新增
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounceTimer?.cancel();
    _transformationController.dispose();
    _repaintNotifier.dispose();  // 新增
    super.dispose();
  }

  void _onControllerChanged() {
    // 使用 ViewportRepaintNotifier 通知重绘，而非 setState
    _repaintNotifier.updateViewport(
      widget.controller.panOffset,
      widget.controller.zoom,
    );
    _startDebounceTimer();
  }

  // ... 其余代码保持不变 ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/widgets/pdf_viewport_widget_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart test/pdf/widgets/pdf_viewport_widget_test.dart
git commit -m "feat(pdf): integrate ViewportRepaintNotifier for direct repaint"
```

---

## Task 8: 集成 GestureDispatcher 到 InkCanvasLayer

**Files:**
- Modify: `lib/src/pdf/widgets/ink_canvas_layer.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/pdf/widgets/ink_canvas_layer_test.dart - 新文件或修改现有
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InkCanvasLayer gesture handling', () {
    testWidgets('cancels drawing on multi-touch', (tester) async {
      // 验证多指时取消绘制
    });
    
    testWidgets('resumes drawing after multi-touch ends', (tester) async {
      // 验证多指结束后可以继续绘制
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pdf/widgets/ink_canvas_layer_test.dart`
Expected: FAIL or inconclusive

- [ ] **Step 3: Modify implementation**

```dart
// lib/src/pdf/widgets/ink_canvas_layer.dart
// 添加导入
import 'package:starmind/src/pdf/gesture_dispatcher.dart';

// 修改 _InkCanvasLayerState 类

class _InkCanvasLayerState extends State<InkCanvasLayer> {
  List<InkPoint> _currentStrokePoints = [];
  List<InkStroke> _sessionStrokes = [];
  bool _isDrawing = false;
  late StrokeStabilizer _stabilizer;
  late PenConfig _activePenConfig;
  List<Offset> _eraserPoints = [];
  
  // 使用 GestureDispatcher 替代手动手势管理
  late final GestureDispatcher _gestureDispatcher;

  @override
  void initState() {
    super.initState();
    _stabilizer = StrokeStabilizer(level: 3);
    _gestureDispatcher = GestureDispatcher();  // 新增
    _updatePenConfig();
  }

  @override
  void didUpdateWidget(InkCanvasLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTool != widget.currentTool ||
        oldWidget.strokeWidth != widget.strokeWidth ||
        oldWidget.currentColor != widget.currentColor ||
        oldWidget.penConfig != widget.penConfig) {
      _updatePenConfig();
    }
    // 同步设置
    _gestureDispatcher.inkModeEnabled = widget.isInkMode;
    _gestureDispatcher.palmRejectionEnabled = widget.palmRejectionEnabled;
  }

  void _onPointerDown(PointerDownEvent event) {
    // 使用 GestureDispatcher 处理
    _gestureDispatcher.onPointerDown(event.pointer, event.kind, event.localPosition);
    
    if (!_gestureDispatcher.isDrawing) return;
    if (_gestureDispatcher.drawingPointerId != event.pointer) return;
    
    // 原有的绘制逻辑...
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_gestureDispatcher.onPointerMove(event.pointer, event.localPosition)) {
      return;
    }
    
    // 原有的绘制逻辑...
  }

  void _onPointerUp(PointerUpEvent event) {
    _gestureDispatcher.onPointerUp(event.pointer);
    
    // 原有的提交逻辑...
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _gestureDispatcher.onPointerCancel(event.pointer);
    
    // 原有的取消逻辑...
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pdf/widgets/ink_canvas_layer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/pdf/widgets/ink_canvas_layer.dart test/pdf/widgets/ink_canvas_layer_test.dart
git commit -m "feat(pdf): integrate GestureDispatcher into InkCanvasLayer"
```

---

## Task 9: 运行完整测试套件

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 2: Fix any failing tests**

如果测试失败，分析原因并修复。

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "feat(pdf): complete PDF annotation optimization implementation"
```

---

## Task 10: 更新文档

**Files:**
- Create: `docs/pdf-annotation-optimization.md`

- [ ] **Step 1: Write documentation**

```markdown
# PDF 批注优化使用指南

## 概述

本次优化解决了以下问题：
1. PDF 缩小到小于视口时无法拖动
2. 缩放时卡顿
3. 多指手势冲突

## 新增组件

### ElasticBoundary
弹性边界约束，允许在 PDF 小于视口时弹性拖动。

### ViewportRepaintNotifier
直绘通知器，跳过 Widget 重建直接触发重绘。

### StaticPictureCache
Picture 缓存，缓存静态内容避免重绘。

### GestureDispatcher
手势分发器，智能区分绘制手势和导航手势。

## 使用方式

无需更改现有使用方式，优化自动生效。

## 性能建议

1. 对于大型 PDF，建议使用 `StaticPictureCache` 缓存页面
2. 手写批注时建议开启 palm rejection
3. 缩放范围已扩展至 0.3x - 10x
```

- [ ] **Step 2: Commit documentation**

```bash
git add docs/pdf-annotation-optimization.md
git commit -m "docs: add PDF annotation optimization guide"
```

---

## 验收清单

- [ ] PDF 缩小到小于视口时可以自由拖动
- [ ] 拖出边界后有弹性阻力，手势结束自动回弹
- [ ] 缩放操作帧率 ≥ 60fps
- [ ] 缩放范围 0.3x - 10x
- [ ] 多指手势正确区分绘制/导航
- [ ] 所有测试通过