# 嵌套卡片布局 (v8.0) - Phase 2 交付文档与 Walkthrough

本期完成了思维导图模块 **Phase 2: 嵌套卡片布局 (Nested Card Layout and Grouping)** 的核心逻辑与渲染，支持 MarginNote 风格的嵌套卡片组。

## 1. 修改内容与架构总结

本阶段通过以下几部分的配合，实现了完全自适应的卡片嵌套布局：

1.  **节点数据模型扩展 (`Note`)**:
    *   在 [note.dart](file:///d:/starmind/lib/src/mindmap/domain/note.dart) 的 `Note.copyWith` 中增加了对 `isCollapsed` (折叠) 以及 `highlightStyle` (高亮样式) 的更新支持，便于在不修改 SQLite Schema 的情况下标记嵌套卡片节点（`highlightStyle == 'nestedCard'`).
2.  **布局引擎重构 (`TreeLayout`)**:
    *   **后序尺寸计算**: 自底向上递归计算各子树节点和容器的大小。如果节点是 `nestedCard` 容器且处于展开状态，则根据子节点所占边界框（紧凑垂直排列，间距 12px），加上上下左右各 16px 的 Padding 自动推导出容器的有效大小，并进行空间预留。
    *   **先序绝对偏移投影**: 自顶向下将容器在画布上的绝对坐标加上其内部局部坐标，转换为子节点的绝对坐标，直接投影并保存。
    *   **对称布局修复**: 修复了 `bothSides` 双向排列时子树与根节点垂直中心对齐的偏移计算，确保在包含不同大小节点时依然完美对齐。
    *   **连线剪枝优化**: 嵌套容器卡片内部的子节点之间跳过标准的贝塞尔连线绘制，仅在容器节点与其他普通分支节点之间绘制连线。
3.  **UI 层重构 (`NodeWidget` & `MindMapPage`)**:
    *   **NodeWidget**: 扩展了对 `nestedCard` 容器的专门渲染。展开时，在 [node_widget.dart](file:///d:/starmind/lib/src/mindmap/ui/node_widget.dart) 中渲染为高质感的半透明卡片面板，并带有暗金色的微光边框（`#C8841A`），预留空间供子节点在上面定位。支持在头部显示组名，并提供了向上的折叠按钮。折叠时自动收缩为 120x40 的标准大小，带有卡片组专属图标，双击或点击折叠按钮即可在折叠/展开状态之间平滑切换。
    *   **MindMapPage**: 适配了动态尺寸，在 [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart) 中的 `_isNodeVisible` 视口裁剪和 `_calculateBounds` 边界框计算时，使用 `TreeLayout.nodeSizes` 获取各节点的实际动态尺寸，避免了裁剪偏差与边界重叠。
    *   **交互支持**: 增加了长按（Long Press）呼出上下文菜单的功能，支持对节点进行“重命名”、“新建子节点”、“切换为/取消嵌套卡片容器”以及“删除”等交互操作。

## 2. 验证结果与单元测试

1.  **单元测试**:
    *   在 [tree_layout_test.dart](file:///d:/starmind/test/mindmap/ui/tree_layout_test.dart) 中新增了 `Nested Card Layout` 测试组：
        *   `calculates size for empty nestedCard container` (验证空容器默认大小 152x72)
        *   `calculates size and positions for nestedCard with children` (验证带子节点的容器尺寸自适应计算 152x164，以及子节点 Y 轴坐标在容器内部的紧凑绝对投影 56px, 108px)
        *   `does not draw connections inside nestedCard container` (验证容器内部子节点不绘制连线)
    *   测试命令：`flutter test test/mindmap/ui/tree_layout_test.dart`
    *   **测试结果：全部通过 (All tests passed!)**
2.  **单元测试覆盖与集成**:
    *   运行 `flutter test test/mindmap/ui/` 对整个思维导图 UI 模块的全部 7 个测试文件进行回归测试，确保未对已有逻辑造成任何负面影响。
