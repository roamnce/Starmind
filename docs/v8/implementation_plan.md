# 思维导图模块嵌套卡片布局 (v8.0) - Phase 2 设计与实现计划

本计划旨在实现思维导图模块的 **Phase 2：嵌套卡片布局 (Nested Card Layout / Grouping)**。嵌套卡片布局类似于 MarginNote 中的卡片组结构，允许将子树节点打包组合为一个卡片容器，且容器内可以递归嵌套树状或卡片式布局。

---

## 1. 核心架构设计与算法逻辑 (Nested Layout Engine)

嵌套卡片布局的核心难点在于**尺寸的递归依赖**：父级容器卡片的尺寸（宽与高）取决于其所有子级卡片/节点完成排布后的整体边界大小 (Layout Bounds)。

为了实现这一自适应布局，我们将分三步重构 `TreeLayout`：

### 1.1 步骤一：定义布局模式 (LayoutMode)
每个节点拥有自己的布局属性，我们在 `Note` 或通过布局推导来确定节点是否渲染为容器卡片：
*   `normal`: 普通分支节点，采用标准树形线缆连接。
*   `nestedCard`: 嵌套容器卡片，其子节点以紧凑的卡片组排列在它内部。

### 1.2 步骤二：自底向上尺寸计算 (Post-order Size Evaluation)
对脑图树进行**后序遍历**（自底向上）计算每个节点或卡片的有效渲染大小：
1.  如果是**叶子节点**，返回默认大小：`width = nodeWidth`, `height = nodeHeight`。
2.  如果是**嵌套卡片组节点 (nestedCard)**：
    *   首先对其所有子节点进行子布局（默认以紧凑卡片垂直或网格排列，不带长线缆，仅用细线或无缝紧贴）。
    *   计算出子节点排布的边界框 `childBounds`。
    *   该嵌套卡片的最终宽度 = `max(nodeWidth, childBounds.width) + padding * 2`。
    *   该嵌套卡片的最终高度 = `nodeHeight + childBounds.height + spacing + padding * 2`。
3.  如果是**普通节点 (normal)**：
    *   其尺寸仍为 `nodeWidth` 和 `nodeHeight`，但在进行父级 `TreeLayout` 排布时，其后代节点如果包含嵌套卡片，需采用后代计算出的有效大尺寸进行间距预留。

### 1.3 步骤三：自顶向下坐标投影 (Pre-order Absolute Offset Projection)
对脑图树进行**先序遍历**（自顶向下）投影绝对偏移量：
1.  根据自底向上计算的有效尺寸，对整树进行多向树形排布，得出各顶级节点和嵌套卡片容器的相对坐标 `positions`。
2.  对于每一个嵌套卡片内部的子节点，其子布局计算的坐标是相对容器左上角的 `(localX, localY)`。
3.  遍历时，将容器在画布上的绝对坐标加上其内部局部坐标，换算为画布绝对坐标并保存：
    $$X_{absolute} = X_{parent\_left} + X_{local} + padding$$
    $$Y_{absolute} = Y_{parent\_top} + Y_{local} + padding$$

---

## 2. 拟修改文件与 Proposed Changes

### 2.1 [MODIFY] [tree_layout.dart](file:///d:/starmind/lib/src/mindmap/ui/tree_layout.dart)
*   引入 `LayoutMode` 属性或在 `LayoutDirection` 之外增加卡片嵌套计算类。
*   重构 `TreeLayout` 以支持：
    *   `calculateNodeSizes(NoteTreeNode node)`：后序递归计算每个子树的有效宽高尺寸。
    *   `calculate(NoteTreeNode root)`：重写排布计算，将嵌套容器卡片作为大尺寸节点对待，并向下级递归投影绝对坐标。
    *   `calculateConnections(NoteTreeNode root, Map<String, Offset> positions)`：嵌套容器卡片内部的节点之间，不绘制标准贝塞尔连线，改用细直线或不画线（符合 MarginNote 的无缝贴合卡片质感）；仅在容器卡片与其他普通树节点之间绘制标准曲线。

### 2.2 [MODIFY] [node_widget.dart](file:///d:/starmind/lib/src/mindmap/ui/node_widget.dart)
*   扩展 `NodeWidget` 支持容器卡片渲染模式 (`isContainer = true`)：
    *   容器卡片渲染为一个大半透明边框面板，拥有自己独立的圆角、微光金色边框，以及独立的层级感背景。
    *   容器卡片头部显示该组的标题（如“AI配音”），其主体空间预留给嵌套在其内部的子节点。
    *   支持容器卡片双击折叠/展开，折叠时自底向上尺寸缩减为普通节点大小，自动触发表格重排。

### 2.3 [MODIFY] [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart)
*   配合 `NodeWidget` 容器节点渲染，调整 `Stack` 层级：容器卡片作为背景框定位在底层，其子节点作为定位 Widget 叠加在它上层。

---

## 3. 验证计划 (Verification Plan)

### 3.1 单元测试
*   在 `test/mindmap/ui/tree_layout_test.dart` 中增加嵌套卡片布局的测试用例：
    *   验证叶子节点大小计算。
    *   验证包含子节点的 `nestedCard` 容器节点尺寸自适应边界框计算。
    *   验证绝对坐标计算中，子节点相对于父级容器的偏移量投影是否正确。

### 3.2 手工校验
*   运行应用，添加多个层级的嵌套子节点，切换布局，验证：
    *   容器边框完美贴合包裹所有内部子卡片。
    *   双击折叠容器时，整树平滑重新布局，没有任何重叠。
