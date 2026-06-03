# Walkthrough (v7.0) - 思维导图模块自由画布与自适应布局

## Changes Made

### 1. 树形自适应布局算法扩展
- **文件:** [tree_layout.dart](file:///d:/starmind/lib/src/mindmap/ui/tree_layout.dart)
- **更新:**
  - 扩展 `LayoutDirection` 枚举，支持 `horizontal` (全右), `left` (全左), 和 `bothSides` (对称两侧) 三种新布局方向。
  - 重写了 `calculate` 坐标定位核心逻辑，在 `bothSides` 时，将一级子节点均匀平分到左右侧，使用对称子树排序计算。
  - 重构了 `_collectConnections`，使其能基于子节点与父节点的相对 `dx` 大小，自动检测并动态重定向锚点（右侧/左侧边缘）。
  - 更新了 `test/mindmap/ui/tree_layout_test.dart` 确保所有布局坐标逻辑测试通过。

### 2. 连线引擎 CustomPaint 水平重排
- **文件:** [canvas_painter.dart](file:///d:/starmind/lib/src/mindmap/ui/canvas_painter.dart)
- **更新:**
  - 将 `_createBezierPath` 改为水平贝塞尔控制点偏折，使曲线顺畅向两侧弯曲。
  - 将 `_createSteppedPath` 改为水平正交直角折线（先沿 X 轴到中点，再沿 Y 轴到目标，最后沿 X 轴到目标）。

### 3. Controller CRUD 节点处理
- **文件:** [mindmap_controller.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_controller.dart)
- **更新:**
  - 引入 `LayoutDirection` 状态及其 Getter/Setter，支持动态切换布局样式。
  - 添加了 `createChildNode` (针对 Tab 按键交互设计) 和 `createSiblingNode` (针对 Enter 按键交互设计) 接口，直接与 `MindMapService` 和本地 SQLite 同步，自动刷新节点树并保持选中高亮。
  - 更新 `test/mindmap/ui/mindmap_controller_test.dart` 添加对应测试用例。

### 4. 视口重构与 Culling 优化
- **文件:** [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart)
- **更新:**
  - 重构为 `StatefulWidget`，引入 `TransformationController` 绑定 `InteractiveViewer` 的变换状态。
  - 实现了 **Viewport Culling (视口裁剪)**：在 `LayoutBuilder` 中同步根据矩阵的平移缩放值计算可见视口范围 (`visibleRect`)，仅渲染屏幕内及缓冲区内的 `NodeWidget`，过滤超出屏幕外的其他 Widget，显著减少节点数量多时的渲染卡顿。
  - 增加了 **键盘快捷键** (`Focus` 包装类)：监听 Tab 键创建子节点，Enter 键创建同级节点，Delete/Backspace 键删除选中节点。
  - 支持 AppBar 缩放按钮及自适应缩放（Fit to Screen）与画布的无冲突双向同步。

### 5. 节点卡片高保真暗色高亮微发光样式
- **文件:** [node_widget.dart](file:///d:/starmind/lib/src/mindmap/ui/node_widget.dart)
- **更新:**
  - 将背景配色更新为高保真 HTML 原型的经典深灰暗色 (`#242930`)。
  - 调整卡片边角与金黄色发光边框 (`#C8841A`)，选中时带有柔和的流光金色阴影。
  - 保留了原有的折叠与展开状态的子节点数量标记，并使用更加圆润的布局。
  - 更新 `test/mindmap/ui/node_widget_test.dart` 校验新的 `Icons.picture_as_pdf_outlined` 图标。

---

## Verification Results

We verified the layout calculations, painter rendering, controllers, culling, and widget state using our unit and widget test suites. All UI/UX logic tests compiled and passed:

1. **Tree Layout Algorithm Coordinates Tests:**
   - `TreeLayout calculates single root position` - **Passed**
   - `TreeLayout calculates positions for LayoutDirection.bothSides` - **Passed**
   - `TreeLayout calculates positions for LayoutDirection.left` - **Passed**
   - `TreeLayout calculates positions for LayoutDirection.horizontal` - **Passed**
   - `TreeLayout calculates bounding box for bothSides` - **Passed**

2. **MindMap Controller Actions Tests:**
   - `MindMapController Note CRUD createChildNode adds child node to selected parent and selects it` - **Passed**
   - `MindMapController Note CRUD createSiblingNode adds sibling node and selects it` - **Passed**

3. **MindMap Canvas Painter Tests:**
   - `MindMapCanvasPainter shouldRepaint returns true when connections change` - **Passed**
   - `MindMapCanvasPainter paints bezier curves` - **Passed**

4. **MindMap Page Layout and Zoom Sync Tests:**
   - `MindMapPage shows empty state when no nodes` - **Passed**
   - `MindMapPage shows zoom controls` - **Passed**
   - `MindMapPage shows nodes after creation` - **Passed**
   - `MindMapPage zoom in button increases scale` - **Passed**

5. **Node Card Widget Render and State Tests:**
   - `NodeWidget displays note title` - **Passed**
   - `NodeWidget shows PDF icon when note has pdfId` - **Passed**
   - `NodeWidget shows selection highlight when isSelected` - **Passed**
   - `NodeWidget calls onTap when tapped` - **Passed**
