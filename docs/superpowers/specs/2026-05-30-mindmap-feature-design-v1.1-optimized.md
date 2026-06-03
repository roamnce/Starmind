# MindMap 思维导图功能设计文档 (优化版)

**日期**: 2026-05-30
**版本**: 1.1 (优化版)
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

## 二、文件结构规划

### 2.1 Dart 侧文件结构

```
lib/src/mindmap/
├── domain/
│   ├── mind_map.dart              # MindMap 实体
│   ├── mind_map_node.dart         # MindMapNode 实体
│   ├── mind_map_edge.dart         # MindMapEdge 实体
│   ├── source_link.dart           # SourceLink 实体
│   ├── layout_mode.dart           # LayoutMode 枚举
│   └── edge_type.dart             # EdgeType 枚举
├── storage/
│   └── mind_map_repository.dart   # MindMap 存储操作（扩展 StorageRepository）
├── canvas/
│   ├── mind_map_canvas.dart       # 主画布组件
│   ├── node_widget.dart           # 节点卡片组件
│   ├── edge_renderer.dart         # 连线绘制 (CustomPainter)
│   └── canvas_toolbar.dart        # 画布工具栏
├── controller/
│   └── mind_map_controller.dart   # 思维导图状态管理
└── widgets/
    ├── node_edit_dialog.dart      # 节点编辑弹窗
    └── excerpt_panel.dart         # 摘录确认面板
```

### 2.2 Rust 侧文件结构

```
rust/src/storage/
├── mind_maps.rs                   # MindMap 存储操作
├── mind_map_nodes.rs              # MindMapNode 存储操作
├── mind_map_edges.rs              # MindMapEdge 存储操作
└── source_links.rs                # SourceLink 存储操作
```

### 2.3 FFI 接口文件

```
rust/src/api/storage.rs            # 扩展现有文件，添加 MindMap 相关 FFI
lib/src/rust/storage/
├── mind_maps.dart                 # FFI 生成的 MindMap 类型
├── mind_map_nodes.dart            # FFI 生成的 MindMapNode 类型
├── mind_map_edges.dart            # FFI 生成的 MindMapEdge 类型
└── source_links.dart              # FFI 生成的 SourceLink 类型
```

### 2.4 测试文件结构

```
test/mindmap/
├── domain/
│   ├── mind_map_test.dart
│   ├── mind_map_node_test.dart
│   └── source_link_test.dart
├── storage/
│   └── mind_map_repository_test.dart
├── canvas/
│   ├── mind_map_canvas_test.dart
│   └── node_widget_test.dart
└── controller/
    └── mind_map_controller_test.dart
```

---

## 三、领域模型

### 3.1 实体关系总览

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

### 3.2 `MindMap`（思维导图）

**文件**: `lib/src/mindmap/domain/mind_map.dart`

```dart
import 'package:starmind/src/mindmap/domain/layout_mode.dart';

/// 思维导图实体。
/// 一个思维导图是画布上的节点和边的容器，与 PDF Document 并列存储于文件夹中。
class MindMap {
  final String id;
  final String title;
  final String? folderId;
  final String? rootNodeId;
  final LayoutMode layoutMode;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isTrashed;

  const MindMap({
    required this.id,
    required this.title,
    this.folderId,
    this.rootNodeId,
    this.layoutMode = LayoutMode.freeform,
    required this.createdAt,
    required this.modifiedAt,
    this.isTrashed = false,
  });

  MindMap copyWith({
    String? title,
    String? folderId,
    String? rootNodeId,
    LayoutMode? layoutMode,
    DateTime? modifiedAt,
    bool? isTrashed,
  }) {
    return MindMap(
      id: id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      rootNodeId: rootNodeId ?? this.rootNodeId,
      layoutMode: layoutMode ?? this.layoutMode,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isTrashed: isTrashed ?? this.isTrashed,
    );
  }

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      folderId.hashCode ^
      rootNodeId.hashCode ^
      layoutMode.hashCode ^
      createdAt.hashCode ^
      modifiedAt.hashCode ^
      isTrashed.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindMap &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          folderId == other.folderId &&
          rootNodeId == other.rootNodeId &&
          layoutMode == other.layoutMode &&
          createdAt == other.createdAt &&
          modifiedAt == other.modifiedAt &&
          isTrashed == other.isTrashed;
}
```

### 3.3 `MindMapNode`（节点）

**文件**: `lib/src/mindmap/domain/mind_map_node.dart`

```dart
import 'dart:convert';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';

/// 思维导图节点。
/// 每个节点有且仅有一个父节点，但可以有多个子节点和多条自由链接。
class MindMapNode {
  final String id;
  final String mindMapId;
  final String? parentId;
  final int sortOrder;
  final double positionX;
  final double positionY;
  final double width;
  final double height;
  final String colorHex;
  final bool isCollapsed;
  final NodeContent content;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const MindMapNode({
    required this.id,
    required this.mindMapId,
    this.parentId,
    this.sortOrder = 0,
    this.positionX = 0,
    this.positionY = 0,
    this.width = 160,
    this.height = 80,
    this.colorHex = '#FFFFFF',
    this.isCollapsed = false,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// 从数据库 JSON 创建
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      mindMapId: json['mind_map_id'] as String,
      parentId: json['parent_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      positionX: (json['position_x'] as num?)?.toDouble() ?? 0,
      positionY: (json['position_y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 160,
      height: (json['height'] as num?)?.toDouble() ?? 80,
      colorHex: json['color_hex'] as String? ?? '#FFFFFF',
      isCollapsed: json['is_collapsed'] as bool? ?? false,
      content: json['content_json'] != null
          ? NodeContent.fromJson(jsonDecode(json['content_json']) as Map<String, dynamic>)
          : const NodeContent(),
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mind_map_id': mindMapId,
        'parent_id': parentId,
        'sort_order': sortOrder,
        'position_x': positionX,
        'position_y': positionY,
        'width': width,
        'height': height,
        'color_hex': colorHex,
        'is_collapsed': isCollapsed,
        'content_json': jsonEncode(content.toJson()),
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
      };
}

/// 节点内容
class NodeContent {
  final String? text;
  final List<String> imageRefs;
  final List<InkStroke> inkStrokes;
  final SourceLink? sourceLink;

  const NodeContent({
    this.text,
    this.imageRefs = const [],
    this.inkStrokes = const [],
    this.sourceLink,
  });

  factory NodeContent.fromJson(Map<String, dynamic> json) {
    return NodeContent(
      text: json['text'] as String?,
      imageRefs: (json['image_refs'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      inkStrokes: (json['ink_strokes'] as List?)
              ?.map((s) => InkStroke.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          const [],
      sourceLink: json['source_link'] != null
          ? SourceLink.fromJson(
              Map<String, dynamic>.from(json['source_link']))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (imageRefs.isNotEmpty) 'image_refs': imageRefs,
        if (inkStrokes.isNotEmpty)
          'ink_strokes': inkStrokes.map((s) => s.toJson()).toList(),
        if (sourceLink != null) 'source_link': sourceLink!.toJson(),
      };
}
```

### 3.4 `SourceLink`（来源链接）

**文件**: `lib/src/mindmap/domain/source_link.dart`

```dart
/// 节点与 PDF 之间的桥梁。
/// 当用户从 PDF 摘录内容创建节点时，自动生成。
class SourceLink {
  final String id;
  final String nodeId;
  final String documentId;
  final String documentTitle;
  final int pageIndex;
  final int? startCharIndex;
  final int? endCharIndex;
  final String? selectedText;
  final String? annotationId;
  final DateTime createdAt;

  const SourceLink({
    required this.id,
    required this.nodeId,
    required this.documentId,
    required this.documentTitle,
    required this.pageIndex,
    this.startCharIndex,
    this.endCharIndex,
    this.selectedText,
    this.annotationId,
    required this.createdAt,
  });

  factory SourceLink.fromJson(Map<String, dynamic> json) {
    return SourceLink(
      id: json['id'] as String,
      nodeId: json['node_id'] as String,
      documentId: json['document_id'] as String,
      documentTitle: json['document_title'] as String,
      pageIndex: json['page_index'] as int,
      startCharIndex: json['start_char_index'] as int?,
      endCharIndex: json['end_char_index'] as int?,
      selectedText: json['selected_text'] as String?,
      annotationId: json['annotation_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'node_id': nodeId,
        'document_id': documentId,
        'document_title': documentTitle,
        'page_index': pageIndex,
        'start_char_index': startCharIndex,
        'end_char_index': endCharIndex,
        'selected_text': selectedText,
        'annotation_id': annotationId,
        'created_at': createdAt.toIso8601String(),
      };
}
```

### 3.5 `MindMapEdge`（边/连接线）

**文件**: `lib/src/mindmap/domain/mind_map_edge.dart`

```dart
import 'package:starmind/src/mindmap/domain/edge_type.dart';

/// 节点之间的连接关系。
/// 注意：层级边 (hierarchical) 由 MindMapNode.parentId 隐式定义，不存储在此表中。
/// 只有 free 类型的边需要存入数据库。
class MindMapEdge {
  final String id;
  final String mindMapId;
  final String sourceNodeId;
  final String targetNodeId;
  final EdgeType edgeType;
  final String? label;
  final String? colorHex;
  final DateTime createdAt;

  const MindMapEdge({
    required this.id,
    required this.mindMapId,
    required this.sourceNodeId,
    required this.targetNodeId,
    this.edgeType = EdgeType.free,
    this.label,
    this.colorHex,
    required this.createdAt,
  });

  factory MindMapEdge.fromJson(Map<String, dynamic> json) {
    return MindMapEdge(
      id: json['id'] as String,
      mindMapId: json['mind_map_id'] as String,
      sourceNodeId: json['source_node_id'] as String,
      targetNodeId: json['target_node_id'] as String,
      edgeType: EdgeType.values.firstWhere(
        (e) => e.name == json['edge_type'],
        orElse: () => EdgeType.free,
      ),
      label: json['label'] as String?,
      colorHex: json['color_hex'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mind_map_id': mindMapId,
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'edge_type': edgeType.name,
        'label': label,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };
}
```

### 3.6 枚举类型

**文件**: `lib/src/mindmap/domain/layout_mode.dart`

```dart
/// 画布布局模式
enum LayoutMode {
  tree,       // 自动布局：Walker 算法排列节点
  freeform,   // 自由布局：用户手动拖拽定位
}
```

**文件**: `lib/src/mindmap/domain/edge_type.dart`

```dart
/// 边类型
enum EdgeType {
  hierarchical,  // 父子层级边（由 parentId 隐式定义）
  free,          // 跨层级自由链接（用户手动创建）
}
```

---

## 四、存储层设计

### 4.1 SQLite 表结构

#### `mind_maps` 表

```sql
CREATE TABLE mind_maps (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  folder_id TEXT,
  root_node_id TEXT,
  layout_mode TEXT NOT NULL DEFAULT 'freeform',
  is_trashed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);

CREATE INDEX idx_mind_maps_folder ON mind_maps(folder_id);
CREATE INDEX idx_mind_maps_trashed ON mind_maps(is_trashed);
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

CREATE INDEX idx_nodes_mind_map ON mind_map_nodes(mind_map_id);
CREATE INDEX idx_nodes_parent ON mind_map_nodes(parent_id);
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

CREATE INDEX idx_source_links_node ON source_links(node_id);
CREATE INDEX idx_source_links_document ON source_links(document_id);
```

#### `mind_map_edges` 表

```sql
-- 注意：此表仅存储 free 类型的边
-- hierarchical 边由 mind_map_nodes.parent_id 隐式定义
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

CREATE INDEX idx_edges_mind_map ON mind_map_edges(mind_map_id);
```

### 4.2 数据库迁移

**文件**: `rust/src/storage/migrations/v2_mindmap.sql`

```sql
-- Migration: Add MindMap tables
-- Version: 2
-- Date: 2026-05-30

-- 思维导图表
CREATE TABLE IF NOT EXISTS mind_maps (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  folder_id TEXT,
  root_node_id TEXT,
  layout_mode TEXT NOT NULL DEFAULT 'freeform',
  is_trashed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);

-- ... (其他表同上)

-- 更新 schema_version
INSERT OR REPLACE INTO schema_version (version) VALUES (2);
```

### 4.3 `StorageRepository` 扩展

**文件**: `lib/src/mindmap/storage/mind_map_repository.dart`

```dart
import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';

/// MindMap 存储操作接口。
/// 实现类：MindMapFfiRepository（生产）和 MindMapInMemoryRepository（测试）。
abstract class MindMapRepository {
  // ── MindMap CRUD ─────────────────────────────────────────

  /// 创建新思维导图，返回生成的 ID
  Future<String> createMindMap({
    required String title,
    String? folderId,
    LayoutMode layoutMode = LayoutMode.freeform,
  });

  /// 获取单个思维导图
  Future<MindMap?> getMindMap(String id);

  /// 获取思维导图列表
  Future<List<MindMap>> getMindMaps({
    String? folderId,
    String? tagId,
    String? searchQuery,
    String sortBy = 'recent',
    bool includeTrashed = false,
  });

  /// 重命名思维导图
  Future<void> renameMindMap(String id, String newTitle);

  /// 移动思维导图到其他文件夹
  Future<void> moveMindMap(String id, String? newFolderId);

  /// 删除思维导图（移入回收站）
  Future<void> trashMindMap(String id);

  /// 永久删除思维导图
  Future<void> deleteMindMap(String id);

  // ── MindMapNode CRUD ─────────────────────────────────────

  /// 创建节点
  Future<String> createNode(MindMapNode node);

  /// 更新节点
  Future<void> updateNode(MindMapNode node);

  /// 删除节点
  Future<void> deleteNode(String id);

  /// 移动节点（改变父节点和排序）
  Future<void> moveNode(String nodeId, String? newParentId, int sortOrder);

  /// 获取思维导图的所有节点
  Future<List<MindMapNode>> getNodes(String mindMapId);

  // ── MindMapEdge CRUD (free edges only) ──────────────────

  /// 创建自由链接
  Future<String> createEdge(MindMapEdge edge);

  /// 删除自由链接
  Future<void> deleteEdge(String id);

  /// 获取思维导图的所有自由链接
  Future<List<MindMapEdge>> getFreeEdges(String mindMapId);

  // ── SourceLink CRUD ─────────────────────────────────────

  /// 创建来源链接
  Future<String> createSourceLink(SourceLink link);

  /// 删除来源链接
  Future<void> deleteSourceLink(String id);

  /// 获取节点的来源链接
  Future<SourceLink?> getSourceLinkByNode(String nodeId);

  /// 获取文档的所有来源链接
  Future<List<SourceLink>> getSourceLinksByDocument(String documentId);
}
```

### 4.4 Rust FFI 接口定义

**文件**: `rust/src/api/storage.rs` (扩展)

```rust
// === MindMap FFI Functions ===

/// Create a new mind map and return its ID
pub fn create_mind_map(
    title: String,
    folder_id: Option<String>,
    layout_mode: String,
) -> Result<String, String>;

/// Get a mind map by ID
pub fn get_mind_map(id: String) -> Result<Option<MindMapRecord>, String>;

/// Get mind maps list with optional filters
pub fn get_mind_maps(
    folder_id: Option<String>,
    tag_id: Option<String>,
    search_query: Option<String>,
    sort_by: String,
    include_trashed: bool,
) -> Result<Vec<MindMapRecord>, String>;

/// Rename a mind map
pub fn rename_mind_map(id: String, new_title: String) -> Result<(), String>;

/// Move mind map to another folder
pub fn move_mind_map(id: String, new_folder_id: Option<String>) -> Result<(), String>;

/// Trash a mind map (soft delete)
pub fn trash_mind_map(id: String) -> Result<(), String>;

/// Permanently delete a mind map
pub fn delete_mind_map(id: String) -> Result<(), String>;

// === MindMapNode FFI Functions ===

/// Create a mind map node
pub fn create_mind_map_node(
    mind_map_id: String,
    parent_id: Option<String>,
    sort_order: i32,
    position_x: f64,
    position_y: f64,
    width: f64,
    height: f64,
    color_hex: String,
    content_json: Option<String>,
) -> Result<String, String>;

/// Update a mind map node
pub fn update_mind_map_node(
    id: String,
    position_x: Option<f64>,
    position_y: Option<f64>,
    width: Option<f64>,
    height: Option<f64>,
    color_hex: Option<String>,
    is_collapsed: Option<bool>,
    content_json: Option<String>,
) -> Result<(), String>;

/// Delete a mind map node
pub fn delete_mind_map_node(id: String) -> Result<(), String>;

/// Move a node to a new parent
pub fn move_mind_map_node(
    node_id: String,
    new_parent_id: Option<String>,
    sort_order: i32,
) -> Result<(), String>;

/// Get all nodes for a mind map
pub fn get_mind_map_nodes(mind_map_id: String) -> Result<Vec<MindMapNodeRecord>, String>;

// === SourceLink FFI Functions ===

/// Create a source link
pub fn create_source_link(
    node_id: String,
    document_id: String,
    document_title: String,
    page_index: i32,
    start_char_index: Option<i32>,
    end_char_index: Option<i32>,
    selected_text: Option<String>,
    annotation_id: Option<String>,
) -> Result<String, String>;

/// Get source link by node ID
pub fn get_source_link_by_node(node_id: String) -> Result<Option<SourceLinkRecord>, String>;

/// Get source links by document ID
pub fn get_source_links_by_document(document_id: String) -> Result<Vec<SourceLinkRecord>, String>;

// === MindMapEdge FFI Functions ===

/// Create a free edge
pub fn create_mind_map_edge(
    mind_map_id: String,
    source_node_id: String,
    target_node_id: String,
    label: Option<String>,
    color_hex: Option<String>,
) -> Result<String, String>;

/// Delete a free edge
pub fn delete_mind_map_edge(id: String) -> Result<(), String>;

/// Get free edges for a mind map
pub fn get_mind_map_free_edges(mind_map_id: String) -> Result<Vec<MindMapEdgeRecord>, String>;
```

---

## 五、实现阶段规划（细化版）

### Phase M1a: 领域模型 + 存储层

**目标**: 建立数据基础，支持 MindMap 的 CRUD 操作

**范围**:
- 领域模型类定义
- SQLite 表创建（迁移脚本）
- Rust FFI 接口实现
- Dart 存储仓库实现
- 单元测试

**测试策略**:
| 测试类型 | 文件 | 覆盖内容 |
|---------|------|---------|
| 单元测试 | `test/mindmap/domain/mind_map_test.dart` | MindMap 实体序列化 |
| 单元测试 | `test/mindmap/domain/mind_map_node_test.dart` | MindMapNode 序列化、NodeContent |
| 单元测试 | `test/mindmap/domain/source_link_test.dart` | SourceLink 序列化 |
| 集成测试 | `test/mindmap/storage/mind_map_repository_test.dart` | CRUD 操作、边界条件 |

**任务分解**:
1. **T1a-1**: 创建目录结构和枚举文件
2. **T1a-2**: 实现 `MindMap` 领域模型
3. **T1a-3**: 实现 `MindMapNode` 和 `NodeContent`
4. **T1a-4**: 实现 `SourceLink` 领域模型
5. **T1a-5**: 实现 `MindMapEdge` 领域模型
6. **T1a-6**: 编写 SQLite 迁移脚本
7. **T1a-7**: 实现 Rust 存储操作
8. **T1a-8**: 实现 Dart FFI 适配器
9. **T1a-9**: 实现 `MindMapRepository` 接口
10. **T1a-10**: 编写单元测试
11. **T1a-11**: 编写集成测试

---

### Phase M1b: Tab 系统 + 主页集成

**目标**: 在现有 Tab 系统中支持思维导图，主页可展示和筛选

**范围**:
- `TabType` 枚举扩展
- `TabItem` 新增字段
- 侧边栏展示思维导图
- 主页筛选栏扩展
- 思维导图卡片渲染

**修改文件**:
| 文件 | 修改内容 |
|------|---------|
| `lib/src/home/tab_layout.dart` | `TabType` 新增 `mindmap`，`TabItem` 新增 `mindMapId` |
| `lib/src/home/tab_navigation_controller.dart` | `openMindMap()` 方法 |
| `lib/src/home/metadata_controller.dart` | 加载思维导图列表 |
| `lib/src/home/document_query_controller.dart` | 支持思维导图筛选 |
| `lib/src/home/workspace_controller.dart` | 协调 MindMap 操作 |

**测试策略**:
| 测试类型 | 文件 | 覆盖内容 |
|---------|------|---------|
| 单元测试 | `test/domain/tab_navigation_controller_test.dart` | MindMap Tab 操作 |
| 单元测试 | `test/domain/workspace_controller_test.dart` | MindMap CRUD 协调 |
| Widget 测试 | `test/home/home_grid_test.dart` | 思维导图卡片渲染 |

**任务分解**:
1. **T1b-1**: 扩展 `TabType` 枚举
2. **T1b-2**: 扩展 `TabItem` 类
3. **T1b-3**: 实现 `openMindMap()` 方法
4. **T1b-4**: 扩展 `MetadataController` 加载思维导图
5. **T1b-5**: 扩展 `DocumentQueryController` 支持筛选
6. **T1b-6**: 更新侧边栏展示逻辑
7. **T1b-7**: 更新主页筛选栏
8. **T1b-8**: 实现思维导图卡片组件
9. **T1b-9**: 编写单元测试
10. **T1b-10**: 编写 Widget 测试

---

### Phase M1c: 画布基础 + 节点渲染

**目标**: 建立可缩放平移的画布，支持节点显示和基本交互

**范围**:
- `MindMapCanvas` 主组件（复用 `InteractiveCanvasViewer`）
- `MindMapNodeWidget` 节点卡片
- `EdgeRenderer` 连线绘制
- 基本手势（缩放、平移）
- 节点选中高亮

**复用说明**:
| 组件 | 复用来源 | 复用方式 |
|------|---------|---------|
| `InteractiveCanvasViewer` | `lib/src/pdf/widgets/interactive_canvas_viewer.dart` | 直接引用 |
| `InkStroke` | `lib/src/domain/ink_stroke.dart` | 直接引用 |
| `TransformationController` | Flutter SDK | 直接引用 |

**测试策略**:
| 测试类型 | 文件 | 覆盖内容 |
|---------|------|---------|
| Widget 测试 | `test/mindmap/canvas/mind_map_canvas_test.dart` | 画布渲染、缩放平移 |
| Widget 测试 | `test/mindmap/canvas/node_widget_test.dart` | 节点渲染、选中状态 |
| Widget 测试 | `test/mindmap/canvas/edge_renderer_test.dart` | 连线绘制 |

**任务分解**:
1. **T1c-1**: 创建 `MindMapCanvas` 基础结构
2. **T1c-2**: 集成 `InteractiveCanvasViewer`
3. **T1c-3**: 实现 `MindMapNodeWidget` 基础渲染
4. **T1c-4**: 实现节点选中状态
5. **T1c-5**: 实现 `EdgeRenderer` 层级边绘制
6. **T1c-6**: 实现 `EdgeRenderer` 自由边绘制
7. **T1c-7**: 实现画布缩放平移手势
8. **T1c-8**: 编写 Widget 测试

---

### Phase M1d: 拖拽交互 + 连线创建

**目标**: 支持节点拖拽移动、手动创建自由链接

**范围**:
- 节点拖拽定位（freeform 模式）
- 手势冲突处理（拖拽节点 vs 平移画布）
- 从节点拖拽创建自由链接
- 删除节点和连线

**手势处理策略**:
```dart
// 在 MindMapCanvas 中通过 hitTest 区分
bool _isPointOnNode(Offset localPosition) {
  // 遍历节点，检查 localPosition 是否在节点 Rect 内
  for (final node in _visibleNodes) {
    final nodeRect = Rect.fromLTWH(
      node.positionX, 
      node.positionY, 
      node.width, 
      node.height
    );
    if (nodeRect.contains(localPosition)) {
      return true;
    }
  }
  return false;
}
```

**测试策略**:
| 测试类型 | 文件 | 覆盖内容 |
|---------|------|---------|
| Widget 测试 | `test/mindmap/canvas/node_drag_test.dart` | 节点拖拽、位置更新 |
| Widget 测试 | `test/mindmap/canvas/edge_creation_test.dart` | 连线创建、删除 |
| 集成测试 | `test/mindmap/canvas/gesture_conflict_test.dart` | 手势冲突处理 |

**任务分解**:
1. **T1d-1**: 实现节点 hitTest 检测
2. **T1d-2**: 实现节点拖拽手势
3. **T1d-3**: 实现拖拽位置持久化
4. **T1d-4**: 实现手势冲突处理
5. **T1d-5**: 实现连线创建交互
6. **T1d-6**: 实现连线删除交互
7. **T1d-7**: 实现节点删除（含级联删除子节点）
8. **T1d-8**: 编写测试

---

### Phase M2: 摘录桥接

**目标**: 从 PDF 选中文字后一键摘录，生成节点并建立双向链接

**范围**:
- PDF 选中工具栏新增"摘录到思维导图"按钮
- 摘录确认面板
- `SourceLink` 创建
- 节点卡片显示来源信息
- 跳转回 PDF 原文

**任务分解**:
1. **T2-1**: 扩展 PDF 选中工具栏
2. **T2-2**: 实现摘录确认面板
3. **T2-3**: 实现 `excerptToMindMap()` 方法
4. **T2-4**: 实现节点来源栏显示
5. **T2-5**: 实现 `jumpToPdfSource()` 方法
6. **T2-6**: 实现 PDF 摘录侧栏扩展
7. **T2-7**: 编写测试

---

### Phase M3: 分屏配对

**目标**: 支持 PDF + 思维导图分屏并排显示

**范围**:
- 分屏选择面板
- `SplitPairing` 运行时配对管理
- 分屏状态下摘录自动落点

**任务分解**:
1. **T3-1**: 实现分屏选择面板
2. **T3-2**: 实现 `SplitPairing` 状态管理
3. **T3-3**: 更新摘录流程支持自动配对
4. **T3-4**: 编写测试

---

### Phase M4: Walker 自动布局 + 层级树

**目标**: 支持 Tree 自动布局模式

**范围**:
- `LayoutEngine` 接口
- `WalkerLayoutEngine` 实现
- LayoutMode 切换
- 树模式下拖拽改变父子关系

**任务分解**:
1. **T4-1**: 定义 `LayoutEngine` 接口
2. **T4-2**: 实现 Walker 布局算法
3. **T4-3**: 实现左右分叉策略
4. **T4-4**: 实现 LayoutMode 切换
5. **T4-5**: 实现树模式拖拽改层级
6. **T4-6**: 编写测试

---

### Phase M5: 富文本节点

**目标**: 节点卡片支持图片、手写笔迹

**任务分解**:
1. **T5-1**: 实现图片插入
2. **T5-2**: 实现手写笔迹嵌入
3. **T5-3**: 实现节点自适应高度
4. **T5-4**: 编写测试

---

### Phase M6: 拖拽落点摘录

**目标**: 从 PDF 直接拖拽选区到画布

**任务分解**:
1. **T6-1**: 实现跨面板拖拽手势
2. **T6-2**: 实现拖拽视觉反馈
3. **T6-3**: 实现松手自动生成节点
4. **T6-4**: 编写测试

---

## 六、技术风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|----------|
| Walker 算法实现复杂度 | 节点布局效果不理想 | 参考 graphview 的 `BuchheimWalkerAlgorithm` 源码，实现精简版；初期可用简单的水平/垂直排列作为 fallback |
| 节点拖拽与画布平移手势冲突 | 交互混乱 | 通过 hitTest 区分：触点在节点上 → 拖拽节点；触点在空白处 → 平移画布 |
| 大量节点时画布性能 | 卡顿 | 虚拟化渲染（只渲染视口内可见节点，复用 PDF 页面虚拟化的思路） |
| `main.dart` 持续膨胀 | 可维护性下降 | MindMap 所有组件放到 `lib/src/mindmap/` 目录下，Phase M1 同步重构 main.dart |
| SourceLink 与 Annotation 双向关联 | 数据一致性 | 使用事务写入；删除 Annotation 时级联更新 SourceLink |

---

## 七、与现有代码的集成点

### 7.1 需要修改的现有文件

| 文件 | 修改内容 | Phase |
|------|---------|-------|
| `lib/src/home/tab_layout.dart` | `TabType` 新增 `mindmap` | M1b |
| `lib/src/domain/storage_repository.dart` | 新增 MindMap 相关方法（或拆分为独立仓库） | M1a |
| `lib/src/domain/ffi_storage_repository.dart` | 实现 MindMap FFI 调用 | M1a |
| `lib/src/home/tab_navigation_controller.dart` | `openMindMap()` 方法 | M1b |
| `lib/src/home/workspace_controller.dart` | MindMap 协调方法 | M1b |
| `rust/src/api/storage.rs` | MindMap FFI 函数 | M1a |
| `rust/src/storage/mod.rs` | 引入 MindMap 模块 | M1a |

### 7.2 直接复用的现有代码

| 组件 | 文件路径 | 复用方式 |
|------|---------|---------|
| `InteractiveCanvasViewer` | `lib/src/pdf/widgets/interactive_canvas_viewer.dart` | 直接引用 |
| `InkStroke` | `lib/src/domain/ink_stroke.dart` | 直接引用 |
| `InkPoint` | `lib/src/domain/ink_stroke.dart` | 直接引用 |
| `Folder` | `lib/src/domain/folder.dart` | 通过 folderId 关联 |
| `Document` | `lib/src/domain/document.dart` | 通过 SourceLink 关联 |
| `Annotation` | `lib/src/domain/annotation.dart` | 可选关联 |

---

## 八、测试策略总结

### 8.1 测试金字塔

```
              ┌─────────────────────┐
              │    E2E 测试          │  Phase M2+（摘录流程）
              │  (集成测试)          │
              ├─────────────────────┤
              │    Widget 测试       │  画布、节点、手势
              │  (组件行为)          │
              ├─────────────────────┤
              │    单元测试          │  领域模型、存储层
              │  (纯逻辑)            │
              └─────────────────────┘
```

### 8.2 测试覆盖率目标

| 层级 | 目标覆盖率 | 工具 |
|------|-----------|------|
| 领域模型 | 100% | `flutter test` |
| 存储层 | 90% | `flutter test` + 内存数据库 |
| Widget | 80% | `flutter test` + `WidgetTester` |
| 集成 | 关键流程 100% | `integration_test` |

### 8.3 测试数据管理

- 使用 `MindMapInMemoryRepository` 进行单元测试
- 集成测试使用临时 SQLite 数据库
- Widget 测试使用 Mock 数据

---

## 九、附录：现有代码结构参考

### 9.1 项目目录结构

```
lib/src/
├── domain/           # 领域模型
│   ├── document.dart
│   ├── folder.dart
│   ├── tag.dart
│   ├── annotation.dart
│   ├── ink_stroke.dart
│   ├── storage_repository.dart
│   ├── ffi_storage_repository.dart
│   └── in_memory_storage_repository.dart
├── home/             # 主页和导航
│   ├── tab_layout.dart
│   ├── tab_navigation_controller.dart
│   ├── workspace_controller.dart
│   ├── metadata_controller.dart
│   ├── document_query_controller.dart
│   └── preferences_controller.dart
├── pdf/              # PDF 相关
│   ├── widgets/
│   │   ├── interactive_canvas_viewer.dart
│   │   ├── pdf_viewport_widget.dart
│   │   └── ...
│   └── ...
└── rust/             # FFI 生成代码
    ├── api/
    └── storage/

rust/src/
├── api/              # FFI 接口
│   ├── storage.rs
│   └── ...
└── storage/          # 存储实现
    ├── mod.rs
    ├── db.rs
    ├── documents.rs
    └── ...
```

### 9.2 现有 FFI 模式参考

```dart
// lib/src/rust/storage/documents.dart (自动生成)
class DocumentInfo {
  final String id;
  final String title;
  final String filePath;
  final String? folderId;
  final List<String> tagIds;
  final PlatformInt64 createdAt;
  // ...
}
```

```dart
// lib/src/domain/ffi_storage_repository.dart
@override
Future<List<Document>> getDocuments({...}) async {
  final ffiDocs = await ffi.getDocuments(...);
  return ffiDocs.map(_convertDocumentInfo).toList();
}

Document _convertDocumentInfo(ffi_doc.DocumentInfo doc) {
  return Document(
    id: doc.id,
    title: doc.title,
    // ...
  );
}
```

---

**文档版本历史**:
- v1.0 (2026-05-30): 初始版本
- v1.1 (2026-05-31): 优化版，补充文件结构、测试策略、M1细粒度拆分、Rust FFI接口定义
