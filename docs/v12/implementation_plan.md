# 思维导图高保真布局、ForUI 完全适配与双视口分屏实现计划 (v12.0)

本计划旨在将 StarMind 思维导图页面重构为与高保真原型图 `index.html` 完美对齐的布局结构，集成 `forui` 组件库进行控件美化，支持右上角分屏按钮弹出磨砂弹窗并能动态加载已有 PDF/思维导图，同时修复脑图曲线连线的坐标偏移缺陷。

## 核心设计决策

> [!NOTE]
> 我们将在 `MindMapController` 中新增四个分屏相关状态，并在 `lib/main.dart` 里的 `MindMapTabViewport` 中监听这些状态，在单屏与横向分屏 `Row` 视图之间动态切流。此方案不会引入任何多线程或额外的多端口渲染冲突，且对现有的 PDF 和脑图组件无破坏性侵入。

> [!WARNING]
> 修改 `TreeLayout` 坐标加偏置 `+ 500` 时，为了不影响旧的单测，我们将同步重构 `test/mindmap/ui/` 下的连线测试，确保 100% 通过。

## 待变动文件及逻辑

---

### MindMap 状态扩充与同级导航

#### [MODIFY] [mindmap_controller.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_controller.dart)
- 新增分屏信息状态字：
  - `String? _splitType;`
  - `String? _splitId;`
  - `String? _splitTitle;`
  - `String? _splitFilePath;`
  - 对应的 getters 及其控制方法：`openSplitScreen(type, id, title, [filePath])` 和 `closeSplitScreen()`。

---

### BreadcrumbBar 面包屑栏与主页面重构

#### [MODIFY] [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart)
- 移除 Scaffold 默认的 Material `AppBar`，代以自定义的顶部 `BreadcrumbBar` 组件（高度 44px，磨砂黑背景，左侧带 Home 房子图标与路径，右侧带收藏、撤销、重做、分屏、更多、侧边栏开关等）。
- 修改 Scaffold `body` 布局：支持在左侧渲染脑图画布，右侧渲染展开的 `MindMapSidebar` 内容面板，以及最右侧宽度为 `52px` 的深色纵向 Tab 卡片栏。
- 将 Canvas 的背景、网格属性和 InteractiveViewer 操作全面绑定到 `controller` 状态。
- 为分屏按钮增加磨砂选项弹窗：
  - 加载 `context.workspaceController.documents` 生成 PDF 选择列表。
  - 异步加载 `MindMapService(FfiMindMapRepository()).getAllTopics()` 生成思维导图选择列表。
  - 选择后调用 `controller.openSplitScreen`。

---

### MindMapSidebar 与 Markdown 工具栏 ForUI 深度集成

#### [MODIFY] [mindmap_sidebar.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_sidebar.dart)
- 顶部栏右侧集成同级节点切换 `<` / `>` 按钮，点击触发同级导航。
- 主题配置面板中，“网格显示”开关替换为 ForUI `FSwitch`，“网格大小”滑块替换为 ForUI `FSlider`。
- 面板内的操作按钮迁移为 ForUI `FButton`，笔记输入框采用 ForUI `FTextField` 的透明极简样式。

#### [MODIFY] [markdown_editor_toolbar.dart](file:///d:/starmind/lib/src/mindmap/ui/markdown_editor_toolbar.dart)
- 完全按照原型图的高保真 2 行排列重构：
  - 第一行：`H`、`B`、`I`、`S`（删除线）、`Link`、`Separator`、`Unordered List`、`Ordered List`、`Task List`、`Separator`、`Quote`、`Divide Line`。
  - 第二行：`Codeblock`、`Inline Code`、`Separator`、`Upload Attachment`、`Table`、`Separator`、`Undo`、`Redo`。
  - 每一个按钮都使用 ForUI 风格的 `FButton` 精简版，外加高保真 SVG 图标。

---

### 双视口分屏自适应切流实现

#### [MODIFY] [main.dart](file:///d:/starmind/lib/main.dart)
- 重构 `MindMapTabViewport` 组件。
- 监听 `widget.controller`：
  - 若 `splitType == null`：返回单一的 `MindMapPage`。
  - 若 `splitType == 'pdf'`：返回横向分屏 `Row(children: [ Expanded(child: MindMapPage), VerticalDivider, Expanded(child: PdfTabViewport) ])`。其中，为 PDF 视口独立缓存或实例化 `PdfViewportController`，加载物理沙盒文件，支持脑图与右侧分屏的 PDF 独立或联动交互。
  - 若 `splitType == 'mindmap'`：返回横向分屏 `Row(children: [ Expanded(child: MindMapPage), VerticalDivider, Expanded(child: MindMapPage) ])`。右侧的 `MindMapPage` 加载选中的脑图数据，形成脑图双开视角。
- 处理分屏下 `PdfViewportController` 等控制器的自动释放逻辑，防止内存泄漏。

---

### 连线锚点与偏置定位算法修复

#### [MODIFY] [tree_layout.dart](file:///d:/starmind/lib/src/mindmap/ui/tree_layout.dart)
- 修改 `calculateConnections` 方法，重构连线锚点偏置：
  - 针对每一个子节点，在其生成连线数据 `Connection` 时，在 X 和 Y 坐标上增加 `+ 500.0` InteractiveViewer 平移偏置。
  - 连线在 Y 轴上对齐到节点的实际高度中点，即 `parentPos.dy + parentSize.height / 2 + 500` 和 `childPos.dy + childSize.height / 2 + 500`。
- 修改 `tree_layout_test.dart` 或相关单测，确保断言适应 `+ 500` 偏置的连线坐标。

---

## 验证与测试计划

### 自动化单元测试
- 运行脑图 UI 下的所有单元测试，验证所有组件交互依然正常：
  ```powershell
  $env:TEMP='D:\temp'; $env:TMP='D:\temp'; flutter test test/mindmap/ui/
  ```

### 手动部署与功能校验
1. 验证顶部 BreadcrumbBar 的颜值与按键联动（包括收藏、撤销、重做）。
2. 验证右侧纵向 Tab 发光激活投影与 3 个侧栏面板的完美适配。
3. 验证 Markdown 紧凑双行工具栏与笔记文本框的输入体验。
4. 验证画布上的脑图曲线，从各层级子节点以及 nestedCard 容器卡片平滑发出并无偏差对齐。
5. 点击右上角分屏，挑选已有 PDF 并验证分屏多视口；挑选另一脑图验证脑图双开；验证关闭分屏无资源泄漏。
