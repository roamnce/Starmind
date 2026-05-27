# PDF 渲染与缩放手势体验优化设计方案

本方案旨在解决 Starmind 现有的 PDF 渲染与缩放功能卡顿、手势冲突和操作不连贯等问题。通过将页面布局静态化、引入自定义手势路由的 `InteractiveCanvasViewer`，并统一滚动与缩放逻辑，全面对齐 Goodnotes 等成熟商业软件的手写和阅读体验。

## User Review Required

> [!IMPORTANT]
> **1. 移除了嵌套的 `SingleChildScrollView`：**
> 整个 PDF 视口的上下滚动和缩放平移现在将完全由自定义的 `InteractiveCanvasViewer` 的 `Matrix4` 矩阵变换接管。这彻底消除了此前“滚动条滚动”与“视口平移”的手势竞争。
> 
> **2. 静态页面布局尺寸（性能提升核心）：**
> 所有 `PdfPageWidget` 及其叠加图层在 Flutter 布局树中的高度和宽度将被固定（在 `baseScale`，即自适应宽度的尺寸），捏合缩放不再触发重新布局（layout pass），保证了 60fps/120fps 的缩放流畅度。

> [!TIP]
> **3. 智能防误触手势路由（Palm Rejection）：**
> 双指操作和开启防误触时的手指触摸将被自动路由给平移/缩放组件；手写笔和关闭防误触时的单指操作将被路由给墨迹绘制，实现了写字与缩放的无缝切换。

## Open Questions

目前已完成所有的关键架构决策对齐，没有遗留的开放问题。

---

## Proposed Changes

### PDF Viewport & Gestures (PDF 视口与手势组件)

#### [NEW] [interactive_canvas_viewer.dart](file:///E:/app/saber/starmind/lib/src/pdf/widgets/interactive_canvas_viewer.dart)
创建自定义的 `InteractiveCanvasViewer`，它是一个深度定制的视口变换组件（改编自 Saber 的 `InteractiveCanvasViewer` 和 Flutter 官方 `InteractiveViewer`），主要实现：
- 使用统一 of Scale 手势识别器，当 `isDrawGesture` predicate 返回 `true` 时，不修改变换矩阵，而是调用手绘绘制的回调；
- 整合防误触（Palm Rejection），在开启防误触时，将手指触控判定为非绘图手势，从而可以使用手指进行滑屏和平移；
- 支持边界回弹和惯性平移。

#### [MODIFY] [pdf_viewport_controller.dart](file:///E:/app/saber/starmind/lib/src/pdf/pdf_viewport_controller.dart)
- 更新视口控制器中的 `zoom` 和 `panOffset` 定义，使 `panOffset` 表示在 `baseScale` (zoom=1.0) 时的局部平移偏移，使逻辑更加清晰。

---

### UI & Page Components (界面与页面渲染组件)

#### [MODIFY] [pdf_viewport_widget.dart](file:///E:/app/saber/starmind/lib/src/pdf/widgets/pdf_viewport_widget.dart)
- 修改 `PdfPageWidget` 的布局尺寸，使其宽度和高度固定在 `baseScale` 对应的静态尺寸上，在 `build` 方法中不再包含 `zoom` 参数；
- 重新实现高精切片渲染逻辑 `_loadHighResTile`：
  - 获取当前在 `baseScale` 静态尺寸下的局部可见区域 `visibleRect`；
  - 乘以当前缩放比例 `zoom` 和 `devicePixelRatio`，再加上 1.3 倍 of 超分系数，计算出最优的目标分辨率 `targetWidth`/`targetHeight`；
  - 异步请求 PDFium 渲染切片，并在 `PdfPagePainter` 中以静态局部坐标系将切片完美贴合绘制。

#### [MODIFY] [ink_canvas_layer.dart](file:///E:/app/saber/starmind/lib/src/pdf/widgets/ink_canvas_layer.dart)
- 简化 `_screenToPdf` 和 `_pdfToScreen` 的坐标变换逻辑，因为页面布局固定在 `baseScale` 且变换由外层 IV 矩阵自动缩放，我们只需要在 `baseScale` 的基础上进行 `Y-flip` 翻转和比例换算，从而去除多余的 `zoom` 和 `panOffset` 运算。
- 更新 `InkCanvasLayer` 使其只接收静态 `baseScale` 或 `viewportWidth`。

#### [MODIFY] [annotation_renderer.dart](file:///E:/app/saber/starmind/lib/src/pdf/widgets/annotation_renderer.dart)
- 同步简化批注绘制层，去掉手动叠加 `zoom` 和 `panOffset` 的逻辑，由底层的 Flutter Canvas 变换天然承载。

#### [MODIFY] [pdf_annotation_integration.dart](file:///E:/app/saber/starmind/lib/src/pdf/widgets/pdf_annotation_integration.dart)
- 调整辅助构造方法的参数签名，移除多余的 `zoom` 和 `panOffset` 参数。

---

### Main Viewport Integration (主视口集成)

#### [MODIFY] [main.dart](file:///E:/app/saber/starmind/lib/main.dart)
- 在 `PdfTabViewport` 中引入 `InteractiveCanvasViewer` 替代原有的 `InteractiveViewer`；
- 移除嵌套的 `SingleChildScrollView`，让 `InteractiveCanvasViewer` 成为页面列表唯一的滚动与平移宿主；
- 在 `isDrawGesture` 中实现手绘拦截判定：
  - 若为笔工具且单点触摸，并且在防误触未开启或使用了触控笔时，返回 `true` 并重定向手势给手写层；
- 基于当前的矩阵偏移计算当前处于第几页，保证缩放后的页码指示器准确无误。

---

## Verification Plan

### Automated Tests
验证代码正常构建及无类型冲突：
```powershell
flutter analyze
```

### Manual Verification
1. **缩放流畅度验证**：双指快速缩放 PDF，确认文字缩放无肉眼可见的卡顿和重排延迟，维持在高帧率。
2. **手势融合验证**：
   - 处于画笔模式时，单指在屏幕上写字，正常生成线条且视口保持不动。
   - 双指在屏幕上滑动或捏合，视口平稳平移和缩放，且不会生成意外的画笔线条。
3. **防误触验证**：
   - 开启防误触，使用手写笔可以写字；此时用单个手指滑动屏幕，视口应该平滑移动而不会画出墨迹。
4. **切片清晰度验证**：放大到 3x 或 5x，短暂等待防抖结束（80ms），确认渲染出的文字极其锐利。
5. **滚动与翻页页码验证**：上下滚动 PDF，确认右下角的状态栏页码能根据当前滚动的偏移量准时切换。
