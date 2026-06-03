# MindMap M1a: 领域模型 + 存储层 Implementation Plan (v2 - 最优方案)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 MindMap 功能的数据基础，融合 MarginNote + GuruMind 最优设计。

**Architecture:**
- **Dart 侧**：领域模型类 + 抽象仓库接口 + FFI 适配器
- **Rust 侧**：SQLite 表创建 + CRUD 函数 + FFI 导出
- **数据模型**：MarginNote 管道分隔 + GuruMind JSON segments + 反向索引优化

**Tech Stack:**
- Dart: flutter_rust_bridge 2.x
- Rust: rusqlite, uuid, serde, serde_json
- 存储: SQLite 单文件（MarginNote 模式）

**设计原则:**
- MarginNote: PDF摘录完整支持（页码+坐标）、管道分隔childIds、USN同步
- GuruMind: JSON segments富文本、ID前缀类型区分、linkedIds反向索引
- 优化: parent_id反向查询字段（解决全表扫描）

---

## File Structure

### Created Files

| File | Responsibility |
|------|---------------|
| `lib/src/mindmap/domain/topic.dart` | Topic 实体（笔记本） |
| `lib/src/mindmap/domain/note.dart` | Note 实体（导图节点） |
| `lib/src/mindmap/domain/note_content.dart` | NoteContent 富文本（JSON segments） |
| `lib/src/mindmap/domain/pdf_position.dart` | PdfPosition PDF摘录位置 |
| `lib/src/mindmap/domain/media_asset.dart` | MediaAsset 媒体资源 |
| `lib/src/mindmap/domain/pdf_config.dart` | PdfConfig PDF配置 |
| `lib/src/mindmap/storage/mindmap_repository.dart` | 抽象仓库接口 |
| `lib/src/mindmap/storage/ffi_mindmap_repository.dart` | FFI 适配器 |
| `lib/src/mindmap/storage/in_memory_mindmap_repository.dart` | 内存仓库（测试） |
| `rust/src/storage/mindmap.rs` | 所有表 + CRUD |
| `test/mindmap/domain/topic_test.dart` | Topic 单元测试 |
| `test/mindmap/domain/note_test.dart` | Note 单元测试 |

### Modified Files

| File | Modification |
|------|-------------|
| `rust/src/storage/mod.rs` | 引入 mindmap 模块 |
| `rust/src/storage/db.rs` | 添加 MindMap 表创建 DDL |
| `rust/src/api/storage.rs` | 添加 FFI 函数导出 |

---

## Task 1: 创建基础领域模型

**Files:**
- Create: `lib/src/mindmap/domain/pdf_position.dart`
- Create: `lib/src/mindmap/domain/note_content.dart`

- [ ] **Step 1: 创建 PdfPosition 实体（PDF摘录位置）**

```dart
// lib/src/mindmap/domain/pdf_position.dart

/// PDF摘录位置信息（完整支持回溯定位）。
///
/// 设计依据：
/// - MarginNote: ZSTARTPAGE/ZENDPAGE + ZSTARTPOS/ZENDPOS
/// - 支持：页码范围、精确坐标、跨页摘录
class PdfPosition {
  /// 起始页码（0-based）
  final int startPage;

  /// 结束页码（0-based，支持跨页摘录）
  final int? endPage;

  /// 起始坐标（页面坐标系统）
  final PdfPoint startPos;

  /// 结束坐标
  final PdfPoint? endPos;

  const PdfPosition({
    required this.startPage,
    this.endPage,
    required this.startPos,
    this.endPos,
  });

  /// 是否跨页摘录
  bool get isCrossPage => endPage != null && endPage != startPage;

  /// 从 JSON 解析
  factory PdfPosition.fromJson(Map<String, dynamic> json) {
    return PdfPosition(
      startPage: json['start_page'] as int,
      endPage: json['end_page'] as int?,
      startPos: PdfPoint.fromJson(json['start_pos'] as Map<String, dynamic>),
      endPos: json['end_pos'] != null
          ? PdfPoint.fromJson(json['end_pos'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 转为 JSON（用于数据库存储）
  Map<String, dynamic> toJson() => {
        'start_page': startPage,
        if (endPage != null) 'end_page': endPage,
        'start_pos': startPos.toJson(),
        if (endPos != null) 'end_pos': endPos!.toJson(),
      };
}

/// PDF 页面坐标点。
class PdfPoint {
  final double x;
  final double y;

  const PdfPoint({required this.x, required this.y});

  factory PdfPoint.fromJson(Map<String, dynamic> json) {
    return PdfPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}
```

- [ ] **Step 2: 创建 NoteContent 实体（JSON segments 富文本）**

```dart
// lib/src/mindmap/domain/note_content.dart

/// 富文本内容（GuruMind JSON segments 格式）。
///
/// 设计依据：
/// - GuruMind: 标准化 JSON segments
/// - 支持：文本样式、图片摘录、填空标记
class NoteContent {
  final List<Segment> segments;

  const NoteContent({required this.segments});

  /// 从 JSON 解析
  factory NoteContent.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List;
    return NoteContent(
      segments: segmentsList
          .map((s) => Segment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  /// 纯文本内容（去除样式）
  String get plainText {
    return segments
        .where((s) => s.type == SegmentType.text)
        .map((s) => s.text ?? '')
        .join('');
  }
}

/// 段落类型
enum SegmentType {
  text,
  image,
}

/// 段落基类
class Segment {
  final SegmentType type;

  // 文本段落字段
  final String? text;
  final TextStyle? style;

  // 图片段落字段
  final String? path; // assets/xxx.png
  final double? width;
  final double? height;
  final int? fit;

  const Segment({
    required this.type,
    this.text,
    this.style,
    this.path,
    this.width,
    this.height,
    this.fit,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    return Segment(
      type: typeStr == 'text' ? SegmentType.text : SegmentType.image,
      text: json['text'] as String?,
      style: json['style'] != null
          ? TextStyle.fromJson(json['style'] as Map<String, dynamic>)
          : null,
      path: json['path'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      fit: json['fit'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type == SegmentType.text ? 'text' : 'image'};
    if (text != null) json['text'] = text;
    if (style != null) json['style'] = style!.toJson();
    if (path != null) json['path'] = path;
    if (width != null) json['width'] = width;
    if (height != null) json['height'] = height;
    if (fit != null) json['fit'] = fit;
    return json;
  }
}

/// 文本样式（GuruMind 完整样式）
class TextStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool cloze; // 填空标记
  final String? link;
  final String? textColor;
  final String? backgroundColor;
  final double? fontSize;
  final String? textAlign;

  const TextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.cloze = false,
    this.link,
    this.textColor,
    this.backgroundColor,
    this.fontSize,
    this.textAlign,
  });

  factory TextStyle.fromJson(Map<String, dynamic> json) {
    return TextStyle(
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strikethrough: json['strikethrough'] as bool? ?? false,
      cloze: json['cloze'] as bool? ?? false,
      link: json['link'] as String?,
      textColor: json['textColor'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      textAlign: json['textAlign'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strikethrough': strikethrough,
        'cloze': cloze,
        if (link != null) 'link': link,
        if (textColor != null) 'textColor': textColor,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (fontSize != null) 'fontSize': fontSize,
        if (textAlign != null) 'textAlign': textAlign,
      };
}
```

- [ ] **Step 3: 运行静态分析验证**

Run: `dart analyze lib/src/mindmap/domain/`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/src/mindmap/domain/pdf_position.dart lib/src/mindmap/domain/note_content.dart
git commit -m "feat(mindmap): add PdfPosition and NoteContent domain models"
```

---

## Task 2: 实现 Topic 实体（笔记本）

**Files:**
- Create: `lib/src/mindmap/domain/topic.dart`
- Test: `test/mindmap/domain/topic_test.dart`

- [ ] **Step 1: 编写 Topic 测试**

```dart
// test/mindmap/domain/topic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('Topic', () {
    test('fromMap creates valid Topic with pipe-separated fields', () {
      final map = {
        'id': '0-6f73097d-26ad-4537-9cb2-156e22f17160',
        'title': 'MarginNote导图',
        'pdf_ids': 'pdf1|pdf2|pdf3', // 管道分隔
        'root_note_ids': 'note1|note2', // 管道分隔
        'is_trashed': 0,
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
        'last_visit_at': '2026-05-30T11:00:00Z',
        'sync_version': 42,
      };

      final topic = Topic.fromMap(map);

      expect(topic.id, '0-6f73097d-26ad-4537-9cb2-156e22f17160');
      expect(topic.title, 'MarginNote导图');
      expect(topic.pdfIds, ['pdf1', 'pdf2', 'pdf3']);
      expect(topic.rootNoteIds, ['note1', 'note2']);
      expect(topic.isTrashed, false);
      expect(topic.syncVersion, 42);
    });

    test('toMap produces valid map with pipe-separated fields', () {
      final topic = Topic(
        id: '0-xxx',
        title: 'Test Topic',
        pdfIds: ['pdf1', 'pdf2'],
        rootNoteIds: ['note1'],
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = topic.toMap();

      expect(map['pdf_ids'], 'pdf1|pdf2');
      expect(map['root_note_ids'], 'note1');
    });

    test('handles empty pipe-separated fields', () {
      final map = {
        'id': '0-xxx',
        'title': 'Empty Topic',
        'pdf_ids': null,
        'root_note_ids': '',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
      };

      final topic = Topic.fromMap(map);

      expect(topic.pdfIds, []);
      expect(topic.rootNoteIds, []);
    });
  });
}
```

- [ ] **Step 2: 实现 Topic 实体**

```dart
// lib/src/mindmap/domain/topic.dart

/// 思维导图笔记本（对应 MarginNote ZTOPIC）。
///
/// 设计依据：
/// - MarginNote: 单文件笔记本模式
/// - 支持多 PDF 关联（pdfIds）
/// - ID前缀: "0-{UUID}" (GuruMind 风格)
class Topic {
  /// 笔记本 ID（格式: "0-{UUID}"）
  final String id;

  /// 笔记本标题
  final String title;

  /// 作者（可选）
  final String? author;

  /// 关联的 PDF 文档 MD5 列表（管道分隔存储）
  final List<String> pdfIds;

  /// 根节点 ID 列表（管道分隔存储）
  final List<String> rootNoteIds;

  /// 缩略图路径
  final String? thumbnailPath;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 最后访问时间
  final DateTime? lastVisitAt;

  /// 是否已删除
  final bool isTrashed;

  /// 同步版本号（USN 机制）
  final int syncVersion;

  const Topic({
    required this.id,
    required this.title,
    this.author,
    this.pdfIds = const [],
    this.rootNoteIds = const [],
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitAt,
    this.isTrashed = false,
    this.syncVersion = 0,
  });

  /// 从数据库 Map 创建（支持管道分隔字段）
  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      pdfIds: _parsePipedList(map['pdf_ids'] as String?),
      rootNoteIds: _parsePipedList(map['root_note_ids'] as String?),
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastVisitAt: map['last_visit_at'] != null
          ? DateTime.parse(map['last_visit_at'] as String)
          : null,
      isTrashed: (map['is_trashed'] as int?) == 1,
      syncVersion: (map['sync_version'] as int?) ?? 0,
    );
  }

  /// 转为数据库 Map（管道分隔字段）
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'pdf_ids': pdfIds.isEmpty ? null : pdfIds.join('|'),
        'root_note_ids': rootNoteIds.isEmpty ? null : rootNoteIds.join('|'),
        'thumbnail_path': thumbnailPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_visit_at': lastVisitAt?.toIso8601String(),
        'is_trashed': isTrashed ? 1 : 0,
        'sync_version': syncVersion,
      };

  /// 解析管道分隔字符串
  static List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 复制并更新字段
  Topic copyWith({
    String? title,
    List<String>? pdfIds,
    List<String>? rootNoteIds,
    DateTime? updatedAt,
    DateTime? lastVisitAt,
    int? syncVersion,
  }) {
    return Topic(
      id: id,
      title: title ?? this.title,
      author: author,
      pdfIds: pdfIds ?? this.pdfIds,
      rootNoteIds: rootNoteIds ?? this.rootNoteIds,
      thumbnailPath: thumbnailPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      isTrashed: isTrashed,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `dart test test/mindmap/domain/topic_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/src/mindmap/domain/topic.dart test/mindmap/domain/topic_test.dart
git commit -m "feat(mindmap): add Topic entity with pipe-separated fields"
```

---

## Task 3: 实现 Note 实体（导图节点）

**Files:**
- Create: `lib/src/mindmap/domain/note.dart`
- Test: `test/mindmap/domain/note_test.dart`

- [ ] **Step 1: 编写 Note 测试**

```dart
// test/mindmap/domain/note_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/note_content.dart';

void main() {
  group('Note', () {
    test('fromMap creates valid Note with all fields', () {
      final map = {
        'id': '1-abc123',
        'topic_id': '0-xxx',
        'parent_id': '1-parent',
        'title': 'Test Note',
        'child_ids': 'child1|child2|child3',
        'content_json': '{"segments":[{"type":"text","text":"Hello","style":{"bold":false}}]}',
        'pdf_id': 'pdf-md5',
        'start_page': 5,
        'end_page': 6,
        'start_pos': '{"x":100.0,"y":200.0}',
        'end_pos': '{"x":300.0,"y":400.0}',
        'highlight_text': 'Original PDF text',
        'highlight_style': 'mbooks-annotation12',
        'media_ids': 'media1|media2',
        'position_x': 50.0,
        'position_y': 100.0,
        'z_index': 10,
        'is_collapsed': 1,
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
        'sync_version': 5,
      };

      final note = Note.fromMap(map);

      expect(note.id, '1-abc123');
      expect(note.topicId, '0-xxx');
      expect(note.parentId, '1-parent');
      expect(note.childIds, ['child1', 'child2', 'child3']);
      expect(note.pdfId, 'pdf-md5');
      expect(note.startPage, 5);
      expect(note.endPage, 6);
      expect(note.highlightText, 'Original PDF text');
      expect(note.positionX, 50.0);
      expect(note.positionY, 100.0);
      expect(note.isCollapsed, true);
    });

    test('toMap produces valid map with pipe-separated child_ids', () {
      final note = Note(
        id: '1-xxx',
        topicId: '0-xxx',
        title: 'Test',
        childIds: ['a', 'b', 'c'],
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = note.toMap();

      expect(map['child_ids'], 'a|b|c');
    });

    test('parses JSON content correctly', () {
      final map = {
        'id': '1-xxx',
        'topic_id': '0-xxx',
        'title': 'Test',
        'content_json': '{"segments":[{"type":"text","text":"Hello","style":{"bold":true}}]}',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
      };

      final note = Note.fromMap(map);

      expect(note.content, isNotNull);
      expect(note.content!.segments.length, 1);
      expect(note.content!.segments[0].text, 'Hello');
      expect(note.content!.segments[0].style?.bold, true);
    });
  });
}
```

- [ ] **Step 2: 实现 Note 实体**

```dart
// lib/src/mindmap/domain/note.dart

import 'dart:convert';
import 'note_content.dart';

/// 导图节点（对应 MarginNote ZBOOKNOTE）。
///
/// 设计依据：
/// - MarginNote: 管道分隔 childIds + PDF 摘录完整支持
/// - GuruMind: JSON segments 富文本
/// - 优化: parent_id 反向索引
/// - ID前缀: "1-{UUID}" (导图节点) 或 "2-{UUID}" (笔记节点)
class Note {
  /// 节点 ID（格式: "1-{UUID}" 或 "2-{UUID}"）
  final String id;

  /// 所属导图 ID
  final String topicId;

  /// 主父节点 ID（优化反向查询）
  final String? parentId;

  /// 节点标题
  final String title;

  /// 富文本内容（JSON segments 格式）
  final NoteContent? content;

  /// 子节点 ID 列表（管道分隔存储，MarginNote 模式）
  final List<String> childIds;

  /// 关联的 PDF ID
  final String? pdfId;

  /// PDF 起始页码
  final int? startPage;

  /// PDF 结束页码（支持跨页摘录）
  final int? endPage;

  /// 起始坐标 JSON（{"x":..., "y":...}）
  final String? startPosJson;

  /// 结束坐标 JSON
  final String? endPosJson;

  /// PDF 摘录原文
  final String? highlightText;

  /// 高亮样式（MarginNote: mbooks-annotation12）
  final String? highlightStyle;

  /// 关联媒体 ID 列表（管道分隔）
  final List<String> mediaIds;

  /// 画布 X 坐标
  final double? positionX;

  /// 画布 Y 坐标
  final double? positionY;

  /// Z 序索引
  final int zIndex;

  /// 是否折叠
  final bool isCollapsed;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 同步版本号
  final int syncVersion;

  const Note({
    required this.id,
    required this.topicId,
    this.parentId,
    required this.title,
    this.content,
    this.childIds = const [],
    this.pdfId,
    this.startPage,
    this.endPage,
    this.startPosJson,
    this.endPosJson,
    this.highlightText,
    this.highlightStyle,
    this.mediaIds = const [],
    this.positionX,
    this.positionY,
    this.zIndex = 0,
    this.isCollapsed = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion = 0,
  });

  /// 从数据库 Map 创建
  factory Note.fromMap(Map<String, dynamic> map) {
    NoteContent? content;
    if (map['content_json'] != null) {
      try {
        final json = jsonDecode(map['content_json'] as String) as Map<String, dynamic>;
        content = NoteContent.fromJson(json);
      } catch (_) {
        // JSON 解析失败时忽略
      }
    }

    return Note(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      parentId: map['parent_id'] as String?,
      title: map['title'] as String,
      content: content,
      childIds: _parsePipedList(map['child_ids'] as String?),
      pdfId: map['pdf_id'] as String?,
      startPage: map['start_page'] as int?,
      endPage: map['end_page'] as int?,
      startPosJson: map['start_pos'] as String?,
      endPosJson: map['end_pos'] as String?,
      highlightText: map['highlight_text'] as String?,
      highlightStyle: map['highlight_style'] as String?,
      mediaIds: _parsePipedList(map['media_ids'] as String?),
      positionX: (map['position_x'] as num?)?.toDouble(),
      positionY: (map['position_y'] as num?)?.toDouble(),
      zIndex: map['z_index'] as int? ?? 0,
      isCollapsed: (map['is_collapsed'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncVersion: (map['sync_version'] as int?) ?? 0,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'parent_id': parentId,
        'title': title,
        'content_json': content != null ? jsonEncode(content!.toJson()) : null,
        'child_ids': childIds.isEmpty ? null : childIds.join('|'),
        'pdf_id': pdfId,
        'start_page': startPage,
        'end_page': endPage,
        'start_pos': startPosJson,
        'end_pos': endPosJson,
        'highlight_text': highlightText,
        'highlight_style': highlightStyle,
        'media_ids': mediaIds.isEmpty ? null : mediaIds.join('|'),
        'position_x': positionX,
        'position_y': positionY,
        'z_index': zIndex,
        'is_collapsed': isCollapsed ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_version': syncVersion,
      };

  /// 解析管道分隔字符串
  static List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 复制并更新字段
  Note copyWith({
    String? title,
    NoteContent? content,
    List<String>? childIds,
    String? parentId,
    double? positionX,
    double? positionY,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      topicId: topicId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      content: content ?? this.content,
      childIds: childIds ?? this.childIds,
      pdfId: pdfId,
      startPage: startPage,
      endPage: endPage,
      startPosJson: startPosJson,
      endPosJson: endPosJson,
      highlightText: highlightText,
      highlightStyle: highlightStyle,
      mediaIds: mediaIds,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      zIndex: zIndex,
      isCollapsed: isCollapsed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion,
    );
  }
}
```

- [ ] **Step 3: 运行测试验证**

Run: `dart test test/mindmap/domain/note_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/src/mindmap/domain/note.dart test/mindmap/domain/note_test.dart
git commit -m "feat(mindmap): add Note entity with PDF excerpt support"
```

---

## Task 4: 创建 Rust 数据库表

**Files:**
- Modify: `rust/src/storage/db.rs`

- [ ] **Step 1: 在 db.rs 添加表创建 DDL**

```rust
// rust/src/storage/db.rs

// 在 create_tables() 函数中添加:

// MindMap Topics 表
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS mindmap_topics (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        pdf_ids TEXT,
        root_note_ids TEXT,
        thumbnail_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_visit_at INTEGER,
        is_trashed INTEGER DEFAULT 0,
        sync_version INTEGER DEFAULT 0
    )
    "#,
    [],
)?;

// MindMap Notes 表
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS mindmap_notes (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        parent_id TEXT,
        title TEXT NOT NULL,
        content_json TEXT,
        child_ids TEXT,
        pdf_id TEXT,
        start_page INTEGER,
        end_page INTEGER,
        start_pos TEXT,
        end_pos TEXT,
        highlight_text TEXT,
        highlight_style TEXT,
        media_ids TEXT,
        position_x REAL,
        position_y REAL,
        z_index INTEGER DEFAULT 0,
        is_collapsed INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_version INTEGER DEFAULT 0,
        FOREIGN KEY (topic_id) REFERENCES mindmap_topics(id)
    )
    "#,
    [],
)?;

// 创建索引
conn.execute(
    "CREATE INDEX IF NOT EXISTS idx_notes_topic ON mindmap_notes(topic_id)",
    [],
)?;
conn.execute(
    "CREATE INDEX IF NOT EXISTS idx_notes_parent ON mindmap_notes(parent_id)",
    [],
)?;
conn.execute(
    "CREATE INDEX IF NOT EXISTS idx_notes_pdf ON mindmap_notes(pdf_id)",
    [],
)?;

// Media Assets 表
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS media_assets (
        id TEXT PRIMARY KEY,
        data BLOB NOT NULL,
        thumbnail BLOB,
        media_type TEXT DEFAULT 'image/png',
        created_at INTEGER NOT NULL
    )
    "#,
    [],
)?;

// PDF Configs 表
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS pdf_configs (
        md5 TEXT PRIMARY KEY,
        title TEXT,
        page_count INTEGER,
        pages_json TEXT,
        current_page INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
    )
    "#,
    [],
)?;
```

- [ ] **Step 2: 编译验证**

Run: `cd rust && cargo check`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add rust/src/storage/db.rs
git commit -m "feat(mindmap): add MindMap database tables DDL"
```

---

## Task 5: 实现 Rust CRUD 函数

**Files:**
- Create: `rust/src/storage/mindmap.rs`

- [ ] **Step 1: 创建 CRUD 函数**

```rust
// rust/src/storage/mindmap.rs

use rusqlite::{params, Connection, Result as SqliteResult};
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

/// Topic（笔记本）实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Topic {
    pub id: String,
    pub title: String,
    pub author: Option<String>,
    pub pdf_ids: Option<String>,      // 管道分隔
    pub root_note_ids: Option<String>, // 管道分隔
    pub thumbnail_path: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub last_visit_at: Option<i64>,
    pub is_trashed: bool,
    pub sync_version: i64,
}

/// Note（导图节点）实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: String,
    pub topic_id: String,
    pub parent_id: Option<String>,
    pub title: String,
    pub content_json: Option<String>,
    pub child_ids: Option<String>, // 管道分隔
    pub pdf_id: Option<String>,
    pub start_page: Option<i32>,
    pub end_page: Option<i32>,
    pub start_pos: Option<String>,
    pub end_pos: Option<String>,
    pub highlight_text: Option<String>,
    pub highlight_style: Option<String>,
    pub media_ids: Option<String>, // 管道分隔
    pub position_x: Option<f64>,
    pub position_y: Option<f64>,
    pub z_index: i32,
    pub is_collapsed: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub sync_version: i64,
}

// ==================== Topic CRUD ====================

/// 创建 Topic
pub fn create_topic(conn: &Connection, title: &str, author: Option<&str>) -> SqliteResult<String> {
    let id = format!("0-{}", uuid::Uuid::new_v4());
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    conn.execute(
        "INSERT INTO mindmap_topics (id, title, author, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![id, title, author, now, now],
    )?;

    Ok(id)
}

/// 根据 ID 查询 Topic
pub fn get_topic_by_id(conn: &Connection, id: &str) -> SqliteResult<Option<Topic>> {
    let mut stmt = conn.prepare(
        "SELECT id, title, author, pdf_ids, root_note_ids, thumbnail_path,
                created_at, updated_at, last_visit_at, is_trashed, sync_version
         FROM mindmap_topics WHERE id = ?1"
    )?;

    let mut rows = stmt.query(params![id])?;

    if let Some(row) = rows.next()? {
        Ok(Some(Topic {
            id: row.get(0)?,
            title: row.get(1)?,
            author: row.get(2)?,
            pdf_ids: row.get(3)?,
            root_note_ids: row.get(4)?,
            thumbnail_path: row.get(5)?,
            created_at: row.get(6)?,
            updated_at: row.get(7)?,
            last_visit_at: row.get(8)?,
            is_trashed: row.get::<_, i32>(9)? == 1,
            sync_version: row.get(10)?,
        }))
    } else {
        Ok(None)
    }
}

/// 更新 Topic
pub fn update_topic(conn: &Connection, topic: &Topic) -> SqliteResult<()> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    conn.execute(
        "UPDATE mindmap_topics SET title = ?1, author = ?2, pdf_ids = ?3,
         root_note_ids = ?4, updated_at = ?5, sync_version = sync_version + 1
         WHERE id = ?6",
        params![
            topic.title,
            topic.author,
            topic.pdf_ids,
            topic.root_note_ids,
            now,
            topic.id
        ],
    )?;

    Ok(())
}

/// 删除 Topic（软删除）
pub fn trash_topic(conn: &Connection, id: &str) -> SqliteResult<()> {
    conn.execute(
        "UPDATE mindmap_topics SET is_trashed = 1 WHERE id = ?1",
        params![id],
    )?;
    Ok(())
}

// ==================== Note CRUD ====================

/// 创建 Note
pub fn create_note(
    conn: &Connection,
    topic_id: &str,
    title: &str,
    parent_id: Option<&str>,
) -> SqliteResult<String> {
    let id = format!("1-{}", uuid::Uuid::new_v4());
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    conn.execute(
        "INSERT INTO mindmap_notes (id, topic_id, parent_id, title, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![id, topic_id, parent_id, title, now, now],
    )?;

    Ok(id)
}

/// 添加子节点（管道分隔追加）
pub fn add_child_to_note(conn: &Connection, parent_id: &str, child_id: &str) -> SqliteResult<()> {
    // 获取当前 child_ids
    let current: Option<String> = conn.query_row(
        "SELECT child_ids FROM mindmap_notes WHERE id = ?1",
        params![parent_id],
        |row| row.get(0),
    ).ok().flatten();

    // 追加新子节点
    let new_child_ids = match current {
        Some(mut s) if !s.is_empty() => {
            s.push('|');
            s.push_str(child_id);
            s
        }
        _ => child_id.to_string(),
    };

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    // 更新父节点
    conn.execute(
        "UPDATE mindmap_notes SET child_ids = ?1, updated_at = ?2 WHERE id = ?3",
        params![new_child_ids, now, parent_id],
    )?;

    // 更新子节点的 parent_id（反向索引）
    conn.execute(
        "UPDATE mindmap_notes SET parent_id = ?1, updated_at = ?2 WHERE id = ?3",
        params![parent_id, now, child_id],
    )?;

    Ok(())
}

/// 查询节点的子节点列表
pub fn get_note_children(conn: &Connection, parent_id: &str) -> SqliteResult<Vec<Note>> {
    // 获取 child_ids 字符串
    let child_ids_str: Option<String> = conn.query_row(
        "SELECT child_ids FROM mindmap_notes WHERE id = ?1",
        params![parent_id],
        |row| row.get(0),
    ).ok().flatten();

    let child_ids_str = match child_ids_str {
        Some(s) if !s.is_empty() => s,
        _ => return Ok(vec![]),
    };

    // 拆分 ID 列表
    let ids: Vec<&str> = child_ids_str.split('|').filter(|s| !s.is_empty()).collect();
    if ids.is_empty() {
        return Ok(vec![]);
    }

    // 批量查询子节点
    let placeholders = ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
    let sql = format!(
        "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                media_ids, position_x, position_y, z_index, is_collapsed,
                created_at, updated_at, sync_version
         FROM mindmap_notes WHERE id IN ({}) ORDER BY z_index",
        placeholders
    );

    let mut stmt = conn.prepare(&sql)?;
    let params: Vec<&dyn rusqlite::ToSql> = ids.iter().map(|s| s as &dyn rusqlite::ToSql).collect();
    let mut rows = stmt.query(params.as_slice())?;

    let mut notes = Vec::new();
    while let Some(row) = rows.next()? {
        notes.push(Note {
            id: row.get(0)?,
            topic_id: row.get(1)?,
            parent_id: row.get(2)?,
            title: row.get(3)?,
            content_json: row.get(4)?,
            child_ids: row.get(5)?,
            pdf_id: row.get(6)?,
            start_page: row.get(7)?,
            end_page: row.get(8)?,
            start_pos: row.get(9)?,
            end_pos: row.get(10)?,
            highlight_text: row.get(11)?,
            highlight_style: row.get(12)?,
            media_ids: row.get(13)?,
            position_x: row.get(14)?,
            position_y: row.get(15)?,
            z_index: row.get(16)?,
            is_collapsed: row.get::<_, i32>(17)? == 1,
            created_at: row.get(18)?,
            updated_at: row.get(19)?,
            sync_version: row.get(20)?,
        });
    }

    Ok(notes)
}

/// 根据 PDF ID 查询所有相关节点
pub fn get_notes_by_pdf(conn: &Connection, pdf_id: &str) -> SqliteResult<Vec<Note>> {
    let mut stmt = conn.prepare(
        "SELECT id, topic_id, parent_id, title, content_json, child_ids, pdf_id,
                start_page, end_page, start_pos, end_pos, highlight_text, highlight_style,
                media_ids, position_x, position_y, z_index, is_collapsed,
                created_at, updated_at, sync_version
         FROM mindmap_notes WHERE pdf_id = ?1 ORDER BY start_page"
    )?;

    let mut rows = stmt.query(params![pdf_id])?;

    let mut notes = Vec::new();
    while let Some(row) = rows.next()? {
        notes.push(Note {
            id: row.get(0)?,
            topic_id: row.get(1)?,
            parent_id: row.get(2)?,
            title: row.get(3)?,
            content_json: row.get(4)?,
            child_ids: row.get(5)?,
            pdf_id: row.get(6)?,
            start_page: row.get(7)?,
            end_page: row.get(8)?,
            start_pos: row.get(9)?,
            end_pos: row.get(10)?,
            highlight_text: row.get(11)?,
            highlight_style: row.get(12)?,
            media_ids: row.get(13)?,
            position_x: row.get(14)?,
            position_y: row.get(15)?,
            z_index: row.get(16)?,
            is_collapsed: row.get::<_, i32>(17)? == 1,
            created_at: row.get(18)?,
            updated_at: row.get(19)?,
            sync_version: row.get(20)?,
        });
    }

    Ok(notes)
}
```

- [ ] **Step 2: 在 mod.rs 中导出模块**

```rust
// rust/src/storage/mod.rs

pub mod mindmap;
pub use mindmap::*;
```

- [ ] **Step 3: 编译验证**

Run: `cd rust && cargo check`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add rust/src/storage/mindmap.rs rust/src/storage/mod.rs
git commit -m "feat(mindmap): add Rust CRUD functions for Topic and Note"
```

---

## Task 6: 添加 FFI 导出函数

**Files:**
- Modify: `rust/src/api/storage.rs`

- [ ] **Step 1: 添加 FFI 函数导出**

```rust
// rust/src/api/storage.rs

// 在文件顶部添加:
use crate::storage::mindmap::*;

// 添加 FFI 函数:

/// 创建思维导图笔记本
#[flutter_rust_bridge::frb]
pub fn mindmap_create_topic(title: String, author: Option<String>) -> Result<String, String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    create_topic(&conn, &title, author.as_deref())
        .map_err(|e| e.to_string())
}

/// 查询笔记本详情
#[flutter_rust_bridge::frb]
pub fn mindmap_get_topic(id: String) -> Result<Option<Topic>, String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    get_topic_by_id(&conn, &id)
        .map_err(|e| e.to_string())
}

/// 创建导图节点
#[flutter_rust_bridge::frb]
pub fn mindmap_create_note(
    topic_id: String,
    title: String,
    parent_id: Option<String>,
) -> Result<String, String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    create_note(&conn, &topic_id, &title, parent_id.as_deref())
        .map_err(|e| e.to_string())
}

/// 添加子节点
#[flutter_rust_bridge::frb]
pub fn mindmap_add_child(parent_id: String, child_id: String) -> Result<(), String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    add_child_to_note(&conn, &parent_id, &child_id)
        .map_err(|e| e.to_string())
}

/// 获取子节点列表
#[flutter_rust_bridge::frb]
pub fn mindmap_get_children(parent_id: String) -> Result<Vec<Note>, String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    get_note_children(&conn, &parent_id)
        .map_err(|e| e.to_string())
}

/// 根据 PDF 查询相关节点
#[flutter_rust_bridge::frb]
pub fn mindmap_get_notes_by_pdf(pdf_id: String) -> Result<Vec<Note>, String> {
    let conn = crate::storage::db::get_connection()
        .map_err(|e| e.to_string())?;

    get_notes_by_pdf(&conn, &pdf_id)
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2: 重新生成 FFI 代码**

Run: `cd rust && cargo build`
Run: `flutter_rust_bridge_codegen generate`

Expected: FFI 代码生成成功

- [ ] **Step 3: Commit**

```bash
git add rust/src/api/storage.rs
git commit -m "feat(mindmap): add FFI functions for MindMap operations"
```

---

## Task 7: 创建 Dart 仓库接口

**Files:**
- Create: `lib/src/mindmap/storage/mindmap_repository.dart`

- [ ] **Step 1: 创建抽象仓库接口**

```dart
// lib/src/mindmap/storage/mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';

/// MindMap 仓库抽象接口。
///
/// 支持两种实现：
/// - FfiMindMapRepository: 生产环境（通过 FFI 调用 Rust）
/// - InMemoryMindMapRepository: 测试环境（内存存储）
abstract class MindMapRepository {
  // ==================== Topic CRUD ====================

  /// 创建笔记本
  Future<String> createTopic(String title, {String? author});

  /// 查询笔记本
  Future<Topic?> getTopic(String id);

  /// 更新笔记本
  Future<void> updateTopic(Topic topic);

  /// 删除笔记本（软删除）
  Future<void> trashTopic(String id);

  // ==================== Note CRUD ====================

  /// 创建节点
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  });

  /// 添加子节点
  Future<void> addChild(String parentId, String childId);

  /// 获取子节点列表
  Future<List<Note>> getChildren(String parentId);

  /// 根据 PDF 查询节点
  Future<List<Note>> getNotesByPdf(String pdfId);

  /// 更新节点
  Future<void> updateNote(Note note);

  /// 删除节点
  Future<void> deleteNote(String id);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/mindmap/storage/mindmap_repository.dart
git commit -m "feat(mindmap): add MindMapRepository abstract interface"
```

---

## Task 8: 实现 FFI 仓库适配器

**Files:**
- Create: `lib/src/mindmap/storage/ffi_mindmap_repository.dart`

- [ ] **Step 1: 实现 FFI 适配器**

```dart
// lib/src/mindmap/storage/ffi_mindmap_repository.dart

import 'package:starmind/src/bridge_generated.dart' as bridge;
import '../domain/topic.dart';
import '../domain/note.dart';
import 'mindmap_repository.dart';

/// FFI 仓库适配器（生产环境）。
///
/// 通过 flutter_rust_bridge 调用 Rust 存储层。
class FfiMindMapRepository implements MindMapRepository {
  final bridge.Starmind _api;

  FfiMindMapRepository(this._api);

  @override
  Future<String> createTopic(String title, {String? author}) async {
    return await _api.mindmapCreateTopic(title: title, author: author);
  }

  @override
  Future<Topic?> getTopic(String id) async {
    final result = await _api.mindmapGetTopic(id: id);
    if (result == null) return null;

    return Topic.fromMap({
      'id': result.id,
      'title': result.title,
      'author': result.author,
      'pdf_ids': result.pdfIds,
      'root_note_ids': result.rootNoteIds,
      'created_at': DateTime.fromMillisecondsSinceEpoch(result.createdAt * 1000).toIso8601String(),
      'updated_at': DateTime.fromMillisecondsSinceEpoch(result.updatedAt * 1000).toIso8601String(),
      'is_trashed': result.isTrashed ? 1 : 0,
      'sync_version': result.syncVersion,
    });
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    // TODO: 实现 FFI 更新函数
    throw UnimplementedError('updateTopic not yet implemented in FFI');
  }

  @override
  Future<void> trashTopic(String id) async {
    // TODO: 实现 FFI 删除函数
    throw UnimplementedError('trashTopic not yet implemented in FFI');
  }

  @override
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  }) async {
    return await _api.mindmapCreateNote(
      topicId: topicId,
      title: title,
      parentId: parentId,
    );
  }

  @override
  Future<void> addChild(String parentId, String childId) async {
    await _api.mindmapAddChild(parentId: parentId, childId: childId);
  }

  @override
  Future<List<Note>> getChildren(String parentId) async {
    final results = await _api.mindmapGetChildren(parentId: parentId);

    return results.map((r) => Note.fromMap({
      'id': r.id,
      'topic_id': r.topicId,
      'parent_id': r.parentId,
      'title': r.title,
      'content_json': r.contentJson,
      'child_ids': r.childIds,
      'pdf_id': r.pdfId,
      'start_page': r.startPage,
      'end_page': r.endPage,
      'start_pos': r.startPos,
      'end_pos': r.endPos,
      'highlight_text': r.highlightText,
      'highlight_style': r.highlightStyle,
      'media_ids': r.mediaIds,
      'position_x': r.positionX,
      'position_y': r.positionY,
      'z_index': r.zIndex,
      'is_collapsed': r.isCollapsed ? 1 : 0,
      'created_at': DateTime.fromMillisecondsSinceEpoch(r.createdAt * 1000).toIso8601String(),
      'updated_at': DateTime.fromMillisecondsSinceEpoch(r.updatedAt * 1000).toIso8601String(),
      'sync_version': r.syncVersion,
    })).toList();
  }

  @override
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    final results = await _api.mindmapGetNotesByPdf(pdfId: pdfId);

    return results.map((r) => Note.fromMap({
      'id': r.id,
      'topic_id': r.topicId,
      'parent_id': r.parentId,
      'title': r.title,
      'content_json': r.contentJson,
      'child_ids': r.childIds,
      'pdf_id': r.pdfId,
      'start_page': r.startPage,
      'end_page': r.endPage,
      'start_pos': r.startPos,
      'end_pos': r.endPos,
      'highlight_text': r.highlightText,
      'highlight_style': r.highlightStyle,
      'media_ids': r.mediaIds,
      'position_x': r.positionX,
      'position_y': r.positionY,
      'z_index': r.zIndex,
      'is_collapsed': r.isCollapsed ? 1 : 0,
      'created_at': DateTime.fromMillisecondsSinceEpoch(r.createdAt * 1000).toIso8601String(),
      'updated_at': DateTime.fromMillisecondsSinceEpoch(r.updatedAt * 1000).toIso8601String(),
      'sync_version': r.syncVersion,
    })).toList();
  }

  @override
  Future<void> updateNote(Note note) async {
    // TODO: 实现 FFI 更新函数
    throw UnimplementedError('updateNote not yet implemented in FFI');
  }

  @override
  Future<void> deleteNote(String id) async {
    // TODO: 实现 FFI 删除函数
    throw UnimplementedError('deleteNote not yet implemented in FFI');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/mindmap/storage/ffi_mindmap_repository.dart
git commit -m "feat(mindmap): add FfiMindMapRepository adapter"
```

---

## Task 9: 创建内存仓库（测试用）

**Files:**
- Create: `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`

- [ ] **Step 1: 实现内存仓库**

```dart
// lib/src/mindmap/storage/in_memory_mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import 'mindmap_repository.dart';

/// 内存仓库（测试环境）。
///
/// 使用 Map 存储数据，用于单元测试。
class InMemoryMindMapRepository implements MindMapRepository {
  final Map<String, Topic> _topics = {};
  final Map<String, Note> _notes = {};

  @override
  Future<String> createTopic(String title, {String? author}) async {
    final id = '0-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _topics[id] = Topic(
      id: id,
      title: title,
      author: author,
      createdAt: now,
      updatedAt: now,
    );

    return id;
  }

  @override
  Future<Topic?> getTopic(String id) async {
    return _topics[id];
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    _topics[topic.id] = topic;
  }

  @override
  Future<void> trashTopic(String id) async {
    final topic = _topics[id];
    if (topic != null) {
      _topics[id] = topic.copyWith(updatedAt: DateTime.now());
      _topics[id] = Topic(
        id: topic.id,
        title: topic.title,
        author: topic.author,
        pdfIds: topic.pdfIds,
        rootNoteIds: topic.rootNoteIds,
        thumbnailPath: topic.thumbnailPath,
        createdAt: topic.createdAt,
        updatedAt: DateTime.now(),
        lastVisitAt: topic.lastVisitAt,
        isTrashed: true,
        syncVersion: topic.syncVersion,
      );
    }
  }

  @override
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  }) async {
    final id = '1-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _notes[id] = Note(
      id: id,
      topicId: topicId,
      parentId: parentId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );

    return id;
  }

  @override
  Future<void> addChild(String parentId, String childId) async {
    final parent = _notes[parentId];
    final child = _notes[childId];

    if (parent != null && child != null) {
      // 更新父节点的 childIds
      final newChildIds = [...parent.childIds, childId];
      _notes[parentId] = parent.copyWith(
        childIds: newChildIds,
        updatedAt: DateTime.now(),
      );

      // 更新子节点的 parentId
      _notes[childId] = child.copyWith(
        parentId: parentId,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<List<Note>> getChildren(String parentId) async {
    final parent = _notes[parentId];
    if (parent == null) return [];

    return parent.childIds
        .map((id) => _notes[id])
        .whereType<Note>()
        .toList();
  }

  @override
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    return _notes.values
        .where((note) => note.pdfId == pdfId)
        .toList();
  }

  @override
  Future<void> updateNote(Note note) async {
    _notes[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
  }

  /// 清空所有数据（测试辅助方法）
  void clear() {
    _topics.clear();
    _notes.clear();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/mindmap/storage/in_memory_mindmap_repository.dart
git commit -m "feat(mindmap): add InMemoryMindMapRepository for testing"
```

---

## Task 10: 集成测试

**Files:**
- Create: `test/mindmap/storage/mindmap_repository_test.dart`

- [ ] **Step 1: 编写集成测试**

```dart
// test/mindmap/storage/mindmap_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  late InMemoryMindMapRepository repository;

  setUp(() {
    repository = InMemoryMindMapRepository();
  });

  group('MindMapRepository', () {
    test('creates and retrieves topic', () async {
      final topicId = await repository.createTopic('Test Topic', author: 'Test Author');

      final topic = await repository.getTopic(topicId);

      expect(topic, isNotNull);
      expect(topic!.title, 'Test Topic');
      expect(topic.author, 'Test Author');
      expect(topic.id, startsWith('0-'));
    });

    test('creates note with parent-child relationship', () async {
      // 创建导图
      final topicId = await repository.createTopic('Test Topic');

      // 创建父节点
      final parentId = await repository.createNote(topicId, 'Parent Node');

      // 创建子节点
      final childId = await repository.createNote(topicId, 'Child Node');

      // 建立关系
      await repository.addChild(parentId, childId);

      // 验证关系
      final children = await repository.getChildren(parentId);
      expect(children.length, 1);
      expect(children[0].id, childId);
      expect(children[0].parentId, parentId);
    });

    test('queries notes by PDF ID', () async {
      final topicId = await repository.createTopic('Test Topic');

      // 创建带 PDF 关联的节点
      final note1Id = await repository.createNote(topicId, 'Note 1');
      final note2Id = await repository.createNote(topicId, 'Note 2');

      // 更新节点添加 PDF ID（使用 copyWith）
      final note1 = await repository.getNotesByPdf('pdf-123');
      expect(note1.isEmpty, true);

      // 手动更新节点（测试场景）
      await repository.updateNote(Note(
        id: note1Id,
        topicId: topicId,
        title: 'Note 1',
        pdfId: 'pdf-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repository.updateNote(Note(
        id: note2Id,
        topicId: topicId,
        title: 'Note 2',
        pdfId: 'pdf-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 查询
      final notes = await repository.getNotesByPdf('pdf-123');
      expect(notes.length, 2);
    });
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `dart test test/mindmap/storage/mindmap_repository_test.dart`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add test/mindmap/storage/mindmap_repository_test.dart
git commit -m "test(mindmap): add repository integration tests"
```

---

## Self-Review

完成后进行自检：

1. **Spec coverage**: 检查是否覆盖了所有 MarginNote 核心特性
   - ✅ Topic 实体（笔记本）
   - ✅ Note 实体（导图节点）
   - ✅ 管道分隔 childIds
   - ✅ PDF 摘录字段（页码+坐标）
   - ✅ parent_id 反向索引
   - ✅ JSON segments 富文本
   - ✅ ID 前缀类型区分
   - ✅ USN 同步版本号

2. **Placeholder scan**: 搜索 "TODO"、"TBD" 等
   - FFI 适配器中有 2 个 TODO（updateTopic、trashTopic）- 可接受，后续完善
   - FFI 适配器中有 2 个 TODO（updateNote、deleteNote）- 可接受，后续完善

3. **Type consistency**: 检查类型一致性
   - ✅ Topic 和 Note 的字段名与 Rust 结构体一致
   - ✅ 管道分隔字段命名一致（`pdf_ids`、`root_note_ids`、`child_ids`）
   - ✅ 时间戳使用 i64（Unix timestamp）

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-30-mindmap-m1a-data-layer-v2.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**