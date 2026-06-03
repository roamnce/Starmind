# StarMind 导图高保真布局与 ForUI 完全集成设计规范

本文档为 StarMind 思维导图页面高保真重构与 ForUI 深度集成的技术设计规范（v12.0），包含整体布局、ForUI 控件替换细节、分屏机制设计以及贝塞尔连线算法修复方案。

---

## 1. 整体布局重构

根据原型图 `D:\starmind\prototype\思维导图页面\index.html` 的结构，将 `MindMapPage` 与 `MindMapTabViewport` 重构为高保真响应式布局。

### 1.1 顶部面包屑栏 (Breadcrumb Bar)
- **位置**：取代原有的 Material `AppBar`，作为画布上方的固定横栏，高度为 `44px`。
- **背景**：毛玻璃深色磨砂（`Color(0xEB100D08)`），下边框 `Color(0x1AFFDC8C)`。
- **左侧部分**：
  - 首部新增 Home 房子图标（小 SVG 图标，与原型一致）。
  - 路径文本“AI配音”（以 `AtkinsonHyperlegibleNext` 字体加粗渲染，字号 `12.5`）。
- **右侧部分**：
  - 收藏（Star）图标按钮：默认为高亮黄色填充填充，代表已收藏状态，与原型一致。
  - 分离的“撤销”、“重做”图标按钮。
  - “分屏”切换图标按钮：点击触发分屏选项选择弹窗。
  - “更多操作”图标按钮。
  - “侧边栏收起/展开”图标按钮。

### 1.2 右侧高保真侧边栏与纵向 Tab 固定栏
- 侧边栏整体在右侧以 `Row` 形式排列。
- **纵向固定 Tab 栏**：
  - 宽度为 `52px`，背景为 `Color(0xFF141921)`，左边框为 `Color(0x1F2A3547)`。
  - 包含三个纵向 Tab 按钮：`节点笔记`、`导图主题`、`节点图标`。
  - 激活状态的 Tab 使用 `forui` 风格的圆角蓝色底色 `Color(0xFF1862C6)`，并伴有发光阴影特效。
- **侧边栏内容面板**：
  - 宽度为 `320px`，背景为 `Color(0xFF141921)`，左边框为 `Color(0x1F2A3547)`。
  - **节点笔记 (Note Panel)**：
    - 头部栏右侧新增同级节点导航按钮 `<` 和 `>`，点击分别触发 `controller.navigateSibling('prev')` 和 `controller.navigateSibling('next')`。
  - **导图主题 (Style Panel)**：
    - 完全高保真重构颜色预设。画布背景色提供 4 款经典 HSL 预设（经典暗黑、深空灰蓝、暗绿森林、幽冥幻紫）。网格线颜色提供 4 款预设。
    - 添加“网格显示”开关（使用 `FSwitch`）与“网格大小”调节滑块（使用 `FSlider`）。
  - **节点图标 (Icon Panel)**：
    - 高保真表情网格选择。

---

## 2. ForUI 控件深度适配

页面内所有的交互控键全部迁移至 `forui` 组件：
1. **FButton**：应用于面包屑栏按钮、底部控制条按钮、Markdown 编辑器工具栏中的每一个按钮。
2. **FTextField**：应用于节点笔记文本输入框，启用透明背景并支持 Markdown 快捷指令写入。
3. **FSwitch**：应用于导图主题设置面板中的“网格显示”开关。
4. **FSlider**：应用于导图主题设置面板中的“网格大小”调节滑块。
5. **Markdown 编辑工具栏**：
   - 重构为紧凑的双行 `FButton` 图标矩阵。
   - 第一行：`H`、`B`、`I`、`S`（删除线格式）、`Link`、`Separator`、`Unordered List`、`Ordered List`、`Task List`、`Separator`、`Quote`、`Divide Line`。
   - 第二行：`Codeblock`、`Inline Code`、`Separator`、`Upload Attachment`、`Table`、`Separator`、`Undo`、`Redo`。

---

## 3. 双视口分屏机制设计 (Split View Integration)

按照用户的指示，“分屏是用最右上角的那个分屏按钮，点击后会让你选择目前已有的 pdf 或者思维导图，选中后就能进行分屏”。

### 3.1 状态管理
在 `MindMapController` 中定义分屏共享状态：
- `String? _splitType` (值为 `'pdf'`、`'mindmap'` 或 `null`)
- `String? _splitId` (PDF 文件的 ID 或思维导图的 Topic ID)
- `String? _splitTitle` (分屏页面的标题)
- `String? _splitFilePath` (PDF 物理沙盒文件路径)
- 控制方法：`openSplitScreen(type, id, title, [filePath])` 和 `closeSplitScreen()`。

### 3.2 分屏选项弹窗 (Frosted Selection Dialog)
- 点击右上角分屏按钮时，在 `MindMapPage` 中弹出一个半透明磨砂玻璃对话框。
- 通过 `context.workspaceController.documents` 获取所有已导入的 PDF 文件。
- 通过 `MindMapService.getAllTopics()` 异步获取所有已有的思维导图。
- 弹窗内展示两个列表：“PDF 文档” 与 “思维导图”，并附带“关闭分屏”按钮。
- 用户选中任一项后，触发 `controller.openSplitScreen`。

### 3.3 布局自适应渲染
在 `MindMapTabViewport` (定义在 `lib/main.dart`) 中监听 `controller.splitType`：
- **若为 `null`**：渲染默认的单屏 `MindMapPage`。
- **若为 `'pdf'`**：在 `Row` 中以 `0.5 : 0.5` 的比例横向分屏：
  - 左侧：`MindMapPage(controller: controller)`
  - 右侧：`PdfTabViewport(docId: splitId, filePath: splitFilePath, pdfController: _getOrBuildSplitPdfController(splitId, splitFilePath))`。
- **若为 `'mindmap'`**：
  - 左侧：`MindMapPage(controller: controller)`
  - 右侧：`MindMapPage(controller: MindMapController(service, splitId)..loadTopic())` (支持两个脑图并排交互！)。

---

## 4. 连线位置偏移与定位算法修复

修复当前贝塞尔连线偏置与节点高度计算缺陷：
1. **InteractiveViewer 平移补偿**：在 `tree_layout.dart` 的连线生成中，由于节点的位置使用 `Positioned(left: pos.dx - size.width/2 + 500, top: pos.dy + 500)`，生成 `Connection` 的 `start` 与 `end` 坐标时必须加上相应的 `500.0` 偏置（包括 X 轴与 Y 轴）。
2. **中心锚点精确定位**：连线的 Y 坐标接入节点的实际排布高度 `size.height`。
   - `start` 的 Y 轴为：`parentPos.dy + parentSize.height / 2 + 500`
   - `end` 的 Y 轴为：`childPos.dy + childSize.height / 2 + 500`
   此举将彻底修复任何普通节点或容器（nestedCard）节点与曲线之间的错位，保证贝塞尔连线平滑接入节点的正中心垂直边缘。
