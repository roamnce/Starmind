# 思维导图模块设计规格文档 (v7.0) - Phase 1：画布视口与脑图结构基本布局

本设计文档详述了在 `v7.0` 迭代中，启动 Starmind 移动/桌面客户端中思维导图模块 Phase 1 的设计规划。本阶段的核心目标是基于现有 Dart/Flutter 的模型与业务服务，实现高性能的自由画布布局、多方向自适应连线、节点增删互动，并为 Phase 1.5 的 MarginNote 嵌套卡片组打下坚实的基础。

---

## 1. 画布架构与手势缩放 (Viewport & Canvas)

### 1.1 自由画布层级设计 (Layout Hierarchy)
画布采用三层结构，使用 `InteractiveViewer` 实现无界平移与缩放，通过绝对定位放置节点：
1. **Viewport 容器层 (`InteractiveViewer`)**：
   *   `constrained: false`：允许子画布大小超出屏幕边界，实现无限画布。
   *   `minScale: 0.1`, `maxScale: 4.0`。
   *   `boundaryMargin: EdgeInsets.all(100)`：边缘外边距。
2. **画布渲染层 (`Stack`)**：
   *   **底层连线层 (`CustomPaint` + `MindMapCanvasPainter`)**：绘制节点间的贝塞尔曲线连接线，保证连线不会遮挡卡片。
   *   **顶层节点层 (`Positioned` widgets)**：将每一个 `NodeWidget` 绝对定位到 `TreeLayout` 计算得出的 `Offset` 坐标上。

### 1.2 高性能视口虚拟化裁剪 (Viewport Culling)
针对 MarginNote 级别的海量卡片排布，通过视口范围计算避免屏幕外多余渲染：
1. 在 `InteractiveViewer` 的 `onInteractionUpdate` 或变换矩阵监听器中，获取当前视口的 `Matrix4` 矩阵。
2. 结合屏幕尺寸计算出当前可见的画布区域 `VisibleRect`。
3. 节点定位渲染时：
   ```dart
   final nodeRect = Rect.fromLTWH(pos.dx, pos.dy, nodeWidth, nodeHeight);
   if (!visibleRect.overlaps(nodeRect)) {
     return const SizedBox.shrink(); // 屏幕外节点不渲染，降低 Widget 重建开销
   }
   ```
4. 为每一个 `NodeWidget` 包裹 `RepaintBoundary`，限制其状态更新（如选中、字数变化）的重绘范围，防止全局重绘。

---

## 2. 脑图布局算法与连线引擎 (TreeLayout & Connections)

### 2.1 多方向树形布局计算
现有的 `TreeLayout` 将支持以下三种布局方向：
1. **左侧布局 (Left Layout)**：子节点递归向父节点左侧伸展。
   *   子节点 X 坐标：`parentX - horizontalSpacing - nodeWidth`。
2. **右侧布局 (Right Layout)**：子节点递归向父节点右侧伸展。
   *   子节点 X 坐标：`parentX + horizontalSpacing + nodeWidth`。
3. **两侧布局 (Both-Sides Layout - Symmetrical)**：
   *   将根节点的第一级子节点依序或属性划分为左右两组。
   *   左侧子树按 Left Layout 排布，右侧子树按 Right Layout 排布。
   *   根节点居中，两边对称展开。

### 2.2 相对端点判别与贝塞尔曲线绘制
`CustomPaint` 中的 `MindMapCanvasPainter` 根据节点相对位置进行绘制：
1. **端点相对位置检测**：
   *   如果 `child.x > parent.x`（子在右）：
       *   起点（Start）：`(parent.right, parent.centerY)`
       *   终点（End）：`(child.left, child.centerY)`
   *   如果 `child.x < parent.x`（子在左）：
       *   起点（Start）：`(parent.left, parent.centerY)`
       *   终点（End）：`(child.right, child.centerY)`
2. **贝塞尔路径计算**：
   *   `controlPoint1 = Start.x + (End.x - Start.x) * 0.45`
   *   `controlPoint2 = End.x - (End.x - Start.x) * 0.45`
   *   `path.cubicTo(controlPoint1, Start.y, controlPoint2, End.y, End.x, End.y)`
3. 支持切换为**直线连线**与**直角折线**。为了避免平移缩放时的计算开销，`Path` 结果将缓存，并在脑图树物理结构变更时才重算。

---

## 3. 节点交互动作与数据同步 (Interactions & Sync)

### 3.1 增加子节点 (Tab)
*   **触发**：在节点选中态下点按快捷键 `Tab` 或点击底部工具栏的添加子节点按钮。
*   **逻辑**：
    1. 在数据库中新建子节点记录（调用 `MindMapService.createNote`，传入当前节点作为 `parentId`）。
    2. 将新节点的 ID 添加至当前节点的 `childIds` 列表，并更新父节点。
    3. 当前节点如果包含折叠状态，设置为展开。
    4. 将全局选中项更改为新创建的子节点，触发表格重新排布和贝塞尔重绘。

### 3.2 增加同级节点 (Enter)
*   **触发**：非根节点选中态下点按 `Enter` 键或点击工具栏添加同级节点按钮。
*   **逻辑**：
    1. 查找当前选中节点的 `parentId`。
    2. 新建节点记录，传入相同的 `parentId`。
    3. 将新节点 ID 追加至父节点的 `childIds` 中，并保存。
    4. 全局选中项切换为该新节点，触发表格重新布局。

### 3.3 删除选中节点 (Delete)
*   **逻辑**：
    1. 递归获取选中节点的所有后代节点 ID。
    2. 调用 `MindMapService.deleteNote` 将它们从库中彻底删除。
    3. 找到当前选中节点的父节点，从其 `childIds` 中删除该节点的 ID。
    4. 将选中项转移到其父节点。
