# PDF 缩放范围扩展与缩小回弹 Bug 修复方案 (v2 - 2D Scale Clamp Fix)

本方案旨在解决当用户捏合缩小 PDF 至 100% (1.0) 以下时，松开双指 PDF 会强制弹回 100% 的底层 Bug，并在自由平移和居中模式下均支持 10% - 1600% 的缩放范围。

## 核心问题分析

1. **`getMaxScaleOnAxis()` 的 2D 缩放局限性（回弹 Bug 的根本原因）**：
   - 之前代码中，我们通过 `matrix.getMaxScaleOnAxis()` 来获取当前缩放比例。
   - 在 Flutter/vector_math 中，`getMaxScaleOnAxis()` 的实现是计算矩阵沿 X、Y、Z 轴的缩放比例平方和的平方根，并返回最大值。
   - 在 2D Viewport 的矩阵变换中，X 和 Y 轴根据缩放系数 `s` 缩放，而 Z 轴的缩放系数默认为 `1.0`。
   - 因此，当缩小比例 `s < 1.0` 时，X 轴和 Y 轴的缩放比例均小于 1.0，但 Z 轴的缩放比例为 1.0。`getMaxScaleOnAxis()` 将返回 `1.0`（因为 `max(s, 1.0) = 1.0`）。
   - 这导致只要缩放比例小于 100%（例如 0.5），任何读取 `getMaxScaleOnAxis()` 的底层逻辑（包括 `main.dart` 监听器和 `InteractiveCanvasViewer` 内部手势）都会错误地读到 `1.0`，从而直接将 Viewport 的状态重写为 `1.0`，造成强制回弹。
   - **修复策略**：在所有相关组件中实现自定义 2D 缩放比例提取函数 `_getMatrixScale2D(matrix)`，通过提取 X 轴分量的模长（不包含 Z 轴）来正确获取 2D 实测缩放系数。

2. **多组件统一修复**：
   - 该 Bug 存在于 `InteractiveCanvasViewer`（手势计算）、`main.dart`（视口变换监听器）以及 `pdf_viewport_widget.dart` 中，需统一将 `getMaxScaleOnAxis()` 替换为 2D 缩放提取算法。

---

## User Review Required

> [!IMPORTANT]
> 此修改使用 X 轴变换向量的长度来解析缩放比例，完全避开了 Z 轴对 2D 缩放比率的干扰，可以完美解决 100% 以下缩放回弹的问题，不影响任何其他手势功能。

---

## Proposed Changes

### 1. Viewport Base Class & Gesture Viewer

#### [MODIFY] [interactive_canvas_viewer.dart](file:///d:/starmind/lib/src/pdf/widgets/interactive_canvas_viewer.dart)
- 添加 `_getMatrixScale2D(Matrix4 matrix)` 辅助方法。
- 将所有 `_transformer.value.getMaxScaleOnAxis()` 和 `matrix.getMaxScaleOnAxis()` 替换为 `_getMatrixScale2D(...)`。

### 2. Main Page

#### [MODIFY] [main.dart](file:///d:/starmind/lib/main.dart)
- 添加 `_getMatrixScale2D(Matrix4 matrix)` 辅助方法。
- 将 `_onTransformChanged` 中的 `matrix.getMaxScaleOnAxis()` 替换为 `_getMatrixScale2D(matrix)`。

### 3. PDF Widget (Backup Widget)

#### [MODIFY] [pdf_viewport_widget.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_viewport_widget.dart)
- 添加 `_getMatrixScale2D(Matrix4 matrix)` 辅助方法。
- 将所有的 `getMaxScaleOnAxis()` 替换为 `_getMatrixScale2D(...)`。

---

## Verification Plan

### Automated Tests
- 运行 `flutter analyze` 确保无语法和类型错误。

### Manual Verification
- 打开 PDF 视图，双指捏合缩小至 100% 以下（如 50%、20%），松开双指，确认 PDF 不会弹回 100%，而是能稳定停留在小于 100% 的倍率并自动水平/垂直居中。
- 测试自由平移模式开启和关闭状态下的捏合缩小，确保均表现正确。
- 确认放大至 1600% 时渲染依然清晰且流畅。
