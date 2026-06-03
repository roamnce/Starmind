# MindMap 思维导图功能设计文档

**日期**: 2026-05-30
**版本**: 1.0
**状态**: 待实现

---

## 一、产品概述

### 1.1 愿景

将 Starmind 从"PDF 阅读器"进化为"知识管理工具"——用户在阅读 PDF 时可以摘录文字、截图、手写笔迹到思维导图画布上，形成结构化的知识网络，并支持跨文档关联。

### 1.2 核心价值链

```
PDF 阅读 → 选中内容 → 一键摘录 → 生成节点卡片 → 画布上自由组织
                                    ↕ 双向链接
PDF 阅读 ← 点击节点跳回源文 ← 节点卡片（富文本/图片/手写）
```

### 1.3 核心决策汇总

| 维度 | 决策 |
|------|------|
| 核心功能 | PDF 摘录 → 思维导图节点 + 节点画布 |
| UI 关系 | PDF 左 / 画布右，同屏并排 |
| 分屏机制 | Tab 拖动触发分屏，分屏时可选择配对的思维导图 |
| 节点形态 | 富文本卡片（文字 + 图片截图 + 手写笔迹） |
| 连接关系 | 层级树为默认 + 任意跨层级自由链接（有向图） |
| 摘录桥接 | 先一键摘录，后续加拖拽落点 |
| 绑定模型 | 松耦合运行时配对，摘录创建永久双向链接 |
| 文件管理 | 思维导图与 PDF 并列在文件夹树中，主页筛选加入"思维导图"分类 |

---

## 二、领域模型

### 2.1 实体关系总览

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│   Document   │◄──────│   SourceLink     │──────►│ MindMapNode  │
│  (existing)  │       │  bridge table    │       │              │
└──────────────┘       └──────────────────┘       └──────┬───────┘
                                                         │
                                                         │ belongs to
                                                         ▼
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│    Folder    │───────│    MindMap       │───────│ MindMapEdge  │
│  (existing)  │       │                  │       │              │
└──────────────┘       └──────────────────┘       └──────────────┘
```

### 2.2 `MindMap`（思维导图）

一个思维导图是画布上的节点和边的容器，与 PDF Document 并列存储于文件夹中。

```
MindMap
├── id: String                          // UUID
├── title: String                       // 用户命名，如"第一章笔记"
├── folderId: String?                   // 归属文件夹，null = 未分类
├── rootNodeId: String?                 // 根节点 ID（可选）
├── layoutMode: LayoutMode              // 'tree' | 'freeform'
├── createdAt: DateTime
├── modifiedAt: DateTime
└── isTrashed: bool                     // 回收站标记
```

### 2.3 `MindMapNode`（节点）

思维导图中的一个知识卡片。每个节点有且仅有一个父节点（通过 `parentId` 建立层级关系），但可以有多个子节点和多条自由链接。

```
MindMapNode
├── id: String                          // UUID
├── mindMapId: String                   // 所属思维导图
├── parentId: String?                   // 父节点 ID，null = 根节点或孤立节点
├── sortOrder: int                      // 同级节点排序序号
├── positionX: double                   // 画布坐标 X（tree 模式下由算法写入，freeform 下用户手动设定）
├── positionY: double                   // 画布坐标 Y
├── width: double                       // 节点卡片宽度（由内容自动计算）
├── height: double                      // 节点卡片高度（由内容自动计算）
├── colorHex: String                    // 节点背景色
├── isCollapsed: bool                   // 是否折叠子节点树
├── createdAt: DateTime
└── modifiedAt: DateTime

// 节点内容（通过 content 字段存储为 JSON）
NodeContent
├── text: String?                       // 纯文本 / 富文本内容
├── imageRefs: List<String>?            // 图片存储路径列表
├── inkStrokes: List<InkStroke>?        // 手写笔迹（复用现有 InkStroke 模型）
└── sourceLink: SourceLink?             // 来源链接（指向 PDF 的某个位置）
```

### 2.4 `SourceLink`（来源链接）

节点与 PDF 之间的桥梁。当用户从 PDF 摘录内容创建节点时，自动生成。同时支持从 PDF 侧维护反向索引，以便"查看此 PDF 的所有摘录"。

```
SourceLink
├── id: String                          // UUID
├── nodeId: String                      // 关联的节点 ID
├── documentId: String                  // 来源 PDF 文档 ID
├── documentTitle: String               // 冗余标题（读优化，避免 JOIN 查询）
├── pageIndex: int                      // 页码
├── startCharIndex: int?                // 起始字符索引
├── endCharIndex: int?                  // 结束字符索引
├── selectedText: String?               // 原文摘录文本（冗余存储）
├── annotationId: String?               // 关联的 Annotation ID（如果摘录同时创建了高亮）
└── createdAt: DateTime
```

### 2.5 `MindMapEdge`（边/连接线）

节点之间的连接关系。分为两种类型：
- **hierarchical（层级边）**：由 `parentId` 隐式派生，表示父子层级关系
- **free（自由链接）**：用户手动创建的跨层级关联

```
MindMapEdge
├── id: String                          // UUID
├── mindMapId: String
├── sourceNodeId: String                // 起始节点
├── targetNodeId: String                // 目标节点
├── edgeType: EdgeType                  // 'hierarchical' | 'free'
├── label: String?                      // 可选边标签
├── colorHex: String?                   // 可选边颜色（自由链接可自定义）
└── createdAt: DateTime
```

> **层级边的存储策略**：层级边（`edgeType == 'hierarchical'`）实际上由 `MindMapNode.parentId` 隐式定义，可以不显式存储在 `MindMapEdge` 表中。只有 `free` 类型的边需要存入 `MindMapEdge` 表。画布渲染时，从所有节点的 `parentId` 动态生成层级边列表。这样避免了 `parentId` 和 `hierarchical edge` 的双重维护问题。

### 2.6 与现有模型的关系

| 新模型 | 依赖的现有模型 | 关系 |
|--------|-------------|------|
| `MindMap` | `Folder` | 属于某个 Folder，与 Document 并列 |
| `MindMap` | `Tag` | 可关联多个 Tag（复用现有 `document_tags` 表模式） |
| `MindMapNode` | `InkStroke` | 节点可包含手写笔迹（直接复用） |
| `MindMapNode` | `Annotation` | 通过 `SourceLink.annotationId` 关联 |
| `SourceLink` | `Document` | 指向来源 PDF |
| `SourceLink` | `Annotation` | 可选关联到 PDF 上的高亮批注 |

### 2.7 `LayoutMode` 枚举

```dart
enum LayoutMode {
  tree,       // 自动布局：Walker 算法排列节点，适合层级结构
  freeform,   // 自由布局：用户手动拖拽定位，适合自由思维
}
```

### 2.8 `EdgeType` 枚举

```dart
enum EdgeType {
  hierarchical,  // 父子层级边（由 parentId 隐式定义）
  free,          // 跨层级自由链接（用户手动创建）
}
```

---

## 三、布局引擎

### 3.1 设计原则

借鉴 graphview 的**算法与渲染分离**架构：布局算法是一个纯函数，输入是节点和边的图结构，输出是每个节点的坐标位置。渲染层拿到坐标后自行绘制。

```
┌─────────────────┐     ┌───────────────────┐     ┌─────────────────┐
│  MindMapModel   │────→│  LayoutEngine     │────→│  CanvasRender   │
│  (节点 + 边)    │     │  (纯计算)         │     │  (绘制坐标)     │
└─────────────────┘     └───────────────────┘     └─────────────────┘
```

### 3.2 `LayoutEngine` 接口

```dart
abstract class LayoutEngine {
  /// 给定节点和边，计算每个节点的坐标位置。
  /// 返回 Map<String, Offset>，key 是 nodeId，value 是计算后的 (x, y) 坐标。
  Map<String, Offset> compute({
    required List<MindMapNode> nodes,
    required List<MindMapEdge> edges,
    required Size viewportSize,
  });
}
```

### 3.3 Walker 算法实现（Tree 布局）

借鉴 graphview 的 `BuchheimWalkerAlgorithm`，实现精简版 Walker 树形布局算法。

**核心思想**：
1. 自底向上计算每个节点的子树宽度
2. 自顶向下分配水平和垂直位置
3. 后序遍历修正重叠

**算法流程**：

```
输入: 根节点 root，节点树
输出: 每个节点的 (x, y) 坐标

Step 1: 第一遍后序遍历（自底向上）
  对每个节点 n:
    if n 是叶子节点:
      n.prelim = 0
    else:
      计算所有子节点的 prelim 偏移
      用 Walker 的分离/重叠修正算法调整子节点间距

Step 2: 第二遍前序遍历（自顶向下）
  对每个节点 n:
    n.x = n.parent.x + 水平间距 + n.prelim
    n.y = n.depth * 垂直间距

Step 3: 中心修正
  以根节点为参考，将整个树平移到视口中心
```

**关键参数**（参考 graphview 的 `BuchheimWalkerConfiguration`）：

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `siblingSeparation` | 同级节点间最小水平距离 | 40.0 |
| `subtreeSeparation` | 不同子树间最小水平距离 | 60.0 |
| `levelSeparation` | 父子层级间垂直距离 | 100.0 |
| `orientation` | 布局方向 | `ORIENTATION_LEFT_RIGHT` |

**水平分叉策略**（借鉴 graphview 的 `MindmapAlgorithm`）：
- 根节点居中
- 子节点交替分配到左右两侧（奇数索引在右，偶数索引在左）
- 左侧子树水平方向镜像翻转

### 3.4 Freeform 自由布局

在 `freeform` 模式下，`LayoutEngine` 不做任何计算，直接返回每个节点的当前存储坐标。用户通过拖拽自由调整节点位置，位置变更持久化到 SQLite。

### 3.5 模式切换

- **Tree → Freeform**：切换时将当前算法计算的坐标写入每个节点的 `positionX/positionY`，然后切换为 freeform 模式。
- **Freeform → Tree**：切换时触发 Walker 算法重新计算所有坐标，覆盖用户手动设定的位置。切换前弹出确认对话框。

---

## 四、画布渲染

### 4.1 画布架构

复用现有 `InteractiveCanvasViewer` 作为画布的缩放/平移容器（与 PDF 视口共用同一套手势和变换逻辑），在其上叠加节点渲染层和连线渲染层。

```
┌──────────────────────────────────────────────────────────┐
│                 MindMapCanvas (StatefulWidget)             │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  InteractiveCanvasViewer (复用现有)                    │  │
│  │  - TransformationController (缩放/平移)               │  │
│  │  - 手势路由: 拖拽节点 vs 平移画布                      │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  CustomPaint: EdgeRenderer                    │   │  │
│  │  │  - 层级边: 贝塞尔曲线                          │   │  │
│  │  │  - 自由边: 直线或虚线 + 可选箭头                 │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Stack: NodeLayer                             │   │  │
│  │  │  - Positioned(node.x, node.y)                 │   │  │
│  │  │  - 每个节点: MindMapNodeWidget                 │   │  │
│  │  │    - 富文本内容                                │   │  │
│  │  │    - 图片缩略图                                │   │  │
│  │  │    - 手写笔迹预览                              │   │  │
│  │  │    - 来源跳转按钮                              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Toolbar (浮动工具栏)                                │  │
│  │  - 添加节点 / 切换布局 / 缩放适配 / 撤销重做          │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### 4.2 节点卡片渲染 (`MindMapNodeWidget`)

每个节点是一个 Flutter Widget，包含以下元素：

```
┌──────────────────────────────────┐
│ [来源图标] 文档标题 · 第3页  [跳转] │  ← SourceLink 快捷栏（可选显示）
├──────────────────────────────────┤
│                                  │
│  摘录的文本内容                    │  ← text 字段
│                                  │
├──────────────────────────────────┤
│  [图片缩略图]                     │  ← imageRefs（如有）
├──────────────────────────────────┤
│  ≈≈ 手写笔迹预览 ≈≈              │  ← inkStrokes（如有）
└──────────────────────────────────┘
       │
       ├─ 子节点连线出口（底部/右侧）
       └─ 自由链接连线出口（任意边）
```

**交互行为**：
- **单击**：选中节点（高亮边框）
- **双击**：编辑文本内容（Inline Text Editor）
- **长按**：弹出上下文菜单（删除、改色、拆分子节点、创建自由链接）
- **拖拽**（freeform 模式）：移动节点位置
- **拖拽**（tree 模式）：拖拽改变父子关系（松手到另一个节点上成为其子节点）
- **点击来源跳转按钮**：跳转到 PDF 原文位置（切换到 PDF 标签页并滚动到对应位置）

### 4.3 连线渲染 (`EdgeRenderer`)

使用 `CustomPaint` 绘制连线：

**层级边（hierarchical）**：
- 贝塞尔曲线，从父节点出口点到子节点入口点
- 颜色跟随父节点 `colorHex`，透明度 0.4
- 线宽 2.0

**自由边（free）**：
- 直线或虚线
- 可自定义颜色和线型
- 可选箭头标记方向

### 4.4 画布手势处理

核心挑战：**拖拽节点** 和 **平移画布** 手势冲突。解决方案：

| 场景 | 手势 | 行为 |
|------|------|------|
| 手指/笔触落在**节点上** | 拖拽 | 移动节点（freeform）或改变层级关系（tree） |
| 手指/笔触落在**空白区域** | 拖拽 | 平移整个画布 |
| 双指 | 捏合 | 缩放画布 |
| 长按空白区域 | 长按 | 弹出"在此处新建节点"菜单 |

实现方式：在 `InteractiveCanvasViewer` 之上叠加一个 `GestureDetector`，通过 `hitTest` 判断触点是否落在某个节点的 `Rect` 内。

### 4.5 与 PDF 视口的复用

画布复用 `InteractiveCanvasViewer` + `TransformationController` 的核心变换逻辑（缩放、平移、边界约束）。但**不复用** PDF 特有的渲染逻辑（瓦片渲染、页面虚拟化、文字选择）。

---

## 五、PDF ↔ MindMap 桥接

### 5.1 摘录流程（一键摘录）

```
用户在 PDF 中选中文字
        │
        ▼
选中工具栏弹出 → 点击"摘录到思维导图"按钮
        │
        ▼
检查当前分屏是否配对了思维导图
        │
        ├── 是 → 弹出确认面板（选择追加为哪个节点的子节点，或新建根节点）
        │         │
        │         ▼
        │   创建 MindMapNode（text = 选中文字）
        │   创建 SourceLink（documentId, pageIndex, charRange, selectedText）
        │   同时可选创建 Annotation（高亮，复用现有批注系统）
        │   自动布局 / 出现在画布上
        │
        └── 否 → 弹出提示"请先分屏并配对一个思维导图"
```

### 5.2 跳转回 PDF

```
用户点击节点卡片上的来源跳转按钮
        │
        ▼
读取 SourceLink（documentId, pageIndex）
        │
        ▼
如果目标 PDF 未打开 → 自动创建 PDF 标签页
如果目标 PDF 已打开 → 切换到该标签页
        │
        ▼
PdfViewportController.scrollToPage(pageIndex)
如果 startCharIndex/endCharIndex 存在 → 高亮对应文字
```

### 5.3 反向查询：PDF 的所有摘录

在 PDF 视图的摘录侧栏中，新增"思维导图摘录"分组：
- 查询所有 `SourceLink` 中 `documentId == 当前文档` 的记录
- 按 `pageIndex` 分组显示
- 点击某条摘录 → 跳转到对应的思维导图画布并聚焦该节点

### 5.4 运行时分屏配对

分屏配对是**运行时的临时关系**，不持久化到数据库。配对关系存储在 `WorkspaceController` 内存中：

```dart
class SplitPairing {
  final String pdfTabId;       // 左侧 PDF 标签页 ID
  final String mindMapTabId;   // 右侧思维导图标签页 ID
}
```

- 用户在分屏后，右侧画布通过选择器指定一个思维导图
- 一个 PDF 可以同时与多个思维导图分屏配对（多面板场景）
- 解除分屏时，配对关系自动清除
- 摘录操作只作用于当前配对的思维导图

---

## 六、分屏集成

### 6.1 TabType 扩展

在现有 `TabType` 枚举中新增 `mindmap`：

```dart
enum TabType { home, pdf, mindmap }
```

`TabItem` 新增字段：

```dart
class TabItem {
  final String id;
  final TabType type;
  final String title;
  final String? filePath;    // PDF 专用
  final String? mindMapId;   // MindMap 专用
}
```

### 6.2 分屏触发流程

```
用户拖拽 PDF 标签页到边缘
        │
        ▼
SplitPanel 检测拖拽位置 → 弹出"选择分屏内容"面板
        │
        ├── 选择一个已有的思维导图 → 新建 LeafNode，打开该思维导图标签页
        ├── 选择"新建思维导图" → 创建空白思维导图 → 打开
        └── 选择另一个 PDF → 按现有逻辑分屏（非 MindMap 功能）
        │
        ▼
ParentNode 创建（direction = horizontal）
左侧: PDF LeafNode
右侧: MindMap LeafNode
        │
        ▼
自动建立运行时配对关系 SplitPairing
```

### 6.3 分屏布局

```
┌────────────────────────────────────────────────────────────┐
│  [Home] [PDF-A.pdf] [MindMap-第一章]                         │  ← Tab Bar
├───────────────────────────────┬────────────────────────────┤
│                               │                            │
│                               │   ┌────────────────────┐   │
│                               │   │ 摘录的文本卡片       │   │
│     PDF 视口                  │   │                    │   │
│     (左侧，55%)              │   ├────────────────────┤   │
│                               │   │ [图片] 手写笔记      │   │
│     ← 高亮选中文字             │   │                    │   │
│     ← 工具栏新增"摘录"按钮      │   ├────────────────────┤   │
│                               │   │ 子节点卡片          │   │
│                               │   └────────────────────┘   │
│                               │                            │
│                               │   思维导图画布（右侧，45%）  │
│                               │                            │
├───────────────────────────────┴────────────────────────────┤
│  [页码] [缩放] [沉浸模式]                                    │  ← 状态栏
└────────────────────────────────────────────────────────────┘
```

---

## 七、存储层

### 7.1 SQLite 表结构

#### `mind_maps` 表

```sql
CREATE TABLE mind_maps (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  folder_id TEXT,
  root_node_id TEXT,
  layout_mode TEXT NOT NULL DEFAULT 'tree',
  is_trashed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);
```

#### `mind_map_nodes` 表

```sql
CREATE TABLE mind_map_nodes (
  id TEXT PRIMARY KEY,
  mind_map_id TEXT NOT NULL,
  parent_id TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  position_x REAL NOT NULL DEFAULT 0,
  position_y REAL NOT NULL DEFAULT 0,
  width REAL NOT NULL DEFAULT 160,
  height REAL NOT NULL DEFAULT 80,
  color_hex TEXT NOT NULL DEFAULT '#FFFFFF',
  is_collapsed INTEGER NOT NULL DEFAULT 0,
  content_json TEXT,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  FOREIGN KEY (mind_map_id) REFERENCES mind_maps(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES mind_map_nodes(id) ON DELETE SET NULL
);
```

#### `source_links` 表

```sql
CREATE TABLE source_links (
  id TEXT PRIMARY KEY,
  node_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  document_title TEXT NOT NULL,
  page_index INTEGER NOT NULL,
  start_char_index INTEGER,
  end_char_index INTEGER,
  selected_text TEXT,
  annotation_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY (annotation_id) REFERENCES annotations(id) ON DELETE SET NULL
);
```

#### `mind_map_edges` 表

```sql
CREATE TABLE mind_map_edges (
  id TEXT PRIMARY KEY,
  mind_map_id TEXT NOT NULL,
  source_node_id TEXT NOT NULL,
  target_node_id TEXT NOT NULL,
  edge_type TEXT NOT NULL DEFAULT 'free',
  label TEXT,
  color_hex TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (mind_map_id) REFERENCES mind_maps(id) ON DELETE CASCADE,
  FOREIGN KEY (source_node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE,
  FOREIGN KEY (target_node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE
);
```

### 7.2 `StorageRepository` 接口扩展

在现有 `StorageRepository` 中新增 MindMap 相关方法：

```dart
abstract class StorageRepository {
  // ... existing methods ...

  // MindMap
  Future<String> createMindMap(String title, String? folderId, LayoutMode layoutMode);
  Future<void> renameMindMap(String id, String newTitle);
  Future<void> deleteMindMap(String id);
  Future<void> moveMindMap(String id, String? newFolderId);
  Future<MindMap?> getMindMap(String id);
  Future<List<MindMap>> getMindMaps({
    String? folderId,
    String? tagId,
    String? searchQuery,
    String sortBy = 'recent',
  });

  // MindMapNode
  Future<String> createNode(MindMapNode node);
  Future<void> updateNode(MindMapNode node);
  Future<void> deleteNode(String id);
  Future<void> moveNode(String nodeId, String? newParentId, int sortOrder);
  Future<List<MindMapNode>> getNodes(String mindMapId);

  // MindMapEdge (free edges only)
  Future<String> createEdge(MindMapEdge edge);
  Future<void> deleteEdge(String id);
  Future<List<MindMapEdge>> getFreeEdges(String mindMapId);

  // SourceLink
  Future<String> createSourceLink(SourceLink link);
  Future<void> deleteSourceLink(String id);
  Future<List<SourceLink>> getSourceLinksByNode(String nodeId);
  Future<List<SourceLink>> getSourceLinksByDocument(String documentId);
}
```

---

## 八、主页集成

### 8.1 侧边栏

在现有侧边栏的文件夹树中，每个文件夹下同时显示 PDF 文档和思维导图。

### 8.2 首页筛选栏

现有筛选栏 `['全部', '笔记', 'PDF']` 扩展为 `['全部', '笔记', 'PDF', '思维导图']`：

| 筛选项 | 显示内容 |
|--------|---------|
| 全部 | 所有 Document + MindMap |
| 笔记 | 暂空（未来功能） |
| PDF | 仅 Document |
| 思维导图 | 仅 MindMap |

### 8.3 卡片展示

思维导图卡片与 PDF 卡片并列展示在网格中，但视觉区分：
- PDF 卡片：保持现有封面渐变风格
- 思维导图卡片：显示缩略预览（画布截图或节点数量统计），带思维导图图标标识

---

## 九、`WorkspaceController` 扩展

### 9.1 新增状态

```dart
class WorkspaceController {
  // ... existing state ...

  // MindMap 相关
  List<MindMap> _mindMaps = [];
  Map<String, List<MindMapNode>> _mindMapNodes = {};  // mindMapId -> nodes
  Map<String, List<MindMapEdge>> _mindMapFreeEdges = {};  // mindMapId -> free edges

  // 运行时分屏配对
  final Map<String, String> _splitPairings = {};  // pdfTabId -> mindMapTabId
}
```

### 9.2 新增方法

```dart
// MindMap CRUD
Future<void> createMindMap(String title, String? folderId);
Future<void> deleteMindMap(String id);
Future<void> openMindMap(MindMap mindMap);  // 打开为标签页

// 分屏配对
void pairWithMindMap(String pdfTabId, String mindMapId);
void unpairMindMap(String pdfTabId);
String? getPairedMindMapId(String pdfTabId);

// 摘录
Future<void> excerptToMindMap({
  required String documentId,
  required int pageIndex,
  required int startCharIndex,
  required int endCharIndex,
  required String selectedText,
  String? parentNodeId,
  String? annotationId,
});

// 跳转
void jumpToPdfSource(SourceLink link);
```

---

## 十、实现阶段规划

### Phase M1：节点与画布基础（核心 MVP）

**目标**：在一个独立的思维导图画布上，可以创建节点、编辑文本、自由拖拽定位、手动连线。

**范围**：
- 领域模型：`MindMap`, `MindMapNode`, `MindMapEdge`, `LayoutMode`, `EdgeType`
- SQLite 表：`mind_maps`, `mind_map_nodes`, `mind_map_edges`
- `StorageRepository` 方法扩展 + Rust FFI 实现
- `MindMapCanvas` 画布组件（复用 `InteractiveCanvasViewer`）
- `MindMapNodeWidget` 节点卡片（纯文本模式）
- `EdgeRenderer` 连线绘制
- 节点拖拽定位 + 手动创建/删除
- 手动创建自由链接（从节点 A 拉线到节点 B）
- `WorkspaceController` MindMap CRUD
- Tab 类型扩展（`TabType.mindmap`）
- 在侧边栏文件夹树和主页网格中展示思维导图

**不包含**：PDF 摘录桥接、分屏配对、富文本/图片、Walker 自动布局

### Phase M2：摘录桥接

**目标**：从 PDF 选中文字后一键摘录，生成节点并建立双向链接。

**范围**：
- `SourceLink` 模型 + `source_links` 表
- PDF 选中工具栏新增"摘录到思维导图"按钮
- 摘录确认面板（选择目标思维导图、父节点）
- 节点卡片显示来源快捷栏 + 跳转按钮
- 跳转回 PDF 原文（自动打开/切换标签页 + 滚动到页码）
- PDF 摘录侧栏新增"思维导图摘录"分组
- `excerptToMindMap()` + `jumpToPdfSource()` 实现

### Phase M3：分屏配对

**目标**：支持 PDF + 思维导图分屏并排显示，摘录自动落到配对的画布。

**范围**：
- 分屏选择面板（选择已有思维导图 / 新建思维导图）
- `SplitPairing` 运行时配对管理
- 分屏状态下摘录直接落到配对画布（无需选择目标）
- 分屏拖拽交互优化

### Phase M4：Walker 自动布局 + 层级树

**目标**：支持 Tree 自动布局模式，父子层级关系。

**范围**：
- `LayoutEngine` 接口 + `WalkerLayoutEngine` 实现
- MindmapAlgorithm 左右分叉策略
- LayoutMode 切换（tree ↔ freeform）
- 树模式下拖拽改变父子关系
- 节点展开/折叠交互 + 动画

### Phase M5：富文本节点

**目标**：节点卡片支持图片、手写笔迹。

**范围**：
- `NodeContent` 图片和手写笔迹字段
- 图片插入（从文件选择器 / 从 PDF 截图区域）
- 手写笔迹嵌入（复用现有 `InkCanvasLayer`，在节点内绘制）
- 节点卡片自适应高度计算

### Phase M6：拖拽落点摘录

**目标**：从 PDF 直接拖拽选区到画布上松手，自动生成节点。

**范围**：
- 跨面板拖拽手势识别
- 拖拽视觉反馈（拖拽过程中的半透明卡片预览）
- 松手位置自动计算 + 节点生成
- 自动建立层级关系（松手位置靠近某节点 → 成为其子节点）

---

## 十一、技术风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|----------|
| Walker 算法实现复杂度 | 节点布局效果不理想 | 参考 graphview 的 `BuchheimWalkerAlgorithm` 源码，实现精简版；初期可用简单的水平/垂直排列作为 fallback |
| 节点拖拽与画布平移手势冲突 | 交互混乱 | 通过 hitTest 区分：触点在节点上 → 拖拽节点；触点在空白处 → 平移画布 |
| 大量节点时画布性能 | 卡顿 | 虚拟化渲染（只渲染视口内可见节点，复用 PDF 页面虚拟化的思路） |
| `main.dart` 持续膨胀 | 可维护性下降 | MindMap 所有组件放到 `lib/src/mindmap/` 目录下，Phase M1 同步重构 main.dart |
| SourceLink 与 Annotation 双向关联 | 数据一致性 | 使用事务写入；删除 Annotation 时级联更新 SourceLink |
