# Task Checklist (v2 - 2D Scale Clamp Fix)

- [x] **提取 2D Scale 提取器并集成**
  - [x] 在 `lib/src/pdf/widgets/interactive_canvas_viewer.dart` 中添加 `_getMatrixScale2D` 辅助方法，并将所有 `getMaxScaleOnAxis` 替换为该辅助方法
  - [x] 在 `lib/main.dart` 中添加 `_getMatrixScale2D` 辅助方法，并将 `_onTransformChanged` 中的 `getMaxScaleOnAxis` 替换为该辅助方法
  - [x] 在 `lib/src/pdf/widgets/pdf_viewport_widget.dart` 中添加 `_getMatrixScale2D` 辅助方法，并将所有 `getMaxScaleOnAxis` 替换为该辅助方法

- [x] **验证测试**
  - [x] 运行 `flutter analyze` 验证代码无语法和静态分析错误
  - [x] 手动验证双指捏合缩小至 100% 以下（如 50% 或 30%）时，松手后是否完美居中且不弹回 100%
  - [x] 手动验证快速放大至 1600% 并拖动，观察切片生成是否流畅无卡顿
