# MindMap 思维导图功能设计文档 (v1.2 - MarginNote 风格)

**日期**: 2026-05-31
**版本**: 1.2 (基于 MarginNote 数据结构逆向分析)
**状态**: 待实现

---

## 一、产品概述

### 1.1 核心目标

将 Starmind 实现为类似 MarginNote 的知识管理工具：
- **PDF 阅读 + 摘录笔记 + 思维导图** 三合一
- 一个笔记本（Topic）关联多个 PDF 文档
- 摘录文字自动生成导图节点，支持双向跳转

### 1.2 与 MarginNote 的对比

| 功能 | MarginNote | Starmind 目标 |
|------|-----------|--------------|
| 笔记本模式 | ✅ 单文件 `.marginnotes` | ✅ Topic 实体 |
| 多 PDF 关联 | ✅ `ZBOOKLIST` | ✅ Topic.pdfIds |
| 导图节点 | ✅ `ZBOOKNOTE` | ✅ Note 实体 |
| 管道分隔子节点 | ✅ `ZMINDLINKS` | ✅ `childIds` |
| PDF 摘录 | ✅ 高亮+坐标 | ✅ 高亮+JSON坐标 |
| 媒体存储 | ✅ `ZMEDIA` BLOB | ✅ Media 实体 |
| OCR | ✅ 图片识别 | ⏳ 后续阶段 |
| 云同步 | ✅ USN机制 | ⏳ 后续阶段 |

---

## 二、领域模型 (基于 MarginNote ZBOOKNOTE)

### 2.1 实体关系总览

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│   Document   │◄──────│    Note          │──────►│   Topic      │
│   (PDF)      │       │   (导图节点)      │       │  (笔记本)     │
│              │       │                  │       │              │
│  md5: String │       │  pdfId: String   │       │  pdfIds: []  │
└──────────────┘       │  childIds: "id1|id2"   │  rootNoteIds: []
                       │  parentId: String│       └──────────────┘
                       └──────────────────┘              │
                                                         │
                       ┌──────────────────┐              │
                       │    Media         │◄─────────────┘
                       │   (图片/截图)     │       (可选关联)
                       │                  │
                       │  md5: String     │
                       │  data: BLOB      │
                       └──────────────────┘
```

### 2.2 `Topic`（笔记本）

**设计依据**: MarginNote `ZTOPIC` 表

一个 Topic 是一个思维导图笔记本，可以关联多个 PDF 文档。

```dart
// lib/src/mindmap/domain/topic.dart

/// 思维导图笔记本（对应 MarginNote 的 ZTOPIC）。
/// 一个笔记本可以关联多个 PDF 文档，包含所有导图节点。
class Topic {
  final String id;                    // UUID
  final String title;                 // 笔记本标题
  final String? author;               // 作者
  final List<String> pdfIds;          // 关联的 PDF 文档 MD5 列表
  final List<String> rootNoteIds;     // 根节点 ID 列表（管道分隔存储在数据库）
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastVisitAt;
  final bool isTrashed;

  const Topic({
    required this.id,
    required this.title,
    this.author,
    this.pdfIds = const [],
    this.rootNoteIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitAt,
    this.isTrashed = false,
  });

  /// 从数据库 Map 创建（支持管道分隔字段）。
  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      pdfIds: _parsePipedList(map['pdf_ids'] as String?),
      rootNoteIds: _parsePipedList(map['root_note_ids'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastVisitAt: map['last_visit_at'] != null
          ? DateTime.parse(map['last_visit_at'] as String)
          : null,
      isTrashed: (map['is_trashed'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'author': author,
    'pdf_ids': _joinPipedList(pdfIds),
    'root_note_ids': _joinPipedList(rootNoteIds),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_visit_at': lastVisitAt?.toIso8601String(),
    'is_trashed': isTrashed ? 1 : 0,
  };

  /// 解析管道分隔列表 "id1|id2|id3" → ["id1", "id2", "id3"]
  static List<String> _parsePipedList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 合并列表为管道分隔字符串 ["id1", "id2"] → "id1|id2"
  static String _joinPipedList(List<String> list) {
    return list.join('|');
  }
}
```

### 2.3 `Note`（导图节点）

**设计依据**: MarginNote `ZBOOKNOTE` 表

这是核心实体，存储导图节点、摘录内容、用户笔记。

```dart
// lib/src/mindmap/domain/note.dart

import 'dart:convert';

/// 导图节点（对应 MarginNote 的 ZBOOKNOTE）。
/// 核心设计：父子关系通过 childIds（管道分隔）存储在父节点中。
class Note {
  // ── 核心标识 ──
  final String id;                    // UUID
  final String title;                 // 节点标题（显示用）

  // ── 内容 ──
  final String? highlightText;        // PDF 摘录原文
  final String? noteText;             // 用户笔记/评论
  final NoteType type;                // 类型: note(256) / other

  // ── 关联 ──
  final String topicId;               // 所属笔记本
  final String? pdfId;                // 来源 PDF MD5（可为空，手动创建节点）
  final String? pdfTitle;             // PDF 标题（冗余存储，读优化）

  // ── 导图结构（核心！）──
  final String? childIdsRaw;          // 子节点ID列表（管道分隔）"uuid1|uuid2|uuid3"
  final String? parentId;             // 主父节点ID（优化查询，MarginNote 未显式存储）

  // ── PDF 位置 ──
  final int? startPage;               // 起始页码
  final int? endPage;                 // 结束页码（支持跨页摘录）
  final String? positionJson;         // 精确坐标（JSON格式）

  // ── 样式 ──
  final HighlightStyle highlightStyle;// 高亮样式

  // ── 媒体 ──
  final List<String> mediaIds;        // 关联媒体 MD5 列表

  // ── 元数据 ──
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? highlightDate;      // 摘录时间（区别于创建时间）
  final bool isCollapsed;             // 导图折叠状态
  final int zIndex;                   // Z排序索引（子节点顺序）

  const Note({
    required this.id,
    required this.title,
    this.highlightText,
    this.noteText,
    this.type = NoteType.note,
    required this.topicId,
    this.pdfId,
    this.pdfTitle,
    this.childIdsRaw,
    this.parentId,
    this.startPage,
    this.endPage,
    this.positionJson,
    this.highlightStyle = HighlightStyle.yellow,
    this.mediaIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.highlightDate,
    this.isCollapsed = false,
    this.zIndex = 0,
  });

  /// 解析子节点 ID 列表。
  List<String> get childIds {
    if (childIdsRaw == null || childIdsRaw!.isEmpty) return const [];
    return childIdsRaw!.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 从数据库 Map 创建。
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      highlightText: map['highlight_text'] as String?,
      noteText: map['note_text'] as String?,
      type: NoteType.fromCode(map['note_type'] as int? ?? 256),
      topicId: map['topic_id'] as String,
      pdfId: map['pdf_id'] as String?,
      pdfTitle: map['pdf_title'] as String?,
      childIdsRaw: map['child_ids'] as String?,
      parentId: map['parent_id'] as String?,
      startPage: map['start_page'] as int?,
      endPage: map['end_page'] as int?,
      positionJson: map['position_json'] as String?,
      highlightStyle: HighlightStyle.fromName(map['highlight_style'] as String?),
      mediaIds: Topic._parsePipedList(map['media_ids'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      highlightDate: map['highlight_date'] != null
          ? DateTime.parse(map['highlight_date'] as String)
          : null,
      isCollapsed: (map['is_collapsed'] as int?) == 1,
      zIndex: map['z_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'highlight_text': highlightText,
    'note_text': noteText,
    'note_type': type.code,
    'topic_id': topicId,
    'pdf_id': pdfId,
    'pdf_title': pdfTitle,
    'child_ids': childIdsRaw,
    'parent_id': parentId,
    'start_page': startPage,
    'end_page': endPage,
    'position_json': positionJson,
    'highlight_style': highlightStyle.name,
    'media_ids': Topic._joinPipedList(mediaIds),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'highlight_date': highlightDate?.toIso8601String(),
    'is_collapsed': isCollapsed ? 1 : 0,
    'z_index': zIndex,
  };

  /// 添加子节点。
  Note addChild(String childId) {
    final currentChildren = childIds;
    if (currentChildren.contains(childId)) return this;
    
    final newChildIdsRaw = Topic._joinPipedList([...currentChildren, childId]);
    return copyWith(
      childIdsRaw: newChildIdsRaw,
      updatedAt: DateTime.now(),
    );
  }

  /// 移除子节点。
  Note removeChild(String childId) {
    final currentChildren = childIds;
    if (!currentChildren.contains(childId)) return this;
    
    final newChildIdsRaw = Topic._joinPipedList(
      currentChildren.where((id) => id != childId).toList()
    );
    return copyWith(
      childIdsRaw: newChildIdsRaw,
      updatedAt: DateTime.now(),
    );
  }

  Note copyWith({
    String? title,
    String? highlightText,
    String? noteText,
    String? childIdsRaw,
    String? parentId,
    int? startPage,
    int? endPage,
    String? positionJson,
    HighlightStyle? highlightStyle,
    List<String>? mediaIds,
    DateTime? updatedAt,
    bool? isCollapsed,
    int? zIndex,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      highlightText: highlightText ?? this.highlightText,
      noteText: noteText ?? this.noteText,
      type: type,
      topicId: topicId,
      pdfId: pdfId,
      pdfTitle: pdfTitle,
      childIdsRaw: childIdsRaw ?? this.childIdsRaw,
      parentId: parentId ?? this.parentId,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      positionJson: positionJson ?? this.positionJson,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      mediaIds: mediaIds ?? this.mediaIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      highlightDate: highlightDate,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

/// 节点类型。
enum NoteType {
  note(256),     // 笔记节点（最常见）
  other(4),      // 其他类型
}

extension NoteTypeExt on NoteType {
  int get code => switch (this) {
    NoteType.note => 256,
    NoteType.other => 4,
  };

  static NoteType fromCode(int code) => switch (code) {
    256 => NoteType.note,
    _ => NoteType.other,
  };
}

/// 高亮样式（对应 MarginNote 的 mbooks-annotation*）。
enum HighlightStyle {
  yellow('mbooks-annotation1'),
  yellowAlt('mbooks-annotation1c'),
  green('mbooks-annotation2'),
  blue('mbooks-annotation3'),
  purple('mbooks-annotation4'),
  red('mbooks-annotation5'),
  orange('mbooks-annotation6'),
  gray('mbooks-annotation12'),
}

extension HighlightStyleExt on HighlightStyle {
  String get name => switch (this) {
    HighlightStyle.yellow => 'mbooks-annotation1',
    HighlightStyle.yellowAlt => 'mbooks-annotation1c',
    HighlightStyle.green => 'mbooks-annotation2',
    HighlightStyle.blue => 'mbooks-annotation3',
    HighlightStyle.purple => 'mbooks-annotation4',
    HighlightStyle.red => 'mbooks-annotation5',
    HighlightStyle.orange => 'mbooks-annotation6',
    HighlightStyle.gray => 'mbooks-annotation12',
  };

  /// 显示颜色（用于渲染）。
  int get colorValue => switch (this) {
    HighlightStyle.yellow => 0xFFFFD700,
    HighlightStyle.yellowAlt => 0xFFFFEC8B,
    HighlightStyle.green => 0xFF51CF66,
    HighlightStyle.blue => 0xFF4A90D9,
    HighlightStyle.purple => 0xFF9775FA,
    HighlightStyle.red => 0xFFFF6B6B,
    HighlightStyle.orange => 0xFFFF9500,
    HighlightStyle.gray => 0xFF888888,
  };

  static HighlightStyle fromName(String? name) => switch (name ?? '') {
    'mbooks-annotation1' => HighlightStyle.yellow,
    'mbooks-annotation1c' => HighlightStyle.yellowAlt,
    'mbooks-annotation2' => HighlightStyle.green,
    'mbooks-annotation3' => HighlightStyle.blue,
    'mbooks-annotation4' => HighlightStyle.purple,
    'mbooks-annotation5' => HighlightStyle.red,
    'mbooks-annotation6' => HighlightStyle.orange,
    'mbooks-annotation12' => HighlightStyle.gray,
    _ => HighlightStyle.yellow,
  };
}
```

### 2.4 `Media`（媒体/图片）

**设计依据**: MarginNote `ZMEDIA` 表

```dart
// lib/src/mindmap/domain/media.dart

/// 媒体资源（对应 MarginNote 的 ZMEDIA）。
/// 存储摘录截图、用户上传图片等。
class Media {
  final String md5;                   // MD5 唯一标识
  final Uint8List? data;              // 图片数据（BLOB）
  final Uint8List? thumbnail;         // 缩略图数据
  final MediaType type;               // 媒体类型
  final DateTime createdAt;

  const Media({
    required this.md5,
    this.data,
    this.thumbnail,
    this.type = MediaType.image,
    required this.createdAt,
  });

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      md5: map['md5'] as String,
      data: map['data'] as Uint8List?,
      thumbnail: map['thumbnail'] as Uint8List?,
      type: MediaType.fromCode(map['media_type'] as int? ?? 0),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'md5': md5,
    'data': data,
    'thumbnail': thumbnail,
    'media_type': type.code,
    'created_at': createdAt.toIso8601String(),
  };
}

enum MediaType {
  image(0),
  screenshot(1),
  handwritten(2),
}

extension MediaTypeExt on MediaType {
  int get code => switch (this) {
    MediaType.image => 0,
    MediaType.screenshot => 1,
    MediaType.handwritten => 2,
  };

  static MediaType fromCode(int code) => switch (code) {
    0 => MediaType.image,
    1 => MediaType.screenshot,
    2 => MediaType.handwritten,
    _ => MediaType.image,
  };
}
```

### 2.5 `PdfPosition`（PDF 位置）

用于精确描述摘录在 PDF 中的位置。

```dart
// lib/src/mindmap/domain/pdf_position.dart

/// PDF 位置坐标（用于摘录跳转）。
class PdfPosition {
  final int startPage;
  final int endPage;
  final Rect? startRect;              // 起始区域（页面坐标）
  final Rect? endRect;                // 结束区域
  final int? startCharIndex;          // 起始字符索引（可选）
  final int? endCharIndex;            // 结束字符索引（可选）

  const PdfPosition({
    required this.startPage,
    this.endPage,
    this.startRect,
    this.endRect,
    this.startCharIndex,
    this.endCharIndex,
  });

  factory PdfPosition.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return PdfPosition(
      startPage: map['start_page'] as int,
      endPage: map['end_page'] as int?,
      startRect: map['start_rect'] != null
          ? Rect.fromJson(map['start_rect'] as Map<String, dynamic>)
          : null,
      endRect: map['end_rect'] != null
          ? Rect.fromJson(map['end_rect'] as Map<String, dynamic>)
          : null,
      startCharIndex: map['start_char_index'] as int?,
      endCharIndex: map['end_char_index'] as int?,
    );
  }

  String toJson() => jsonEncode({
    'start_page': startPage,
    'end_page': endPage,
    'start_rect': startRect?.toJson(),
    'end_rect': endRect?.toJson(),
    'start_char_index': startCharIndex,
    'end_char_index': endCharIndex,
  });
}

/// PDF 页面坐标区域。
class PdfRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const PdfRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory PdfRect.fromJson(Map<String, dynamic> map) {
    return PdfRect(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  Rect toRect() => Rect.fromLTWH(x, y, width, height);
}
```

---

## 三、存储层设计

### 3.1 SQLite 表结构

#### `topics` 表（笔记本）

```sql
CREATE TABLE topics (
  id TEXT PRIMARY KEY,                -- UUID
  title TEXT NOT NULL,                -- 笔记本标题
  author TEXT,                        -- 作者
  pdf_ids TEXT,                       -- 关联PDF MD5列表（管道分隔）
  root_note_ids TEXT,                 -- 根节点ID列表（管道分隔）
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_visit_at TEXT,
  is_trashed INTEGER DEFAULT 0
);

CREATE INDEX idx_topics_trashed ON topics(is_trashed);
CREATE INDEX idx_topics_updated ON topics(updated_at DESC);
```

#### `notes` 表（导图节点）

```sql
CREATE TABLE notes (
  -- 核心标识
  id TEXT PRIMARY KEY,                -- UUID
  title TEXT NOT NULL DEFAULT '',     -- 标题
  note_type INTEGER DEFAULT 256,      -- 类型: 256=笔记

  -- 内容
  highlight_text TEXT,                -- PDF摘录原文
  note_text TEXT,                     -- 用户笔记

  -- 关联
  topic_id TEXT NOT NULL,             -- 所属笔记本
  pdf_id TEXT,                        -- 来源PDF MD5
  pdf_title TEXT,                     -- PDF标题（冗余）

  -- 导图结构（核心！）
  child_ids TEXT,                     -- 子节点ID（管道分隔）"id1|id2|id3"
  parent_id TEXT,                     -- 主父节点ID

  -- PDF位置
  start_page INTEGER,
  end_page INTEGER,
  position_json TEXT,                 -- 精确坐标JSON

  -- 样式
  highlight_style TEXT DEFAULT 'mbooks-annotation1',

  -- 媒体
  media_ids TEXT,                     -- 媒体MD5列表（管道分隔）

  -- 元数据
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  highlight_date TEXT,
  is_collapsed INTEGER DEFAULT 0,
  z_index INTEGER DEFAULT 0,

  FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
);

CREATE INDEX idx_notes_topic ON notes(topic_id);
CREATE INDEX idx_notes_pdf ON notes(pdf_id);
CREATE INDEX idx_notes_parent ON notes(parent_id);
CREATE INDEX idx_notes_created ON notes(created_at DESC);
```

#### `media` 表（媒体）

```sql
CREATE TABLE media (
  md5 TEXT PRIMARY KEY,               -- MD5唯一标识
  data BLOB,                          -- 图片数据
  thumbnail BLOB,                     -- 缩略图
  media_type INTEGER DEFAULT 0,       -- 类型
  created_at TEXT NOT NULL
);
```

### 3.2 关键设计决策

| 决策 | 理由 |
|------|------|
| `child_ids` 管道分隔 | MarginNote 成功模式，单字段存储有序列表 |
| `parent_id` 显式存储 | 优化查询（MarginNote 未显式存储，需全表扫描） |
| `pdf_title` 冠余存储 | 读优化，避免 JOIN 查询 |
| `highlight_style` CSS 类名 | 兼容 MarginNote 导出格式 |
| `position_json` JSON 格式 | 灵活扩展，支持复杂坐标 |

---

## 四、与原有 Spec 的变更

### 4.1 实体变更

| 原实体 | 新实体 | 变化 |
|-------|-------|------|
| `MindMap` | `Topic` | 重命名，新增 `pdfIds` |
| `MindMapNode` | `Note` | 重命名，`childIdsRaw` 替代 `parentId` 主模式 |
| `MindMapEdge` | **删除** | 管道分隔模式不需要边表 |
| `SourceLink` | **合并到 Note** | `pdfId + highlightText + positionJson` |
| 新增 | `Media` | 图片/截图 BLOB 存储 |

### 4.2 关系变更

```
原设计: Document ←── SourceLink ──→ MindMapNode ←── MindMapEdge ──→ MindMapNode

新设计: Document ←── Note ──→ Topic
                │           │
                └─── Media ←─┘
```

---

## 五、实现阶段规划

### Phase M1a: 领域模型 + 存储层（MarginNote 风格）

**范围**:
- `Topic` 实体 + 管道分隔列表处理
- `Note` 实体 + `childIds` 管道分隔
- `Media` 实体
- `HighlightStyle` + `NoteType` 枚举
- SQLite 表创建
- Rust CRUD + FFI

### Phase M1b: Tab 系统 + Topic 列表

**范围**:
- Topic 作为 Tab 内容
- 主页 Topic 卡片展示
- Topic 创建/删除 UI

### Phase M1c: 导图画布 + 节点渲染

**范围**:
- Topic 画布组件
- Note 卡片组件
- 子节点加载（通过 `childIds` 查询）
- 连线绘制（基于 `childIds`）

### Phase M2: PDF 摘录

**范围**:
- PDF 选区 → 创建 Note
- `highlightText` + `positionJson` 存储
- 跳转回 PDF（读取 `positionJson`）

---

## 六、与现有 Starmind 代码的集成

### 6.1 Document 实体扩展

需要在 `Document` 中新增 `md5` 字段用于关联：

```dart
// lib/src/domain/document.dart 扩展

class Document {
  // ... existing fields ...
  final String md5;                   // 新增：PDF MD5 标识

  const Document({
    // ... existing params ...
    required this.md5,
  });
}
```

### 6.2 存储仓库接口

```dart
// lib/src/mindmap/storage/topic_repository.dart

abstract class TopicRepository {
  // ── Topic CRUD ──
  Future<String> createTopic(String title);
  Future<Topic?> getTopic(String id);
  Future<List<Topic>> getTopics({bool includeTrashed = false});
  Future<void> renameTopic(String id, String newTitle);
  Future<void> deleteTopic(String id);
  Future<void> addPdfToTopic(String topicId, String pdfId);
  Future<void> removePdfFromTopic(String topicId, String pdfId);

  // ── Note CRUD ──
  Future<String> createNote({
    required String topicId,
    required String title,
    String? pdfId,
    String? highlightText,
    String? noteText,
    int? startPage,
    String? positionJson,
  });
  Future<Note?> getNote(String id);
  Future<List<Note>> getNotesByTopic(String topicId);
  Future<List<Note>> getChildNotes(String parentId);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> addChildNote(String parentId, String childId);
  Future<void> removeChildNote(String parentId, String childId);

  // ── Media CRUD ──
  Future<String> saveMedia(Uint8List data);
  Future<Uint8List?> getMediaData(String md5);
  Future<void> deleteMedia(String md5);
}
```

---

## 七、文件结构规划

```
lib/src/mindmap/
├── domain/
│   ├── topic.dart                 # Topic 实体 + 管道分隔解析
│   ├── note.dart                  # Note 实体 + childIds
│   ├── media.dart                 # Media 实体
│   ├── pdf_position.dart          # PDF 位置坐标
│   ├── highlight_style.dart       # 高亮样式枚举
│   └── note_type.dart             # 节点类型枚举
├── storage/
│   ├── topic_repository.dart      # 抽象仓库接口
│   ├── ffi_topic_repository.dart  # FFI 实现
│   └── in_memory_topic_repository.dart # 内存实现（测试）
└── widgets/
    ├── topic_canvas.dart          # 导图画布
    ├── note_card.dart             # 节点卡片
    └── connection_line.dart       # 连线绘制

rust/src/storage/
├── topics.rs                      # Topic 表 CRUD
├── notes.rs                       # Note 表 CRUD
├── media.rs                       # Media 表 CRUD
└── db.rs                          # 表创建 DDL（扩展）
```

---

## 八、总结

本设计基于 MarginNote 数据结构逆向分析，采用以下核心模式：

1. **管道分隔子节点列表** - `childIds: "id1|id2|id3"`
2. **Topic 笔记本模式** - 一个笔记本关联多个 PDF
3. **Note 实体合并摘录信息** - 不需要单独的 SourceLink 表
4. **Media BLOB 存储** - 图片直接存数据库
5. **JSON 坐标格式** - 灵活扩展 PDF 位置

相比原有设计：
- **简化了关系模型**（删除 MindMapEdge、SourceLink）
- **优化了查询效率**（parent_id 冠余存储）
- **兼容 MarginNote 格式**（便于未来导入导出）