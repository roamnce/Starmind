# PDF 批注优化使用指南

## 概述

本次优化解决了以下问题：
1. PDF 缩小到小于视口时无法拖动
2. 缩放时卡顿
3. 多指手势冲突

## 新增组件

### ElasticBoundary
弹性边界约束，允许在 PDF 小于视口时弹性拖动。

**位置**: `lib/src/pdf/elastic_boundary.dart`

**主要方法**:
- `constrain(Offset pan, Rect boundary, Rect viewport)` - 应用弹性约束
- `snapBack(Offset pan, Rect boundary, Rect viewport)` - 计算回弹目标位置
- `needsSnapBack(Offset pan, Rect boundary, Rect viewport)` - 判断是否需要回弹

**常量**:
- `elasticity = 0.3` - 弹性阻力系数
- `snapBackThreshold = 50.0` - 触发回弹的阈值

### ViewportRepaintNotifier
直绘通知器，跳过 Widget 重建直接触发重绘。

**位置**: `lib/src/pdf/viewport_repaint_notifier.dart`

**主要方法**:
- `updateViewport(Offset pan, double zoom)` - 更新视口状态
- `setZoom(double value)` - 设置缩放
- `setPanOffset(Offset value)` - 设置平移偏移
- `getTransform()` - 获取变换矩阵

### StaticPictureCache
Picture 缓存，缓存静态内容避免重绘。

**位置**: `lib/src/pdf/static_picture_cache.dart`

**主要方法**:
- `lookup(String pageId, double zoom)` - 查找缓存
- `store(String pageId, double zoom, ui.Picture picture)` - 存储缓存
- `clear()` - 清除缓存
- `dispose()` - 释放资源

**常量**:
- `maxEntries = 6` - LRU 最大条目数
- `zoomQuantum = 0.5` - 缩放分桶量子

### GestureDispatcher
手势分发器，智能区分绘制手势和导航手势。

**位置**: `lib/src/pdf/gesture_dispatcher.dart`

**主要属性**:
- `inkModeEnabled` - 是否启用批注模式
- `palmRejectionEnabled` - 是否启用手掌拒绝
- `isDrawing` - 是否正在绘制
- `drawingPointerId` - 当前绘制指针ID

**主要方法**:
- `isDrawGesture(ScaleStartDetails, PointerDeviceKind)` - 判断是否为绘制手势
- `onPointerDown(int pointerId, PointerDeviceKind kind, Offset position)` - 指针按下
- `onPointerMove(int pointerId, Offset position)` - 指针移动
- `onPointerUp(int pointerId)` - 指针抬起
- `onPointerCancel(int pointerId)` - 指针取消

## 使用方式

无需更改现有使用方式，优化自动生效。

## 性能建议

1. 对于大型 PDF，建议使用 `StaticPictureCache` 缓存页面
2. 手写批注时建议开启 palm rejection
3. 缩放范围已扩展至 0.3x - 10x

## 缩放范围

| 版本 | 最小缩放 | 最大缩放 |
|------|----------|----------|
| 优化前 | 0.5x | 5.0x |
| 优化后 | 0.3x | 10.0x |

## 测试覆盖

所有新增组件都有完整的单元测试：
- `test/pdf/elastic_boundary_test.dart`
- `test/pdf/viewport_repaint_notifier_test.dart`
- `test/pdf/static_picture_cache_test.dart`
- `test/pdf/gesture_dispatcher_test.dart`
- `test/pdf/widgets/interactive_canvas_viewer_test.dart`
- `test/pdf/widgets/pdf_viewport_widget_test.dart`
- `test/pdf/widgets/ink_canvas_layer_test.dart`
