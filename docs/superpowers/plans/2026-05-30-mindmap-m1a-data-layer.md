# MindMap M1a: 领域模型 + 存储层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 MindMap 功能的数据基础，支持思维导图的 CRUD 操作和持久化存储。

**Architecture:** 
- Dart 侧：领域模型类 + 抽象仓库接口 + FFI 适配器 + 内存仓库（测试用）
- Rust 侧：SQLite 表创建 + CRUD 函数 + FFI 导出
- 复用现有的 `db.rs` 和 `storage.rs` 模式

**Tech Stack:** 
- Dart: flutter_rust_bridge 2.x（FFI 生成）
- Rust: rusqlite（SQLite）、uuid（ID 生成）、once_cell（全局状态）

---

## File Structure

### Created Files

| File | Responsibility |
|------|---------------|
| `lib/src/mindmap/domain/layout_mode.dart` | `LayoutMode` 枚举定义 |
| `lib/src/mindmap/domain/edge_type.dart` | `EdgeType` 枚举定义 |
| `lib/src/mindmap/domain/mind_map.dart` | `MindMap` 实体类 |
| `lib/src/mindmap/domain/mind_map_node.dart` | `MindMapNode` + `NodeContent` 实体类 |
| `lib/src/mindmap/domain/source_link.dart` | `SourceLink` 实体类 |
| `lib/src/mindmap/domain/mind_map_edge.dart` | `MindMapEdge` 实体类 |
| `lib/src/mindmap/storage/mind_map_repository.dart` | 抽象仓库接口 |
| `lib/src/mindmap/storage/ffi_mind_map_repository.dart` | FFI 适配器（生产） |
| `lib/src/mindmap/storage/in_memory_mind_map_repository.dart` | 内存仓库（测试） |
| `rust/src/storage/mind_maps.rs` | MindMap 表 + CRUD |
| `rust/src/storage/mind_map_nodes.rs` | MindMapNode 表 + CRUD |
| `rust/src/storage/mind_map_edges.rs` | MindMapEdge 表 + CRUD |
| `rust/src/storage/source_links.rs` | SourceLink 表 + CRUD |

### Modified Files

| File | Modification |
|------|-------------|
| `rust/src/storage/mod.rs` | 引入 MindMap 模块 |
| `rust/src/storage/db.rs` | 添加 MindMap 表创建 DDL |
| `rust/src/api/storage.rs` | 添加 MindMap FFI 函数导出 |
| `lib/src/domain/storage_repository.dart` | 添加 `mindMapRepository` getter（可选，也可保持独立） |

---

## Task 1: 创建枚举类型

**Files:**
- Create: `lib/src/mindmap/domain/layout_mode.dart`
- Create: `lib/src/mindmap/domain/edge_type.dart`

- [ ] **Step 1: 创建 `LayoutMode` 枚举**

```dart
// lib/src/mindmap/domain/layout_mode.dart

/// 画布布局模式。
enum LayoutMode {
  /// 自动布局：Walker 算法排列节点，适合层级结构
  tree,
  /// 自由布局：用户手动拖拽定位，适合自由思维
  freeform,
}
```

- [ ] **Step 2: 创建 `EdgeType` 枚举**

```dart
// lib/src/mindmap/domain/edge_type.dart

/// 边类型。
enum EdgeType {
  /// 父子层级边（由 parentId 隐式定义，不存储在 edges 表中）
  hierarchical,
  /// 跨层级自由链接（用户手动创建，存储在 edges 表中）
  free,
}
```

- [ ] **Step 3: 运行静态分析验证**

Run: `dart analyze lib/src/mindmap/domain/`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/src/mindmap/domain/layout_mode.dart lib/src/mindmap/domain/edge_type.dart
git commit -m "feat(mindmap): add LayoutMode and EdgeType enums"
```

---

## Task 2: 实现 MindMap 实体类

**Files:**
- Create: `lib/src/mindmap/domain/mind_map.dart`
- Test: `test/mindmap/domain/mind_map_test.dart`

- [ ] **Step 1: 编写 MindMap 测试（验证序列化）**

```dart
// test/mindmap/domain/mind_map_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';

void main() {
  group('MindMap', () {
    test('fromMap creates valid MindMap', () {
      final map = {
        'id': 'mm-001',
        'title': 'Chapter 1 Notes',
        'folder_id': 'folder-001',
        'root_node_id': 'node-001',
        'layout_mode': 'tree',
        'is_trashed': 0,
        'created_at': '2026-05-30T10:00:00Z',
        'modified_at': '2026-05-30T12:00:00Z',
      };

      final mindMap = MindMap.fromMap(map);

      expect(mindMap.id, 'mm-001');
      expect(mindMap.title, 'Chapter 1 Notes');
      expect(mindMap.folderId, 'folder-001');
      expect(mindMap.rootNodeId, 'node-001');
      expect(mindMap.layoutMode, LayoutMode.tree);
      expect(mindMap.isTrashed, false);
      expect(mindMap.createdAt, DateTime.parse('2026-05-30T10:00:00Z'));
      expect(mindMap.modifiedAt, DateTime.parse('2026-05-30T12:00:00Z'));
    });

    test('toMap produces valid map', () {
      final mindMap = MindMap(
        id: 'mm-001',
        title: 'Chapter 1 Notes',
        folderId: 'folder-001',
        rootNodeId: 'node-001',
        layoutMode: LayoutMode.tree,
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        modifiedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = mindMap.toMap();

      expect(map['id'], 'mm-001');
      expect(map['title'], 'Chapter 1 Notes');
      expect(map['folder_id'], 'folder-001');
      expect(map['root_node_id'], 'node-001');
      expect(map['layout_mode'], 'tree');
      expect(map['is_trashed'], 0);
      expect(map['created_at'], '2026-05-30T10:00:00.000Z');
      expect(map['modified_at'], '2026-05-30T12:00:00.000Z');
    });

    test('copyWith updates specified fields', () {
      final original = MindMap(
        id: 'mm-001',
        title: 'Original Title',
        layoutMode: LayoutMode.freeform,
        createdAt: DateTime(2026, 5, 30, 10),
        modifiedAt: DateTime(2026, 5, 30, 10),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        layoutMode: LayoutMode.tree,
        modifiedAt: DateTime(2026, 5, 30, 12),
      );

      expect(updated.id, 'mm-001'); // unchanged
      expect(updated.title, 'Updated Title');
      expect(updated.layoutMode, LayoutMode.tree);
      expect(updated.createdAt, DateTime(2026, 5, 30, 10)); // unchanged
      expect(updated.modifiedAt, DateTime(2026, 5, 30, 12));
    });

    test('equality works correctly', () {
      final a = MindMap(
        id: 'mm-001',
        title: 'Test',
        layoutMode: LayoutMode.freeform,
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
      );

      final b = MindMap(
        id: 'mm-001',
        title: 'Test',
        layoutMode: LayoutMode.freeform,
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
      );

      final c = MindMap(
        id: 'mm-002',
        title: 'Test',
        layoutMode: LayoutMode.freeform,
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/domain/mind_map_test.dart`
Expected: FAIL - MindMap class not found

- [ ] **Step 3: 实现 MindMap 实体类**

```dart
// lib/src/mindmap/domain/mind_map.dart

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

  /// 从数据库 Map 创建（字段名使用 snake_case）。
  factory MindMap.fromMap(Map<String, dynamic> map) {
    return MindMap(
      id: map['id'] as String,
      title: map['title'] as String,
      folderId: map['folder_id'] as String?,
      rootNodeId: map['root_node_id'] as String?,
      layoutMode: LayoutMode.values.firstWhere(
        (e) => e.name == (map['layout_mode'] as String? ?? 'freeform'),
        orElse: () => LayoutMode.freeform,
      ),
      isTrashed: (map['is_trashed'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      modifiedAt: DateTime.parse(map['modified_at'] as String),
    );
  }

  /// 转换为数据库 Map（字段名使用 snake_case）。
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'folder_id': folderId,
        'root_node_id': rootNodeId,
        'layout_mode': layoutMode.name,
        'is_trashed': isTrashed ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
      };

  /// 复制并更新指定字段。
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

  @override
  String toString() => 'MindMap(id: $id, title: $title, layoutMode: $layoutMode)';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/domain/mind_map_test.dart`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/domain/mind_map.dart test/mindmap/domain/mind_map_test.dart
git commit -m "feat(mindmap): add MindMap entity with serialization tests"
```

---

## Task 3: 实现 SourceLink 实体类

**Files:**
- Create: `lib/src/mindmap/domain/source_link.dart`
- Test: `test/mindmap/domain/source_link_test.dart`

- [ ] **Step 1: 编写 SourceLink 测试**

```dart
// test/mindmap/domain/source_link_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';

void main() {
  group('SourceLink', () {
    test('fromMap creates valid SourceLink', () {
      final map = {
        'id': 'sl-001',
        'node_id': 'node-001',
        'document_id': 'doc-001',
        'document_title': 'Chapter 1.pdf',
        'page_index': 3,
        'start_char_index': 100,
        'end_char_index': 150,
        'selected_text': 'This is the selected text.',
        'annotation_id': 'ann-001',
        'created_at': '2026-05-30T10:00:00Z',
      };

      final link = SourceLink.fromMap(map);

      expect(link.id, 'sl-001');
      expect(link.nodeId, 'node-001');
      expect(link.documentId, 'doc-001');
      expect(link.documentTitle, 'Chapter 1.pdf');
      expect(link.pageIndex, 3);
      expect(link.startCharIndex, 100);
      expect(link.endCharIndex, 150);
      expect(link.selectedText, 'This is the selected text.');
      expect(link.annotationId, 'ann-001');
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 'sl-002',
        'node_id': 'node-002',
        'document_id': 'doc-001',
        'document_title': 'Chapter 1.pdf',
        'page_index': 5,
        'created_at': '2026-05-30T10:00:00Z',
      };

      final link = SourceLink.fromMap(map);

      expect(link.startCharIndex, isNull);
      expect(link.endCharIndex, isNull);
      expect(link.selectedText, isNull);
      expect(link.annotationId, isNull);
    });

    test('toMap produces valid map', () {
      final link = SourceLink(
        id: 'sl-001',
        nodeId: 'node-001',
        documentId: 'doc-001',
        documentTitle: 'Chapter 1.pdf',
        pageIndex: 3,
        startCharIndex: 100,
        endCharIndex: 150,
        selectedText: 'This is the selected text.',
        annotationId: 'ann-001',
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
      );

      final map = link.toMap();

      expect(map['id'], 'sl-001');
      expect(map['node_id'], 'node-001');
      expect(map['document_id'], 'doc-001');
      expect(map['document_title'], 'Chapter 1.pdf');
      expect(map['page_index'], 3);
      expect(map['start_char_index'], 100);
      expect(map['end_char_index'], 150);
      expect(map['selected_text'], 'This is the selected text.');
      expect(map['annotation_id'], 'ann-001');
    });

    test('equality works correctly', () {
      final a = SourceLink(
        id: 'sl-001',
        nodeId: 'node-001',
        documentId: 'doc-001',
        documentTitle: 'Test.pdf',
        pageIndex: 1,
        createdAt: DateTime(2026, 5, 30),
      );

      final b = SourceLink(
        id: 'sl-001',
        nodeId: 'node-001',
        documentId: 'doc-001',
        documentTitle: 'Test.pdf',
        pageIndex: 1,
        createdAt: DateTime(2026, 5, 30),
      );

      final c = SourceLink(
        id: 'sl-002',
        nodeId: 'node-001',
        documentId: 'doc-001',
        documentTitle: 'Test.pdf',
        pageIndex: 1,
        createdAt: DateTime(2026, 5, 30),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/domain/source_link_test.dart`
Expected: FAIL - SourceLink class not found

- [ ] **Step 3: 实现 SourceLink 实体类**

```dart
// lib/src/mindmap/domain/source_link.dart

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

  /// 从数据库 Map 创建。
  factory SourceLink.fromMap(Map<String, dynamic> map) {
    return SourceLink(
      id: map['id'] as String,
      nodeId: map['node_id'] as String,
      documentId: map['document_id'] as String,
      documentTitle: map['document_title'] as String,
      pageIndex: map['page_index'] as int,
      startCharIndex: map['start_char_index'] as int?,
      endCharIndex: map['end_char_index'] as int?,
      selectedText: map['selected_text'] as String?,
      annotationId: map['annotation_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// 转换为数据库 Map。
  Map<String, dynamic> toMap() => {
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

  @override
  int get hashCode =>
      id.hashCode ^
      nodeId.hashCode ^
      documentId.hashCode ^
      documentTitle.hashCode ^
      pageIndex.hashCode ^
      startCharIndex.hashCode ^
      endCharIndex.hashCode ^
      selectedText.hashCode ^
      annotationId.hashCode ^
      createdAt.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceLink &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nodeId == other.nodeId &&
          documentId == other.documentId &&
          documentTitle == other.documentTitle &&
          pageIndex == other.pageIndex &&
          startCharIndex == other.startCharIndex &&
          endCharIndex == other.endCharIndex &&
          selectedText == other.selectedText &&
          annotationId == other.annotationId &&
          createdAt == other.createdAt;

  @override
  String toString() =>
      'SourceLink(id: $id, nodeId: $nodeId, documentId: $documentId, pageIndex: $pageIndex)';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/domain/source_link_test.dart`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/domain/source_link.dart test/mindmap/domain/source_link_test.dart
git commit -m "feat(mindmap): add SourceLink entity with serialization tests"
```

---

## Task 4: 实现 MindMapNode + NodeContent 实体类

**Files:**
- Create: `lib/src/mindmap/domain/mind_map_node.dart`
- Test: `test/mindmap/domain/mind_map_node_test.dart`

- [ ] **Step 1: 编写 MindMapNode 测试**

```dart
// test/mindmap/domain/mind_map_node_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/domain/ink_stroke.dart';

void main() {
  group('NodeContent', () {
    test('fromJson creates valid NodeContent with text', () {
      final json = {'text': 'Sample text content'};
      final content = NodeContent.fromJson(json);

      expect(content.text, 'Sample text content');
      expect(content.imageRefs, isEmpty);
      expect(content.inkStrokes, isEmpty);
      expect(content.sourceLink, isNull);
    });

    test('fromJson handles imageRefs', () {
      final json = {
        'text': 'Content with image',
        'image_refs': ['img1.png', 'img2.png'],
      };
      final content = NodeContent.fromJson(json);

      expect(content.text, 'Content with image');
      expect(content.imageRefs, ['img1.png', 'img2.png']);
    });

    test('toJson produces valid output', () {
      final content = NodeContent(
        text: 'Test content',
        imageRefs: ['img.png'],
      );

      final json = content.toJson();

      expect(json['text'], 'Test content');
      expect(json['image_refs'], ['img.png']);
      expect(json.containsKey('ink_strokes'), false); // empty list not included
    });
  });

  group('MindMapNode', () {
    test('fromMap creates valid MindMapNode', () {
      final contentJson = jsonEncode({'text': 'Node text'});
      final map = {
        'id': 'node-001',
        'mind_map_id': 'mm-001',
        'parent_id': 'node-000',
        'sort_order': 1,
        'position_x': 100.0,
        'position_y': 200.0,
        'width': 160.0,
        'height': 80.0,
        'color_hex': '#FFFFFF',
        'is_collapsed': 0,
        'content_json': contentJson,
        'created_at': '2026-05-30T10:00:00Z',
        'modified_at': '2026-05-30T12:00:00Z',
      };

      final node = MindMapNode.fromMap(map);

      expect(node.id, 'node-001');
      expect(node.mindMapId, 'mm-001');
      expect(node.parentId, 'node-000');
      expect(node.sortOrder, 1);
      expect(node.positionX, 100.0);
      expect(node.positionY, 200.0);
      expect(node.width, 160.0);
      expect(node.height, 80.0);
      expect(node.colorHex, '#FFFFFF');
      expect(node.isCollapsed, false);
      expect(node.content.text, 'Node text');
    });

    test('fromMap handles null parentId (root node)', () {
      final map = {
        'id': 'node-root',
        'mind_map_id': 'mm-001',
        'sort_order': 0,
        'position_x': 0.0,
        'position_y': 0.0,
        'created_at': '2026-05-30T10:00:00Z',
        'modified_at': '2026-05-30T10:00:00Z',
      };

      final node = MindMapNode.fromMap(map);

      expect(node.parentId, isNull);
      expect(node.width, 160.0); // default
      expect(node.height, 80.0); // default
      expect(node.colorHex, '#FFFFFF'); // default
    });

    test('toMap produces valid map', () {
      final node = MindMapNode(
        id: 'node-001',
        mindMapId: 'mm-001',
        parentId: 'node-000',
        sortOrder: 1,
        positionX: 100.0,
        positionY: 200.0,
        width: 180.0,
        height: 100.0,
        colorHex: '#FF5733',
        content: NodeContent(text: 'Node text'),
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        modifiedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = node.toMap();
      final contentJson = jsonDecode(map['content_json'] as String);

      expect(map['id'], 'node-001');
      expect(map['mind_map_id'], 'mm-001');
      expect(map['parent_id'], 'node-000');
      expect(map['position_x'], 100.0);
      expect(map['color_hex'], '#FF5733');
      expect(contentJson['text'], 'Node text');
    });

    test('copyWith updates position', () {
      final original = MindMapNode(
        id: 'node-001',
        mindMapId: 'mm-001',
        positionX: 0.0,
        positionY: 0.0,
        content: const NodeContent(),
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
      );

      final updated = original.copyWith(
        positionX: 100.0,
        positionY: 200.0,
        modifiedAt: DateTime(2026, 5, 30, 12),
      );

      expect(updated.id, 'node-001'); // unchanged
      expect(updated.positionX, 100.0);
      expect(updated.positionY, 200.0);
      expect(updated.createdAt, DateTime(2026, 5, 30)); // unchanged
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/domain/mind_map_node_test.dart`
Expected: FAIL - MindMapNode/NodeContent class not found

- [ ] **Step 3: 实现 MindMapNode 实体类**

```dart
// lib/src/mindmap/domain/mind_map_node.dart

import 'dart:convert';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';

/// 节点内容。
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

  /// 从 JSON Map 创建。
  factory NodeContent.fromJson(Map<String, dynamic> json) {
    return NodeContent(
      text: json['text'] as String?,
      imageRefs: (json['image_refs'] as List?)
              ?.map((e) => e as String)
              .toList() ?? const [],
      inkStrokes: (json['ink_strokes'] as List?)
              ?.map((s) => InkStroke.fromJson(Map<String, dynamic>.from(s)))
              .toList() ?? const [],
      sourceLink: json['source_link'] != null
          ? SourceLink.fromMap(Map<String, dynamic>.from(json['source_link']))
          : null,
    );
  }

  /// 转换为 JSON Map。
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (text != null) map['text'] = text;
    if (imageRefs.isNotEmpty) map['image_refs'] = imageRefs;
    if (inkStrokes.isNotEmpty) {
      map['ink_strokes'] = inkStrokes.map((s) => s.toJson()).toList();
    }
    if (sourceLink != null) {
      // Store as map (snake_case) for consistency with database
      map['source_link'] = sourceLink!.toMap();
    }
    return map;
  }

  NodeContent copyWith({
    String? text,
    List<String>? imageRefs,
    List<InkStroke>? inkStrokes,
    SourceLink? sourceLink,
  }) {
    return NodeContent(
      text: text ?? this.text,
      imageRefs: imageRefs ?? this.imageRefs,
      inkStrokes: inkStrokes ?? this.inkStrokes,
      sourceLink: sourceLink ?? this.sourceLink,
    );
  }
}

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

  /// 从数据库 Map 创建。
  factory MindMapNode.fromMap(Map<String, dynamic> map) {
    NodeContent content = const NodeContent();
    if (map['content_json'] != null) {
      final contentJson = jsonDecode(map['content_json'] as String)
          as Map<String, dynamic>;
      content = NodeContent.fromJson(contentJson);
    }

    return MindMapNode(
      id: map['id'] as String,
      mindMapId: map['mind_map_id'] as String,
      parentId: map['parent_id'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      positionX: (map['position_x'] as num?)?.toDouble() ?? 0,
      positionY: (map['position_y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 160,
      height: (map['height'] as num?)?.toDouble() ?? 80,
      colorHex: map['color_hex'] as String? ?? '#FFFFFF',
      isCollapsed: (map['is_collapsed'] as int?) == 1,
      content: content,
      createdAt: DateTime.parse(map['created_at'] as String),
      modifiedAt: DateTime.parse(map['modified_at'] as String),
    );
  }

  /// 转换为数据库 Map。
  Map<String, dynamic> toMap() => {
        'id': id,
        'mind_map_id': mindMapId,
        'parent_id': parentId,
        'sort_order': sortOrder,
        'position_x': positionX,
        'position_y': positionY,
        'width': width,
        'height': height,
        'color_hex': colorHex,
        'is_collapsed': isCollapsed ? 1 : 0,
        'content_json': jsonEncode(content.toJson()),
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
      };

  /// 复制并更新指定字段。
  MindMapNode copyWith({
    String? parentId,
    int? sortOrder,
    double? positionX,
    double? positionY,
    double? width,
    double? height,
    String? colorHex,
    bool? isCollapsed,
    NodeContent? content,
    DateTime? modifiedAt,
  }) {
    return MindMapNode(
      id: id,
      mindMapId: mindMapId,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      width: width ?? this.width,
      height: height ?? this.height,
      colorHex: colorHex ?? this.colorHex,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      content: content ?? this.content,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  int get hashCode =>
      id.hashCode ^
      mindMapId.hashCode ^
      parentId.hashCode ^
      sortOrder.hashCode ^
      positionX.hashCode ^
      positionY.hashCode ^
      width.hashCode ^
      height.hashCode ^
      colorHex.hashCode ^
      isCollapsed.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      modifiedAt.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindMapNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          mindMapId == other.mindMapId &&
          parentId == other.parentId &&
          sortOrder == other.sortOrder &&
          positionX == other.positionX &&
          positionY == other.positionY &&
          width == other.width &&
          height == other.height &&
          colorHex == other.colorHex &&
          isCollapsed == other.isCollapsed &&
          content == other.content &&
          createdAt == other.createdAt &&
          modifiedAt == other.modifiedAt;

  @override
  String toString() =>
      'MindMapNode(id: $id, mindMapId: $mindMapId, position: ($positionX, $positionY))';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/domain/mind_map_node_test.dart`
Expected: All 6 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/domain/mind_map_node.dart test/mindmap/domain/mind_map_node_test.dart
git commit -m "feat(mindmap): add MindMapNode and NodeContent entities with tests"
```

---

## Task 5: 实现 MindMapEdge 实体类

**Files:**
- Create: `lib/src/mindmap/domain/mind_map_edge.dart`
- Test: `test/mindmap/domain/mind_map_edge_test.dart`

- [ ] **Step 1: 编写 MindMapEdge 测试**

```dart
// test/mindmap/domain/mind_map_edge_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/edge_type.dart';

void main() {
  group('MindMapEdge', () {
    test('fromMap creates valid MindMapEdge', () {
      final map = {
        'id': 'edge-001',
        'mind_map_id': 'mm-001',
        'source_node_id': 'node-a',
        'target_node_id': 'node-b',
        'edge_type': 'free',
        'label': 'relationship',
        'color_hex': '#FF5733',
        'created_at': '2026-05-30T10:00:00Z',
      };

      final edge = MindMapEdge.fromMap(map);

      expect(edge.id, 'edge-001');
      expect(edge.mindMapId, 'mm-001');
      expect(edge.sourceNodeId, 'node-a');
      expect(edge.targetNodeId, 'node-b');
      expect(edge.edgeType, EdgeType.free);
      expect(edge.label, 'relationship');
      expect(edge.colorHex, '#FF5733');
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 'edge-002',
        'mind_map_id': 'mm-001',
        'source_node_id': 'node-a',
        'target_node_id': 'node-b',
        'edge_type': 'free',
        'created_at': '2026-05-30T10:00:00Z',
      };

      final edge = MindMapEdge.fromMap(map);

      expect(edge.label, isNull);
      expect(edge.colorHex, isNull);
    });

    test('toMap produces valid map', () {
      final edge = MindMapEdge(
        id: 'edge-001',
        mindMapId: 'mm-001',
        sourceNodeId: 'node-a',
        targetNodeId: 'node-b',
        edgeType: EdgeType.free,
        label: 'relationship',
        colorHex: '#FF5733',
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
      );

      final map = edge.toMap();

      expect(map['id'], 'edge-001');
      expect(map['mind_map_id'], 'mm-001');
      expect(map['source_node_id'], 'node-a');
      expect(map['target_node_id'], 'node-b');
      expect(map['edge_type'], 'free');
      expect(map['label'], 'relationship');
      expect(map['color_hex'], '#FF5733');
    });

    test('default edgeType is free', () {
      final edge = MindMapEdge(
        id: 'edge-001',
        mindMapId: 'mm-001',
        sourceNodeId: 'node-a',
        targetNodeId: 'node-b',
        createdAt: DateTime(2026, 5, 30),
      );

      expect(edge.edgeType, EdgeType.free);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/domain/mind_map_edge_test.dart`
Expected: FAIL - MindMapEdge class not found

- [ ] **Step 3: 实现 MindMapEdge 实体类**

```dart
// lib/src/mindmap/domain/mind_map_edge.dart

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

  /// 从数据库 Map 创建。
  factory MindMapEdge.fromMap(Map<String, dynamic> map) {
    return MindMapEdge(
      id: map['id'] as String,
      mindMapId: map['mind_map_id'] as String,
      sourceNodeId: map['source_node_id'] as String,
      targetNodeId: map['target_node_id'] as String,
      edgeType: EdgeType.values.firstWhere(
        (e) => e.name == (map['edge_type'] as String? ?? 'free'),
        orElse: () => EdgeType.free,
      ),
      label: map['label'] as String?,
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// 转换为数据库 Map。
  Map<String, dynamic> toMap() => {
        'id': id,
        'mind_map_id': mindMapId,
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'edge_type': edgeType.name,
        'label': label,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  int get hashCode =>
      id.hashCode ^
      mindMapId.hashCode ^
      sourceNodeId.hashCode ^
      targetNodeId.hashCode ^
      edgeType.hashCode ^
      label.hashCode ^
      colorHex.hashCode ^
      createdAt.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindMapEdge &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          mindMapId == other.mindMapId &&
          sourceNodeId == other.sourceNodeId &&
          targetNodeId == other.targetNodeId &&
          edgeType == other.edgeType &&
          label == other.label &&
          colorHex == other.colorHex &&
          createdAt == other.createdAt;

  @override
  String toString() =>
      'MindMapEdge(id: $id, source: $sourceNodeId → target: $targetNodeId, type: $edgeType)';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/domain/mind_map_edge_test.dart`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/domain/mind_map_edge.dart test/mindmap/domain/mind_map_edge_test.dart
git commit -m "feat(mindmap): add MindMapEdge entity with tests"
```

---

## Task 6: 扩展 Rust 存储层 - 表结构

**Files:**
- Modify: `rust/src/storage/db.rs`
- Modify: `rust/src/storage/mod.rs`

- [ ] **Step 1: 添加 MindMap 表创建 DDL**

在 `rust/src/storage/db.rs` 的 `init_db` 函数中，在现有表创建之后添加：

```rust
// rust/src/storage/db.rs
// 在 init_db 函数中，annotations 表创建之后添加：

    // Create mind_maps table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS mind_maps (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            folder_id TEXT,
            root_node_id TEXT,
            layout_mode TEXT NOT NULL DEFAULT 'freeform',
            is_trashed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE SET NULL
        );",
        [],
    ).map_err(|e| format!("Failed to create mind_maps table: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_mind_maps_folder ON mind_maps(folder_id);",
        [],
    ).map_err(|e| format!("Failed to create mind_maps folder index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_mind_maps_trashed ON mind_maps(is_trashed);",
        [],
    ).map_err(|e| format!("Failed to create mind_maps trashed index: {}", e))?;

    // Create mind_map_nodes table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS mind_map_nodes (
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
            FOREIGN KEY(mind_map_id) REFERENCES mind_maps(id) ON DELETE CASCADE,
            FOREIGN KEY(parent_id) REFERENCES mind_map_nodes(id) ON DELETE SET NULL
        );",
        [],
    ).map_err(|e| format!("Failed to create mind_map_nodes table: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_nodes_mind_map ON mind_map_nodes(mind_map_id);",
        [],
    ).map_err(|e| format!("Failed to create nodes mind_map index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_nodes_parent ON mind_map_nodes(parent_id);",
        [],
    ).map_err(|e| format!("Failed to create nodes parent index: {}", e))?;

    // Create source_links table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS source_links (
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
            FOREIGN KEY(node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
            FOREIGN KEY(annotation_id) REFERENCES annotations(id) ON DELETE SET NULL
        );",
        [],
    ).map_err(|e| format!("Failed to create source_links table: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_source_links_node ON source_links(node_id);",
        [],
    ).map_err(|e| format!("Failed to create source_links node index: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_source_links_document ON source_links(document_id);",
        [],
    ).map_err(|e| format!("Failed to create source_links document index: {}", e))?;

    // Create mind_map_edges table (free edges only)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS mind_map_edges (
            id TEXT PRIMARY KEY,
            mind_map_id TEXT NOT NULL,
            source_node_id TEXT NOT NULL,
            target_node_id TEXT NOT NULL,
            edge_type TEXT NOT NULL DEFAULT 'free',
            label TEXT,
            color_hex TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY(mind_map_id) REFERENCES mind_maps(id) ON DELETE CASCADE,
            FOREIGN KEY(source_node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE,
            FOREIGN KEY(target_node_id) REFERENCES mind_map_nodes(id) ON DELETE CASCADE
        );",
        [],
    ).map_err(|e| format!("Failed to create mind_map_edges table: {}", e))?;

    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_edges_mind_map ON mind_map_edges(mind_map_id);",
        [],
    ).map_err(|e| format!("Failed to create edges mind_map index: {}", e))?;
```

- [ ] **Step 2: 更新 `mod.rs` 引入新模块**

```rust
// rust/src/storage/mod.rs

pub mod db;
pub mod folders;
pub mod tags;
pub mod documents;
pub mod annotations;
pub mod mind_maps;
pub mod mind_map_nodes;
pub mod mind_map_edges;
pub mod source_links;
```

- [ ] **Step 3: 运行 Rust 编译验证**

Run: `cd rust && cargo check`
Expected: No errors (modules will be added in next tasks)

- [ ] **Step 4: Commit**

```bash
git add rust/src/storage/db.rs rust/src/storage/mod.rs
git commit -m "feat(mindmap): add MindMap SQLite tables and module declarations"
```

---

## Task 7: 实现 Rust MindMap CRUD

**Files:**
- Create: `rust/src/storage/mind_maps.rs`

- [ ] **Step 1: 创建 `mind_maps.rs`**

```rust
// rust/src/storage/mind_maps.rs

use crate::storage::db::with_db;
use uuid::Uuid;

/// MindMap record for FFI.
#[derive(Debug, Clone)]
pub struct MindMapRecord {
    pub id: String,
    pub title: String,
    pub folder_id: Option<String>,
    pub root_node_id: Option<String>,
    pub layout_mode: String,
    pub is_trashed: bool,
    pub created_at: String,
    pub modified_at: String,
}

/// Creates a new mind map and returns its ID.
pub fn create_mind_map(
    title: String,
    folder_id: Option<String>,
    layout_mode: String,
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mind_maps (id, title, folder_id, layout_mode, created_at, modified_at) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6);",
            rusqlite::params![id, title, folder_id, layout_mode, now, now],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Gets a mind map by ID.
pub fn get_mind_map(id: String) -> Result<Option<MindMapRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, title, folder_id, root_node_id, layout_mode, is_trashed, created_at, modified_at 
             FROM mind_maps WHERE id = ?1;"
        )?;

        let result = stmt
            .query_row([&id], |row| {
                Ok(MindMapRecord {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    folder_id: row.get(2)?,
                    root_node_id: row.get(3)?,
                    layout_mode: row.get(4)?,
                    is_trashed: row.get::<_, i32>(5)? == 1,
                    created_at: row.get(6)?,
                    modified_at: row.get(7)?,
                })
            })
            .optional()?;

        Ok(result)
    })
}

/// Gets mind maps list with filters.
pub fn get_mind_maps(
    folder_id: Option<String>,
    search_query: Option<String>,
    sort_by: String,
    include_trashed: bool,
) -> Result<Vec<MindMapRecord>, String> {
    with_db(|conn| {
        let mut query_parts = vec![
            "SELECT id, title, folder_id, root_node_id, layout_mode, is_trashed, created_at, modified_at FROM mind_maps"
                .to_string(),
        ];
        let mut filters = vec![];
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = vec![];

        // Exclude trashed by default
        if !include_trashed {
            filters.push("is_trashed = 0".to_string());
        }

        // Folder filter
        if let Some(ref f_id) = folder_id {
            if f_id == "unclassified" {
                filters.push("folder_id IS NULL".to_string());
            } else if !f_id.is_empty() && f_id != "all" {
                filters.push("folder_id = ?".to_string());
                params.push(Box::new(f_id.clone()));
            }
        }

        // Search query
        if let Some(ref search) = search_query {
            if !search.is_empty() {
                filters.push("title LIKE ?".to_string());
                params.push(Box::new(format!("%{}%", search)));
            }
        }

        if !filters.is_empty() {
            query_parts.push("WHERE".to_string());
            query_parts.push(filters.join(" AND "));
        }

        // Sorting
        let order_clause = match sort_by.as_str() {
            "name" => "ORDER BY title ASC",
            "created" => "ORDER BY created_at DESC",
            "modified" | _ => "ORDER BY modified_at DESC",
        };
        query_parts.push(order_clause.to_string());

        let final_query = query_parts.join(" ");
        let mut stmt = conn.prepare(&final_query)?;
        let params_refs: Vec<&dyn rusqlite::ToSql> =
            params.iter().map(|p| p.as_ref()).collect();

        let results = stmt
            .query_map(&params_refs[..], |row| {
                Ok(MindMapRecord {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    folder_id: row.get(2)?,
                    root_node_id: row.get(3)?,
                    layout_mode: row.get(4)?,
                    is_trashed: row.get::<_, i32>(5)? == 1,
                    created_at: row.get(6)?,
                    modified_at: row.get(7)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(results)
    })
}

/// Renames a mind map.
pub fn rename_mind_map(id: String, new_title: String) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    with_db(|conn| {
        conn.execute(
            "UPDATE mind_maps SET title = ?1, modified_at = ?2 WHERE id = ?3;",
            rusqlite::params![new_title, now, id],
        )?;
        Ok(())
    })
}

/// Moves mind map to another folder.
pub fn move_mind_map(id: String, new_folder_id: Option<String>) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    with_db(|conn| {
        conn.execute(
            "UPDATE mind_maps SET folder_id = ?1, modified_at = ?2 WHERE id = ?3;",
            rusqlite::params![new_folder_id, now, id],
        )?;
        Ok(())
    })
}

/// Trashes a mind map (soft delete).
pub fn trash_mind_map(id: String) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    with_db(|conn| {
        conn.execute(
            "UPDATE mind_maps SET is_trashed = 1, modified_at = ?1 WHERE id = ?2;",
            rusqlite::params![now, id],
        )?;
        Ok(())
    })
}

/// Permanently deletes a mind map.
pub fn delete_mind_map(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mind_maps WHERE id = ?1;", [&id])?;
        Ok(())
    })
}
```

- [ ] **Step 2: 添加 chrono 依赖**

在 `rust/Cargo.toml` 的 `[dependencies]` 中添加（如果不存在）：

```toml
chrono = "0.4"
```

- [ ] **Step 3: 运行 Rust 编译验证**

Run: `cd rust && cargo check`
Expected: Compiles successfully

- [ ] **Step 4: Commit**

```bash
git add rust/src/storage/mind_maps.rs rust/Cargo.toml
git commit -m "feat(mindmap): add Rust MindMap CRUD operations"
```

---

## Task 8: 实现 Rust MindMapNode CRUD

**Files:**
- Create: `rust/src/storage/mind_map_nodes.rs`

- [ ] **Step 1: 创建 `mind_map_nodes.rs`**

```rust
// rust/src/storage/mind_map_nodes.rs

use crate::storage::db::with_db;
use uuid::Uuid;

/// MindMapNode record for FFI.
#[derive(Debug, Clone)]
pub struct MindMapNodeRecord {
    pub id: String,
    pub mind_map_id: String,
    pub parent_id: Option<String>,
    pub sort_order: i32,
    pub position_x: f64,
    pub position_y: f64,
    pub width: f64,
    pub height: f64,
    pub color_hex: String,
    pub is_collapsed: bool,
    pub content_json: Option<String>,
    pub created_at: String,
    pub modified_at: String,
}

/// Creates a mind map node.
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
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mind_map_nodes (id, mind_map_id, parent_id, sort_order, position_x, position_y, width, height, color_hex, content_json, created_at, modified_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12);",
            rusqlite::params![
                id,
                mind_map_id,
                parent_id,
                sort_order,
                position_x,
                position_y,
                width,
                height,
                color_hex,
                content_json,
                now,
                now
            ],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Gets all nodes for a mind map.
pub fn get_mind_map_nodes(mind_map_id: String) -> Result<Vec<MindMapNodeRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, mind_map_id, parent_id, sort_order, position_x, position_y, width, height, color_hex, is_collapsed, content_json, created_at, modified_at
             FROM mind_map_nodes WHERE mind_map_id = ?1 ORDER BY sort_order;"
        )?;

        let nodes = stmt
            .query_map([&mind_map_id], |row| {
                Ok(MindMapNodeRecord {
                    id: row.get(0)?,
                    mind_map_id: row.get(1)?,
                    parent_id: row.get(2)?,
                    sort_order: row.get(3)?,
                    position_x: row.get(4)?,
                    position_y: row.get(5)?,
                    width: row.get(6)?,
                    height: row.get(7)?,
                    color_hex: row.get(8)?,
                    is_collapsed: row.get::<_, i32>(9)? == 1,
                    content_json: row.get(10)?,
                    created_at: row.get(11)?,
                    modified_at: row.get(12)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(nodes)
    })
}

/// Updates a mind map node.
pub fn update_mind_map_node(
    id: String,
    position_x: Option<f64>,
    position_y: Option<f64>,
    width: Option<f64>,
    height: Option<f64>,
    color_hex: Option<String>,
    is_collapsed: Option<bool>,
    content_json: Option<String>,
) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    with_db(|conn| {
        // Build dynamic update query
        let mut updates = vec!["modified_at = ?".to_string()];
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = vec![Box::new(now.clone())];
        let mut param_idx = 2;

        if let Some(px) = position_x {
            updates.push(format!("position_x = ?{}", param_idx));
            params.push(Box::new(px));
            param_idx += 1;
        }
        if let Some(py) = position_y {
            updates.push(format!("position_y = ?{}", param_idx));
            params.push(Box::new(py));
            param_idx += 1;
        }
        if let Some(w) = width {
            updates.push(format!("width = ?{}", param_idx));
            params.push(Box::new(w));
            param_idx += 1;
        }
        if let Some(h) = height {
            updates.push(format!("height = ?{}", param_idx));
            params.push(Box::new(h));
            param_idx += 1;
        }
        if let Some(c) = color_hex {
            updates.push(format!("color_hex = ?{}", param_idx));
            params.push(Box::new(c));
            param_idx += 1;
        }
        if let Some(collapsed) = is_collapsed {
            updates.push(format!("is_collapsed = ?{}", param_idx));
            params.push(Box::new(if collapsed { 1 } else { 0 }));
            param_idx += 1;
        }
        if let Some(content) = content_json {
            updates.push(format!("content_json = ?{}", param_idx));
            params.push(Box::new(content));
        }

        params.push(Box::new(id.clone()));
        let query = format!(
            "UPDATE mind_map_nodes SET {} WHERE id = ?{};",
            updates.join(", "),
            param_idx
        );

        let params_refs: Vec<&dyn rusqlite::ToSql> =
            params.iter().map(|p| p.as_ref()).collect();
        conn.execute(&query, &params_refs[..])?;
        Ok(())
    })
}

/// Moves a node to a new parent.
pub fn move_mind_map_node(
    node_id: String,
    new_parent_id: Option<String>,
    sort_order: i32,
) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    with_db(|conn| {
        conn.execute(
            "UPDATE mind_map_nodes SET parent_id = ?1, sort_order = ?2, modified_at = ?3 WHERE id = ?4;",
            rusqlite::params![new_parent_id, sort_order, now, node_id],
        )?;
        Ok(())
    })
}

/// Deletes a mind map node.
pub fn delete_mind_map_node(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mind_map_nodes WHERE id = ?1;", [&id])?;
        Ok(())
    })
}
```

- [ ] **Step 2: 运行 Rust 编译验证**

Run: `cd rust && cargo check`
Expected: Compiles successfully

- [ ] **Step 3: Commit**

```bash
git add rust/src/storage/mind_map_nodes.rs
git commit -m "feat(mindmap): add Rust MindMapNode CRUD operations"
```

---

## Task 9: 实现 Rust SourceLink + MindMapEdge CRUD

**Files:**
- Create: `rust/src/storage/source_links.rs`
- Create: `rust/src/storage/mind_map_edges.rs`

- [ ] **Step 1: 创建 `source_links.rs`**

```rust
// rust/src/storage/source_links.rs

use crate::storage::db::with_db;
use uuid::Uuid;

/// SourceLink record for FFI.
#[derive(Debug, Clone)]
pub struct SourceLinkRecord {
    pub id: String,
    pub node_id: String,
    pub document_id: String,
    pub document_title: String,
    pub page_index: i32,
    pub start_char_index: Option<i32>,
    pub end_char_index: Option<i32>,
    pub selected_text: Option<String>,
    pub annotation_id: Option<String>,
    pub created_at: String,
}

/// Creates a source link.
pub fn create_source_link(
    node_id: String,
    document_id: String,
    document_title: String,
    page_index: i32,
    start_char_index: Option<i32>,
    end_char_index: Option<i32>,
    selected_text: Option<String>,
    annotation_id: Option<String>,
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    with_db(|conn| {
        conn.execute(
            "INSERT INTO source_links (id, node_id, document_id, document_title, page_index, start_char_index, end_char_index, selected_text, annotation_id, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10);",
            rusqlite::params![
                id,
                node_id,
                document_id,
                document_title,
                page_index,
                start_char_index,
                end_char_index,
                selected_text,
                annotation_id,
                now
            ],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Gets source link by node ID.
pub fn get_source_link_by_node(node_id: String) -> Result<Option<SourceLinkRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, node_id, document_id, document_title, page_index, start_char_index, end_char_index, selected_text, annotation_id, created_at
             FROM source_links WHERE node_id = ?1;"
        )?;

        let result = stmt
            .query_row([&node_id], |row| {
                Ok(SourceLinkRecord {
                    id: row.get(0)?,
                    node_id: row.get(1)?,
                    document_id: row.get(2)?,
                    document_title: row.get(3)?,
                    page_index: row.get(4)?,
                    start_char_index: row.get(5)?,
                    end_char_index: row.get(6)?,
                    selected_text: row.get(7)?,
                    annotation_id: row.get(8)?,
                    created_at: row.get(9)?,
                })
            })
            .optional()?;

        Ok(result)
    })
}

/// Gets source links by document ID.
pub fn get_source_links_by_document(document_id: String) -> Result<Vec<SourceLinkRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, node_id, document_id, document_title, page_index, start_char_index, end_char_index, selected_text, annotation_id, created_at
             FROM source_links WHERE document_id = ?1 ORDER BY page_index, created_at;"
        )?;

        let links = stmt
            .query_map([&document_id], |row| {
                Ok(SourceLinkRecord {
                    id: row.get(0)?,
                    node_id: row.get(1)?,
                    document_id: row.get(2)?,
                    document_title: row.get(3)?,
                    page_index: row.get(4)?,
                    start_char_index: row.get(5)?,
                    end_char_index: row.get(6)?,
                    selected_text: row.get(7)?,
                    annotation_id: row.get(8)?,
                    created_at: row.get(9)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(links)
    })
}

/// Deletes a source link.
pub fn delete_source_link(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM source_links WHERE id = ?1;", [&id])?;
        Ok(())
    })
}
```

- [ ] **Step 2: 创建 `mind_map_edges.rs`**

```rust
// rust/src/storage/mind_map_edges.rs

use crate::storage::db::with_db;
use uuid::Uuid;

/// MindMapEdge record for FFI.
#[derive(Debug, Clone)]
pub struct MindMapEdgeRecord {
    pub id: String,
    pub mind_map_id: String,
    pub source_node_id: String,
    pub target_node_id: String,
    pub edge_type: String,
    pub label: Option<String>,
    pub color_hex: Option<String>,
    pub created_at: String,
}

/// Creates a free edge.
pub fn create_mind_map_edge(
    mind_map_id: String,
    source_node_id: String,
    target_node_id: String,
    label: Option<String>,
    color_hex: Option<String>,
) -> Result<String, String> {
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    with_db(|conn| {
        conn.execute(
            "INSERT INTO mind_map_edges (id, mind_map_id, source_node_id, target_node_id, edge_type, label, color_hex, created_at)
             VALUES (?1, ?2, ?3, ?4, 'free', ?5, ?6, ?7);",
            rusqlite::params![id, mind_map_id, source_node_id, target_node_id, label, color_hex, now],
        )?;
        Ok(())
    })?;

    Ok(id)
}

/// Gets free edges for a mind map.
pub fn get_mind_map_free_edges(mind_map_id: String) -> Result<Vec<MindMapEdgeRecord>, String> {
    with_db(|conn| {
        let mut stmt = conn.prepare(
            "SELECT id, mind_map_id, source_node_id, target_node_id, edge_type, label, color_hex, created_at
             FROM mind_map_edges WHERE mind_map_id = ?1 AND edge_type = 'free';"
        )?;

        let edges = stmt
            .query_map([&mind_map_id], |row| {
                Ok(MindMapEdgeRecord {
                    id: row.get(0)?,
                    mind_map_id: row.get(1)?,
                    source_node_id: row.get(2)?,
                    target_node_id: row.get(3)?,
                    edge_type: row.get(4)?,
                    label: row.get(5)?,
                    color_hex: row.get(6)?,
                    created_at: row.get(7)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(edges)
    })
}

/// Deletes a free edge.
pub fn delete_mind_map_edge(id: String) -> Result<(), String> {
    with_db(|conn| {
        conn.execute("DELETE FROM mind_map_edges WHERE id = ?1;", [&id])?;
        Ok(())
    })
}
```

- [ ] **Step 3: 运行 Rust 编译验证**

Run: `cd rust && cargo check`
Expected: Compiles successfully

- [ ] **Step 4: Commit**

```bash
git add rust/src/storage/source_links.rs rust/src/storage/mind_map_edges.rs
git commit -m "feat(mindmap): add Rust SourceLink and MindMapEdge CRUD operations"
```

---

## Task 10: 导出 Rust FFI 函数

**Files:**
- Modify: `rust/src/api/storage.rs`

- [ ] **Step 1: 添加 FFI 导出**

在 `rust/src/api/storage.rs` 文件末尾添加：

```rust
// rust/src/api/storage.rs
// 在文件末尾添加：

// Re-export MindMap storage structures
pub use crate::storage::mind_maps::MindMapRecord;
pub use crate::storage::mind_map_nodes::MindMapNodeRecord;
pub use crate::storage::mind_map_edges::MindMapEdgeRecord;
pub use crate::storage::source_links::SourceLinkRecord;

// ============== MindMap APIs ==============

/// Creates a new mind map and returns its ID.
pub fn create_mind_map(
    title: String,
    folder_id: Option<String>,
    layout_mode: String,
) -> Result<String, String> {
    crate::storage::mind_maps::create_mind_map(title, folder_id, layout_mode)
}

/// Gets a mind map by ID.
pub fn get_mind_map(id: String) -> Result<Option<MindMapRecord>, String> {
    crate::storage::mind_maps::get_mind_map(id)
}

/// Gets mind maps list with filters.
pub fn get_mind_maps(
    folder_id: Option<String>,
    search_query: Option<String>,
    sort_by: String,
    include_trashed: bool,
) -> Result<Vec<MindMapRecord>, String> {
    crate::storage::mind_maps::get_mind_maps(folder_id, search_query, sort_by, include_trashed)
}

/// Renames a mind map.
pub fn rename_mind_map(id: String, new_title: String) -> Result<(), String> {
    crate::storage::mind_maps::rename_mind_map(id, new_title)
}

/// Moves mind map to another folder.
pub fn move_mind_map(id: String, new_folder_id: Option<String>) -> Result<(), String> {
    crate::storage::mind_maps::move_mind_map(id, new_folder_id)
}

/// Trashes a mind map (soft delete).
pub fn trash_mind_map(id: String) -> Result<(), String> {
    crate::storage::mind_maps::trash_mind_map(id)
}

/// Permanently deletes a mind map.
pub fn delete_mind_map(id: String) -> Result<(), String> {
    crate::storage::mind_maps::delete_mind_map(id)
}

// ============== MindMapNode APIs ==============

/// Creates a mind map node.
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
) -> Result<String, String> {
    crate::storage::mind_map_nodes::create_mind_map_node(
        mind_map_id,
        parent_id,
        sort_order,
        position_x,
        position_y,
        width,
        height,
        color_hex,
        content_json,
    )
}

/// Gets all nodes for a mind map.
pub fn get_mind_map_nodes(mind_map_id: String) -> Result<Vec<MindMapNodeRecord>, String> {
    crate::storage::mind_map_nodes::get_mind_map_nodes(mind_map_id)
}

/// Updates a mind map node.
pub fn update_mind_map_node(
    id: String,
    position_x: Option<f64>,
    position_y: Option<f64>,
    width: Option<f64>,
    height: Option<f64>,
    color_hex: Option<String>,
    is_collapsed: Option<bool>,
    content_json: Option<String>,
) -> Result<(), String> {
    crate::storage::mind_map_nodes::update_mind_map_node(
        id,
        position_x,
        position_y,
        width,
        height,
        color_hex,
        is_collapsed,
        content_json,
    )
}

/// Moves a node to a new parent.
pub fn move_mind_map_node(
    node_id: String,
    new_parent_id: Option<String>,
    sort_order: i32,
) -> Result<(), String> {
    crate::storage::mind_map_nodes::move_mind_map_node(node_id, new_parent_id, sort_order)
}

/// Deletes a mind map node.
pub fn delete_mind_map_node(id: String) -> Result<(), String> {
    crate::storage::mind_map_nodes::delete_mind_map_node(id)
}

// ============== SourceLink APIs ==============

/// Creates a source link.
pub fn create_source_link(
    node_id: String,
    document_id: String,
    document_title: String,
    page_index: i32,
    start_char_index: Option<i32>,
    end_char_index: Option<i32>,
    selected_text: Option<String>,
    annotation_id: Option<String>,
) -> Result<String, String> {
    crate::storage::source_links::create_source_link(
        node_id,
        document_id,
        document_title,
        page_index,
        start_char_index,
        end_char_index,
        selected_text,
        annotation_id,
    )
}

/// Gets source link by node ID.
pub fn get_source_link_by_node(node_id: String) -> Result<Option<SourceLinkRecord>, String> {
    crate::storage::source_links::get_source_link_by_node(node_id)
}

/// Gets source links by document ID.
pub fn get_source_links_by_document(document_id: String) -> Result<Vec<SourceLinkRecord>, String> {
    crate::storage::source_links::get_source_links_by_document(document_id)
}

/// Deletes a source link.
pub fn delete_source_link(id: String) -> Result<(), String> {
    crate::storage::source_links::delete_source_link(id)
}

// ============== MindMapEdge APIs ==============

/// Creates a free edge.
pub fn create_mind_map_edge(
    mind_map_id: String,
    source_node_id: String,
    target_node_id: String,
    label: Option<String>,
    color_hex: Option<String>,
) -> Result<String, String> {
    crate::storage::mind_map_edges::create_mind_map_edge(
        mind_map_id,
        source_node_id,
        target_node_id,
        label,
        color_hex,
    )
}

/// Gets free edges for a mind map.
pub fn get_mind_map_free_edges(mind_map_id: String) -> Result<Vec<MindMapEdgeRecord>, String> {
    crate::storage::mind_map_edges::get_mind_map_free_edges(mind_map_id)
}

/// Deletes a free edge.
pub fn delete_mind_map_edge(id: String) -> Result<(), String> {
    crate::storage::mind_map_edges::delete_mind_map_edge(id)
}
```

- [ ] **Step 2: 运行 Rust 编译验证**

Run: `cd rust && cargo build`
Expected: Compiles successfully

- [ ] **Step 3: 重新生成 Flutter Rust Bridge**

Run: `flutter_rust_bridge_codegen generate`
Expected: FFI Dart files generated in `lib/src/rust/storage/`

- [ ] **Step 4: Commit**

```bash
git add rust/src/api/storage.rs
git commit -m "feat(mindmap): export MindMap FFI functions"
```

---

## Task 11: 实现 Dart MindMapRepository 接口

**Files:**
- Create: `lib/src/mindmap/storage/mind_map_repository.dart`

- [ ] **Step 1: 创建抽象仓库接口**

```dart
// lib/src/mindmap/storage/mind_map_repository.dart

import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';

/// MindMap 存储操作接口。
/// 实现类：FfiMindMapRepository（生产）和 InMemoryMindMapRepository（测试）。
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
    String? searchQuery,
    String sortBy = 'modified',
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

- [ ] **Step 2: 运行静态分析验证**

Run: `dart analyze lib/src/mindmap/storage/`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/src/mindmap/storage/mind_map_repository.dart
git commit -m "feat(mindmap): add MindMapRepository abstract interface"
```

---

## Task 12: 实现 InMemoryMindMapRepository（测试用）

**Files:**
- Create: `lib/src/mindmap/storage/in_memory_mind_map_repository.dart`
- Test: `test/mindmap/storage/mind_map_repository_test.dart`

- [ ] **Step 1: 编写仓库测试**

```dart
// test/mindmap/storage/mind_map_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mind_map_repository.dart';

void main() {
  late InMemoryMindMapRepository repository;

  setUp(() {
    repository = InMemoryMindMapRepository();
  });

  group('MindMap CRUD', () {
    test('createMindMap returns valid ID', () async {
      final id = await repository.createMindMap(
        title: 'Test MindMap',
        folderId: 'folder-001',
      );

      expect(id, isNotEmpty);
      expect(id.startsWith('mm-'), true);
    });

    test('getMindMap returns created mind map', () async {
      final id = await repository.createMindMap(
        title: 'Test MindMap',
        layoutMode: LayoutMode.tree,
      );

      final mindMap = await repository.getMindMap(id);

      expect(mindMap, isNotNull);
      expect(mindMap!.title, 'Test MindMap');
      expect(mindMap.layoutMode, LayoutMode.tree);
    });

    test('getMindMap returns null for unknown ID', () async {
      final mindMap = await repository.getMindMap('unknown-id');
      expect(mindMap, isNull);
    });

    test('getMindMaps returns filtered list', () async {
      await repository.createMindMap(title: 'Map A', folderId: 'folder-001');
      await repository.createMindMap(title: 'Map B', folderId: 'folder-002');
      await repository.createMindMap(title: 'Map C', folderId: 'folder-001');

      final maps = await repository.getMindMaps(folderId: 'folder-001');

      expect(maps.length, 2);
      expect(maps.every((m) => m.folderId == 'folder-001'), true);
    });

    test('renameMindMap updates title', () async {
      final id = await repository.createMindMap(title: 'Old Title');

      await repository.renameMindMap(id, 'New Title');

      final mindMap = await repository.getMindMap(id);
      expect(mindMap!.title, 'New Title');
    });

    test('trashMindMap marks as trashed', () async {
      final id = await repository.createMindMap(title: 'Test');

      await repository.trashMindMap(id);

      final mindMap = await repository.getMindMap(id);
      expect(mindMap!.isTrashed, true);

      // Not included in normal list
      final maps = await repository.getMindMaps();
      expect(maps.every((m) => !m.isTrashed), true);
    });

    test('deleteMindMap removes permanently', () async {
      final id = await repository.createMindMap(title: 'Test');

      await repository.deleteMindMap(id);

      final mindMap = await repository.getMindMap(id);
      expect(mindMap, isNull);
    });
  });

  group('MindMapNode CRUD', () {
    late String mindMapId;

    setUp(() async {
      mindMapId = await repository.createMindMap(title: 'Test');
    });

    test('createNode returns valid ID', () async {
      final id = await repository.createNode(
        MindMapNode(
          id: 'test-id',
          mindMapId: mindMapId,
          content: const NodeContent(text: 'Node content'),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      expect(id, isNotEmpty);
    });

    test('getNodes returns all nodes for mind map', () async {
      await repository.createNode(
        MindMapNode(
          id: 'node-1',
          mindMapId: mindMapId,
          content: const NodeContent(text: 'A'),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );
      await repository.createNode(
        MindMapNode(
          id: 'node-2',
          mindMapId: mindMapId,
          content: const NodeContent(text: 'B'),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      final nodes = await repository.getNodes(mindMapId);

      expect(nodes.length, 2);
    });

    test('updateNode updates position', () async {
      final id = await repository.createNode(
        MindMapNode(
          id: 'test-id',
          mindMapId: mindMapId,
          positionX: 0,
          positionY: 0,
          content: const NodeContent(),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      await repository.updateNode(
        MindMapNode(
          id: id,
          mindMapId: mindMapId,
          positionX: 100,
          positionY: 200,
          content: const NodeContent(),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      final nodes = await repository.getNodes(mindMapId);
      expect(nodes.first.positionX, 100);
      expect(nodes.first.positionY, 200);
    });

    test('deleteNode removes node', () async {
      final id = await repository.createNode(
        MindMapNode(
          id: 'test-id',
          mindMapId: mindMapId,
          content: const NodeContent(),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      await repository.deleteNode(id);

      final nodes = await repository.getNodes(mindMapId);
      expect(nodes.isEmpty, true);
    });
  });

  group('SourceLink CRUD', () {
    late String nodeId;
    late String mindMapId;

    setUp(() async {
      mindMapId = await repository.createMindMap(title: 'Test');
      nodeId = await repository.createNode(
        MindMapNode(
          id: 'test-id',
          mindMapId: mindMapId,
          content: const NodeContent(),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );
    });

    test('createSourceLink returns valid ID', () async {
      final id = await repository.createSourceLink(
        SourceLink(
          id: 'test-id',
          nodeId: nodeId,
          documentId: 'doc-001',
          documentTitle: 'Test.pdf',
          pageIndex: 1,
          createdAt: DateTime.now(),
        ),
      );

      expect(id, isNotEmpty);
    });

    test('getSourceLinkByNode returns link', () async {
      await repository.createSourceLink(
        SourceLink(
          id: 'test-id',
          nodeId: nodeId,
          documentId: 'doc-001',
          documentTitle: 'Test.pdf',
          pageIndex: 1,
          createdAt: DateTime.now(),
        ),
      );

      final link = await repository.getSourceLinkByNode(nodeId);

      expect(link, isNotNull);
      expect(link!.documentId, 'doc-001');
    });

    test('getSourceLinksByDocument returns all links', () async {
      await repository.createSourceLink(
        SourceLink(
          id: 'link-1',
          nodeId: nodeId,
          documentId: 'doc-001',
          documentTitle: 'Test.pdf',
          pageIndex: 1,
          createdAt: DateTime.now(),
        ),
      );

      final links = await repository.getSourceLinksByDocument('doc-001');

      expect(links.length, 1);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/storage/mind_map_repository_test.dart`
Expected: FAIL - InMemoryMindMapRepository not found

- [ ] **Step 3: 实现 InMemoryMindMapRepository**

```dart
// lib/src/mindmap/storage/in_memory_mind_map_repository.dart

import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';
import 'package:starmind/src/mindmap/storage/mind_map_repository.dart';

/// In-memory adapter for testing and rapid prototyping.
class InMemoryMindMapRepository implements MindMapRepository {
  final Map<String, MindMap> _mindMaps = {};
  final Map<String, MindMapNode> _nodes = {};
  final Map<String, MindMapEdge> _edges = {};
  final Map<String, SourceLink> _sourceLinks = {};

  @override
  Future<String> createMindMap({
    required String title,
    String? folderId,
    LayoutMode layoutMode = LayoutMode.freeform,
  }) async {
    final id = 'mm-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    _mindMaps[id] = MindMap(
      id: id,
      title: title,
      folderId: folderId,
      layoutMode: layoutMode,
      createdAt: now,
      modifiedAt: now,
    );
    return id;
  }

  @override
  Future<MindMap?> getMindMap(String id) async {
    return _mindMaps[id];
  }

  @override
  Future<List<MindMap>> getMindMaps({
    String? folderId,
    String? searchQuery,
    String sortBy = 'modified',
    bool includeTrashed = false,
  }) async {
    var result = _mindMaps.values.toList();

    if (!includeTrashed) {
      result = result.where((m) => !m.isTrashed).toList();
    }

    if (folderId != null && folderId != 'all') {
      if (folderId == 'unclassified') {
        result = result.where((m) => m.folderId == null).toList();
      } else {
        result = result.where((m) => m.folderId == folderId).toList();
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result.where((m) => m.title.contains(searchQuery)).toList();
    }

    // Sort
    result.sort((a, b) {
      switch (sortBy) {
        case 'name':
          return a.title.compareTo(b.title);
        case 'created':
          return b.createdAt.compareTo(a.createdAt);
        case 'modified':
        default:
          return b.modifiedAt.compareTo(a.modifiedAt);
      }
    });

    return result;
  }

  @override
  Future<void> renameMindMap(String id, String newTitle) async {
    final old = _mindMaps[id];
    if (old != null) {
      _mindMaps[id] = old.copyWith(title: newTitle, modifiedAt: DateTime.now());
    }
  }

  @override
  Future<void> moveMindMap(String id, String? newFolderId) async {
    final old = _mindMaps[id];
    if (old != null) {
      _mindMaps[id] = old.copyWith(folderId: newFolderId, modifiedAt: DateTime.now());
    }
  }

  @override
  Future<void> trashMindMap(String id) async {
    final old = _mindMaps[id];
    if (old != null) {
      _mindMaps[id] = old.copyWith(isTrashed: true, modifiedAt: DateTime.now());
    }
  }

  @override
  Future<void> deleteMindMap(String id) async {
    _mindMaps.remove(id);
    // Cascade delete nodes
    _nodes.removeWhere((_, node) => node.mindMapId == id);
    // Cascade delete edges
    _edges.removeWhere((_, edge) => edge.mindMapId == id);
    // Cascade delete source links
    _sourceLinks.removeWhere((_, link) => _nodes[link.nodeId] == null);
  }

  @override
  Future<String> createNode(MindMapNode node) async {
    final id = node.id.isEmpty
        ? 'node-${DateTime.now().millisecondsSinceEpoch}'
        : node.id;
    _nodes[id] = node.copyWith(id: id);
    return id;
  }

  @override
  Future<List<MindMapNode>> getNodes(String mindMapId) async {
    return _nodes.values.where((n) => n.mindMapId == mindMapId).toList();
  }

  @override
  Future<void> updateNode(MindMapNode node) async {
    _nodes[node.id] = node.copyWith(modifiedAt: DateTime.now());
  }

  @override
  Future<void> deleteNode(String id) async {
    _nodes.remove(id);
    // Cascade delete source links
    _sourceLinks.removeWhere((_, link) => link.nodeId == id);
    // Update children to have null parent
    for (final entry in _nodes.entries) {
      if (entry.value.parentId == id) {
        _nodes[entry.key] = entry.value.copyWith(parentId: null);
      }
    }
  }

  @override
  Future<void> moveNode(String nodeId, String? newParentId, int sortOrder) async {
    final old = _nodes[nodeId];
    if (old != null) {
      _nodes[nodeId] = old.copyWith(
        parentId: newParentId,
        sortOrder: sortOrder,
        modifiedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<String> createEdge(MindMapEdge edge) async {
    final id = edge.id.isEmpty
        ? 'edge-${DateTime.now().millisecondsSinceEpoch}'
        : edge.id;
    _edges[id] = edge.copyWith(id: id);
    return id;
  }

  @override
  Future<List<MindMapEdge>> getFreeEdges(String mindMapId) async {
    return _edges.values
        .where((e) => e.mindMapId == mindMapId && e.edgeType == EdgeType.free)
        .toList();
  }

  @override
  Future<void> deleteEdge(String id) async {
    _edges.remove(id);
  }

  @override
  Future<String> createSourceLink(SourceLink link) async {
    final id = link.id.isEmpty
        ? 'sl-${DateTime.now().millisecondsSinceEpoch}'
        : link.id;
    _sourceLinks[id] = SourceLink(
      id: id,
      nodeId: link.nodeId,
      documentId: link.documentId,
      documentTitle: link.documentTitle,
      pageIndex: link.pageIndex,
      startCharIndex: link.startCharIndex,
      endCharIndex: link.endCharIndex,
      selectedText: link.selectedText,
      annotationId: link.annotationId,
      createdAt: link.createdAt,
    );
    return id;
  }

  @override
  Future<SourceLink?> getSourceLinkByNode(String nodeId) async {
    return _sourceLinks.values.firstWhereOrNull((l) => l.nodeId == nodeId);
  }

  @override
  Future<List<SourceLink>> getSourceLinksByDocument(String documentId) async {
    return _sourceLinks.values
        .where((l) => l.documentId == documentId)
        .toList();
  }

  @override
  Future<void> deleteSourceLink(String id) async {
    _sourceLinks.remove(id);
  }

  // Test helpers
  void seedMindMaps(List<MindMap> maps) {
    for (final map in maps) {
      _mindMaps[map.id] = map;
    }
  }

  void seedNodes(List<MindMapNode> nodes) {
    for (final node in nodes) {
      _nodes[node.id] = node;
    }
  }
}

// Helper extension for firstWhereOrNull
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/storage/mind_map_repository_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/storage/in_memory_mind_map_repository.dart test/mindmap/storage/mind_map_repository_test.dart
git commit -m "feat(mindmap): add InMemoryMindMapRepository with tests"
```

---

## Task 13: 实现 FfiMindMapRepository（生产）

**Files:**
- Create: `lib/src/mindmap/storage/ffi_mind_map_repository.dart`

- [ ] **Step 1: 实现 FFI 适配器**

```dart
// lib/src/mindmap/storage/ffi_mind_map_repository.dart

import 'package:starmind/src/rust/api/storage.dart' as ffi;
import 'package:starmind/src/mindmap/domain/mind_map.dart';
import 'package:starmind/src/mindmap/domain/mind_map_node.dart';
import 'package:starmind/src/mindmap/domain/mind_map_edge.dart';
import 'package:starmind/src/mindmap/domain/source_link.dart';
import 'package:starmind/src/mindmap/domain/layout_mode.dart';
import 'package:starmind/src/mindmap/storage/mind_map_repository.dart';

/// Production adapter: calls Rust FFI and converts FFI types to Dart domain models.
class FfiMindMapRepository implements MindMapRepository {
  @override
  Future<String> createMindMap({
    required String title,
    String? folderId,
    LayoutMode layoutMode = LayoutMode.freeform,
  }) async {
    return ffi.createMindMap(
      title: title,
      folderId: folderId,
      layoutMode: layoutMode.name,
    );
  }

  @override
  Future<MindMap?> getMindMap(String id) async {
    final record = await ffi.getMindMap(id: id);
    return record != null ? _convertMindMapRecord(record) : null;
  }

  @override
  Future<List<MindMap>> getMindMaps({
    String? folderId,
    String? searchQuery,
    String sortBy = 'modified',
    bool includeTrashed = false,
  }) async {
    final records = await ffi.getMindMaps(
      folderId: folderId,
      searchQuery: searchQuery,
      sortBy: sortBy,
      includeTrashed: includeTrashed,
    );
    return records.map(_convertMindMapRecord).toList();
  }

  @override
  Future<void> renameMindMap(String id, String newTitle) async {
    await ffi.renameMindMap(id: id, newTitle: newTitle);
  }

  @override
  Future<void> moveMindMap(String id, String? newFolderId) async {
    await ffi.moveMindMap(id: id, newFolderId: newFolderId);
  }

  @override
  Future<void> trashMindMap(String id) async {
    await ffi.trashMindMap(id: id);
  }

  @override
  Future<void> deleteMindMap(String id) async {
    await ffi.deleteMindMap(id: id);
  }

  @override
  Future<String> createNode(MindMapNode node) async {
    return ffi.createMindMapNode(
      mindMapId: node.mindMapId,
      parentId: node.parentId,
      sortOrder: node.sortOrder,
      positionX: node.positionX,
      positionY: node.positionY,
      width: node.width,
      height: node.height,
      colorHex: node.colorHex,
      contentJson: node.content.toJson().toString(),
    );
  }

  @override
  Future<List<MindMapNode>> getNodes(String mindMapId) async {
    final records = await ffi.getMindMapNodes(mindMapId: mindMapId);
    return records.map(_convertNodeRecord).toList();
  }

  @override
  Future<void> updateNode(MindMapNode node) async {
    await ffi.updateMindMapNode(
      id: node.id,
      positionX: node.positionX,
      positionY: node.positionY,
      width: node.width,
      height: node.height,
      colorHex: node.colorHex,
      isCollapsed: node.isCollapsed,
      contentJson: node.content.toJson().toString(),
    );
  }

  @override
  Future<void> moveNode(String nodeId, String? newParentId, int sortOrder) async {
    await ffi.moveMindMapNode(
      nodeId: nodeId,
      newParentId: newParentId,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> deleteNode(String id) async {
    await ffi.deleteMindMapNode(id: id);
  }

  @override
  Future<String> createEdge(MindMapEdge edge) async {
    return ffi.createMindMapEdge(
      mindMapId: edge.mindMapId,
      sourceNodeId: edge.sourceNodeId,
      targetNodeId: edge.targetNodeId,
      label: edge.label,
      colorHex: edge.colorHex,
    );
  }

  @override
  Future<List<MindMapEdge>> getFreeEdges(String mindMapId) async {
    final records = await ffi.getMindMapFreeEdges(mindMapId: mindMapId);
    return records.map(_convertEdgeRecord).toList();
  }

  @override
  Future<void> deleteEdge(String id) async {
    await ffi.deleteMindMapEdge(id: id);
  }

  @override
  Future<String> createSourceLink(SourceLink link) async {
    return ffi.createSourceLink(
      nodeId: link.nodeId,
      documentId: link.documentId,
      documentTitle: link.documentTitle,
      pageIndex: link.pageIndex,
      startCharIndex: link.startCharIndex,
      endCharIndex: link.endCharIndex,
      selectedText: link.selectedText,
      annotationId: link.annotationId,
    );
  }

  @override
  Future<SourceLink?> getSourceLinkByNode(String nodeId) async {
    final record = await ffi.getSourceLinkByNode(nodeId: nodeId);
    return record != null ? _convertSourceLinkRecord(record) : null;
  }

  @override
  Future<List<SourceLink>> getSourceLinksByDocument(String documentId) async {
    final records = await ffi.getSourceLinksByDocument(documentId: documentId);
    return records.map(_convertSourceLinkRecord).toList();
  }

  @override
  Future<void> deleteSourceLink(String id) async {
    await ffi.deleteSourceLink(id: id);
  }

  // ── FFI → Dart Type Conversion ───────────────────────────────

  MindMap _convertMindMapRecord(ffi.MindMapRecord record) {
    return MindMap(
      id: record.id,
      title: record.title,
      folderId: record.folderId,
      rootNodeId: record.rootNodeId,
      layoutMode: LayoutMode.values.firstWhere(
        (e) => e.name == record.layoutMode,
        orElse: () => LayoutMode.freeform,
      ),
      isTrashed: record.isTrashed,
      createdAt: DateTime.parse(record.createdAt),
      modifiedAt: DateTime.parse(record.modifiedAt),
    );
  }

  MindMapNode _convertNodeRecord(ffi.MindMapNodeRecord record) {
    return MindMapNode.fromMap({
      'id': record.id,
      'mind_map_id': record.mindMapId,
      'parent_id': record.parentId,
      'sort_order': record.sortOrder,
      'position_x': record.positionX,
      'position_y': record.positionY,
      'width': record.width,
      'height': record.height,
      'color_hex': record.colorHex,
      'is_collapsed': record.isCollapsed ? 1 : 0,
      'content_json': record.contentJson,
      'created_at': record.createdAt,
      'modified_at': record.modifiedAt,
    });
  }

  MindMapEdge _convertEdgeRecord(ffi.MindMapEdgeRecord record) {
    return MindMapEdge.fromMap({
      'id': record.id,
      'mind_map_id': record.mindMapId,
      'source_node_id': record.sourceNodeId,
      'target_node_id': record.targetNodeId,
      'edge_type': record.edgeType,
      'label': record.label,
      'color_hex': record.colorHex,
      'created_at': record.createdAt,
    });
  }

  SourceLink _convertSourceLinkRecord(ffi.SourceLinkRecord record) {
    return SourceLink.fromMap({
      'id': record.id,
      'node_id': record.nodeId,
      'document_id': record.documentId,
      'document_title': record.documentTitle,
      'page_index': record.pageIndex,
      'start_char_index': record.startCharIndex,
      'end_char_index': record.endCharIndex,
      'selected_text': record.selectedText,
      'annotation_id': record.annotationId,
      'created_at': record.createdAt,
    });
  }
}
```

- [ ] **Step 2: 运行静态分析验证**

Run: `dart analyze lib/src/mindmap/storage/ffi_mind_map_repository.dart`
Expected: No issues found (after FFI generation)

- [ ] **Step 3: Commit**

```bash
git add lib/src/mindmap/storage/ffi_mind_map_repository.dart
git commit -m "feat(mindmap): add FfiMindMapRepository production adapter"
```

---

## Self-Review Checklist

完成后执行自检：

### 1. Spec Coverage

| Spec Requirement | Task |
|------------------|------|
| `MindMap` entity | Task 2 |
| `MindMapNode` + `NodeContent` | Task 4 |
| `SourceLink` | Task 3 |
| `MindMapEdge` | Task 5 |
| `LayoutMode` enum | Task 1 |
| `EdgeType` enum | Task 1 |
| SQLite tables | Task 6 |
| Rust CRUD functions | Tasks 7, 8, 9 |
| FFI exports | Task 10 |
| `MindMapRepository` interface | Task 11 |
| InMemory implementation | Task 12 |
| FFI implementation | Task 13 |

### 2. Placeholder Scan

✅ 无 "TBD"、"TODO"、"implement later"
✅ 无 "add appropriate error handling"
✅ 无 "write tests for the above"（测试代码完整）
✅ 无 "similar to Task N"
✅ 所有代码步骤都有完整实现

### 3. Type Consistency

✅ `MindMapRecord` ↔ `MindMap.fromMap()`
✅ `MindMapNodeRecord` ↔ `MindMapNode.fromMap()`
✅ `SourceLinkRecord` ↔ `SourceLink.fromMap()`
✅ `MindMapEdgeRecord` ↔ `MindMapEdge.fromMap()`
✅ `LayoutMode.tree` ↔ `layout_mode: 'tree'`
✅ `EdgeType.free` ↔ `edge_type: 'free'`

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-30-mindmap-m1a-data-layer.md`.**

**Two execution options:**

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**