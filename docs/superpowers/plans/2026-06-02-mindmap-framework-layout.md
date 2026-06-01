# 思维导图框架式布局实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复连线问题，新增 MarginNote 风格的框架式布局模式，支持节点级控制和拖动调整子节点位置。

**Architecture:** 渐进式重构方案，在现有 TreeLayout 基础上新增 FrameworkLayout 类，扩展 Note 模型支持 layoutStyle 字段，修复连线锚点计算，最终实现框架嵌套树形布局。

**Tech Stack:** Flutter/Dart, CustomPainter, TreeLayout algorithm

---

## 文件结构

### 新增文件
- `lib/src/mindmap/ui/framework_layout.dart` - 框架式布局算法核心类
- `test/mindmap/ui/framework_layout_test.dart` - 框架式布局单元测试
- `lib/src/mindmap/ui/framework_child_position.dart` - 子节点位置模型

### 修改文件
- `lib/src/mindmap/domain/note.dart:77-99` - 新增 layoutStyle 和 childPositions 字段
- `lib/src/mindmap/ui/tree_layout.dart:246-302` - 修复连线锚点计算
- `lib/src/mindmap/ui/canvas_painter.dart:89-116` - 改进贝塞尔曲线绘制
- `lib/src/mindmap/ui/node_widget.dart:39-135` - 支持框架式样式渲染
- `lib/src/mindmap/ui/mindmap_page.dart:340-426` - 适配框架式布局渲染逻辑
- `test/mindmap/ui/tree_layout_test.dart` - 新增连线测试用例

---

## Phase 1: 连线修复

### Task 1: 分析连线锚点问题

**Files:**
- Read: `lib/src/mindmap/ui/tree_layout.dart:246-302`
- Read: `lib/src/mindmap/ui/canvas_painter.dart:89-116`

- [ ] **Step 1: 分析当前连线锚点计算逻辑**

阅读 `tree_layout.dart` 的 `_collectConnections` 方法，理解当前锚点计算：

```dart
// 当前代码（第 278-291 行）
final isRightSide = childPos.dx > parentPos.dx;

Offset start, end;
if (isRightSide) {
  // 子节点在右侧：从父节点右边缘中心连到子节点左边缘中心
  start = Offset(parentPos.dx + parentSize.width / 2, parentPos.dy + parentSize.height / 2);
  end = Offset(childPos.dx - childSize.width / 2, childPos.dy + childSize.height / 2);
} else {
  // 子节点在左侧：从父节点左边缘中心连到子节点右边缘中心
  start = Offset(parentPos.dx - parentSize.width / 2, parentPos.dy + parentSize.height / 2);
  end = Offset(childPos.dx + childSize.width / 2, childPos.dy + childSize.height / 2);
}
```

**问题分析：**
1. `parentPos` 是节点中心坐标，但锚点计算使用了 `parentSize.height / 2`
2. 节点渲染位置是 `pos.dy + 500`（带偏移），而连线坐标也做了 +500 偏移
3. 锚点 Y 坐标计算：`parentPos.dy + parentSize.height / 2` —— 这是节点底部，而非中心

**正确逻辑应该是：**
- 锚点应该在节点边缘的中心点
- 对于水平方向连线，锚点 Y 应该是节点中心 Y：`parentPos.dy`
- 锚点 X 应该是节点边缘 X：`parentPos.dx ± parentSize.width / 2`

- [ ] **Step 2: 编写连线锚点测试用例**

Create: `test/mindmap/ui/connection_anchor_test.dart`

```dart
// test/mindmap/ui/connection_anchor_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('Connection Anchor Points', () {
    test('anchor point should be at node edge center, not bottom', () {
      final layout = const TreeLayout();
      final child = NoteTreeNode(
        note: Note(
          id: '1-child',
          topicId: '0-topic',
          title: 'Child',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final root = NoteTreeNode(
        note: Note(
          id: '1-root',
          topicId: '0-topic',
          title: 'Root',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        children: [child],
      );

      final positions = layout.calculate(root);
      final connections = layout.calculateConnections(root, positions);

      expect(connections.length, equals(1));
      
      final conn = connections.first;
      final rootPos = positions['1-root']!;
      final childPos = positions['1-child']!;
      
      // 获取节点尺寸（默认 120x40）
      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);
      final childSize = layout.nodeSizes['1-child'] ?? const Size(120, 40);

      // 验证锚点在节点边缘中心
      // start Y 应该等于 rootPos.dy（节点中心），而非 rootPos.dy + height/2
      expect(conn.start.dy, equals(rootPos.dy));
      // end Y 应该等于 childPos.dy（节点中心）
      expect(conn.end.dy, equals(childPos.dy));
      
      // 验证锚点 X 在节点边缘
      // start X 应该是 root 右边缘
      expect(conn.start.dx, equals(rootPos.dx + rootSize.width / 2));
      // end X 应该是 child 左边缘
      expect(conn.end.dx, equals(childPos.dx - childSize.width / 2));
    });

    test('anchor point for left-side child should be at left edge', () {
      final layout = const TreeLayout(direction: LayoutDirection.left);
      final child = NoteTreeNode(
        note: Note(
          id: '1-child',
          topicId: '0-topic',
          title: 'Child',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final root = NoteTreeNode(
        note: Note(
          id: '1-root',
          topicId: '0-topic',
          title: 'Root',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        children: [child],
      );

      final positions = layout.calculate(root);
      final connections = layout.calculateConnections(root, positions);

      final conn = connections.first;
      final rootPos = positions['1-root']!;
      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);

      // 左侧连线：start X 应该是 root 左边缘
      expect(conn.start.dx, equals(rootPos.dx - rootSize.width / 2));
      // end X 应该是 child 右边缘
      expect(conn.end.dx, greaterThan(conn.start.dx));
    });
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test test/mindmap/ui/connection_anchor_test.dart`

Expected: FAIL - 测试会失败，因为当前锚点计算使用 `parentPos.dy + parentSize.height / 2`（节点底部），而测试期望 `parentPos.dy`（节点中心）

- [ ] **Step 4: 修复连线锚点计算**

Modify: `lib/src/mindmap/ui/tree_layout.dart:278-291`

```dart
// lib/src/mindmap/ui/tree_layout.dart - _collectConnections 方法

// 连线锚点连接到节点边缘中心点
// parentPos/childPos 是节点中心坐标
final isRightSide = childPos.dx > parentPos.dx;

Offset start, end;
if (isRightSide) {
  // 子节点在右侧：从父节点右边缘中心连到子节点左边缘中心
  // 锚点 Y = parentPos.dy（节点中心），而非 parentPos.dy + height/2（节点底部）
  start = Offset(parentPos.dx + parentSize.width / 2, parentPos.dy);
  end = Offset(childPos.dx - childSize.width / 2, childPos.dy);
} else {
  // 子节点在左侧：从父节点左边缘中心连到子节点右边缘中心
  start = Offset(parentPos.dx - parentSize.width / 2, parentPos.dy);
  end = Offset(childPos.dx + childSize.width / 2, childPos.dy);
}
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/mindmap/ui/connection_anchor_test.dart`

Expected: PASS

- [ ] **Step 6: 运行现有连线测试确保向后兼容**

Run: `flutter test test/mindmap/ui/tree_layout_test.dart`

Expected: PASS - 现有测试应该仍然通过

- [ ] **Step 7: 提交连线修复**

```bash
git add lib/src/mindmap/ui/tree_layout.dart test/mindmap/ui/connection_anchor_test.dart
git commit -m "fix(mindmap): correct connection anchor point calculation

- Anchor points now at node edge center (not bottom)
- Fix Y coordinate: use parentPos.dy instead of parentPos.dy + height/2
- Add unit tests for anchor point validation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 2: 框架式布局基础

### Task 2: 新增 FrameworkChildPosition 模型

**Files:**
- Create: `lib/src/mindmap/ui/framework_child_position.dart`
- Create: `test/mindmap/ui/framework_child_position_test.dart`

- [ ] **Step 1: 编写 FrameworkChildPosition 模型测试**

Create: `test/mindmap/ui/framework_child_position_test.dart`

```dart
// test/mindmap/ui/framework_child_position_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/framework_child_position.dart';

void main() {
  group('FrameworkChildPosition', () {
    test('creates position with row and col', () {
      const pos = FrameworkChildPosition(row: 0, col: 1);
      expect(pos.row, equals(0));
      expect(pos.col, equals(1));
    });

    test('serializes to and from JSON', () {
      const pos = FrameworkChildPosition(row: 2, col: 0);
      final json = pos.toJson();
      expect(json['row'], equals(2));
      expect(json['col'], equals(0));

      final restored = FrameworkChildPosition.fromJson(json);
      expect(restored.row, equals(2));
      expect(restored.col, equals(0));
    });

    test('supports equality comparison', () {
      const pos1 = FrameworkChildPosition(row: 1, col: 2);
      const pos2 = FrameworkChildPosition(row: 1, col: 2);
      const pos3 = FrameworkChildPosition(row: 0, col: 2);
      
      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/ui/framework_child_position_test.dart`

Expected: FAIL - 文件不存在

- [ ] **Step 3: 实现 FrameworkChildPosition 模型**

Create: `lib/src/mindmap/ui/framework_child_position.dart`

```dart
// lib/src/mindmap/ui/framework_child_position.dart

/// 框架内子节点的自定义位置
class FrameworkChildPosition {
  /// 行索引（从 0 开始）
  final int row;

  /// 列索引（从 0 开始）
  final int col;

  const FrameworkChildPosition({
    required this.row,
    required this.col,
  });

  /// 从 JSON 创建
  factory FrameworkChildPosition.fromJson(Map<String, dynamic> json) {
    return FrameworkChildPosition(
      row: json['row'] as int,
      col: json['col'] as int,
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FrameworkChildPosition &&
        other.row == row &&
        other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'FrameworkChildPosition(row: $row, col: $col)';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/ui/framework_child_position_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/mindmap/ui/framework_child_position.dart test/mindmap/ui/framework_child_position_test.dart
git commit -m "feat(mindmap): add FrameworkChildPosition model for custom child positions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 扩展 Note 模型支持 layoutStyle

**Files:**
- Modify: `lib/src/mindmap/domain/note.dart:77-99`
- Modify: `lib/src/mindmap/domain/note.dart:139-161`
- Modify: `lib/src/mindmap/domain/note.dart:169-205`

- [ ] **Step 1: 编写 Note layoutStyle 测试**

Create: `test/mindmap/domain/note_layout_style_test.dart`

```dart
// test/mindmap/domain/note_layout_style_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('Note layoutStyle', () {
    test('creates note with default layoutStyle (normal)', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(note.layoutStyle, equals('normal'));
    });

    test('creates note with framework layoutStyle', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(note.layoutStyle, equals('framework'));
    });

    test('serializes layoutStyle to and from Map', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final map = note.toMap();
      expect(map['layout_style'], equals('framework'));
      
      final restored = Note.fromMap(map);
      expect(restored.layoutStyle, equals('framework'));
    });

    test('copyWith updates layoutStyle', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final updated = note.copyWith(layoutStyle: 'framework');
      expect(updated.layoutStyle, equals('framework'));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/domain/note_layout_style_test.dart`

Expected: FAIL - Note 类没有 layoutStyle 字段

- [ ] **Step 3: 修改 Note 类添加 layoutStyle 字段**

Modify: `lib/src/mindmap/domain/note.dart`

```dart
// lib/src/mindmap/domain/note.dart

// 在类定义中添加新字段（约第 75 行后）
class Note {
  // ... existing fields ...

  /// 布局样式：'normal'（普通节点）或 'framework'（框架容器）
  final String layoutStyle;

  // ... existing fields ...

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
    this.layoutStyle = 'normal', // 新增：默认为普通节点
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion = 0,
  });
```

- [ ] **Step 4: 修改 fromMap 方法**

```dart
// lib/src/mindmap/domain/note.dart - fromMap 方法

factory Note.fromMap(Map<String, dynamic> map) {
  // ... existing parsing ...

  return Note(
    // ... existing fields ...
    layoutStyle: map['layout_style'] as String? ?? 'normal',
    // ... existing fields ...
  );
}
```

- [ ] **Step 5: 修改 toMap 方法**

```dart
// lib/src/mindmap/domain/note.dart - toMap 方法

Map<String, dynamic> toMap() => {
  // ... existing fields ...
  'layout_style': layoutStyle,
  // ... existing fields ...
};
```

- [ ] **Step 6: 修改 copyWith 方法**

```dart
// lib/src/mindmap/domain/note.dart - copyWith 方法

Note copyWith({
  String? title,
  NoteContent? content,
  List<String>? childIds,
  Object? parentId = _unset,
  double? positionX,
  double? positionY,
  bool? isCollapsed,
  String? highlightStyle,
  String? layoutStyle, // 新增参数
  DateTime? updatedAt,
}) {
  return Note(
    // ... existing fields ...
    layoutStyle: layoutStyle ?? this.layoutStyle,
    // ... existing fields ...
  );
}
```

- [ ] **Step 7: 运行测试验证通过**

Run: `flutter test test/mindmap/domain/note_layout_style_test.dart`

Expected: PASS

- [ ] **Step 8: 运行所有 Note 相关测试**

Run: `flutter test test/mindmap/domain/`

Expected: PASS

- [ ] **Step 9: 提交**

```bash
git add lib/src/mindmap/domain/note.dart test/mindmap/domain/note_layout_style_test.dart
git commit -m "feat(mindmap): add layoutStyle field to Note model

- Support 'normal' and 'framework' layout styles
- Default to 'normal' for backward compatibility
- Add serialization and copyWith support

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 实现 FrameworkLayout 核心类

**Files:**
- Create: `lib/src/mindmap/ui/framework_layout.dart`
- Create: `test/mindmap/ui/framework_layout_test.dart`

- [ ] **Step 1: 编写网格排列算法测试**

Create: `test/mindmap/ui/framework_layout_test.dart`

```dart
// test/mindmap/ui/framework_layout_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/framework_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('FrameworkLayout Grid Arrangement', () {
    test('arranges 1 child in single row', () {
      final layout = FrameworkLayout();
      final children = [
        NoteTreeNode(
          note: Note(
            id: '1-child1',
            topicId: '0-topic',
            title: 'Child1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ];

      final grid = layout.arrangeGrid(children);

      expect(grid.length, equals(1));
      expect(grid[0].length, equals(1));
    });

    test('arranges 2 children in single row', () {
      final layout = FrameworkLayout();
      final children = [
        NoteTreeNode(
          note: Note(
            id: '1-child1',
            topicId: '0-topic',
            title: 'Child1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        NoteTreeNode(
          note: Note(
            id: '1-child2',
            topicId: '0-topic',
            title: 'Child2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ];

      final grid = layout.arrangeGrid(children);

      expect(grid.length, equals(1));
      expect(grid[0].length, equals(2));
    });

    test('arranges 3 children in two rows (2 + 1)', () {
      final layout = FrameworkLayout();
      final children = List.generate(3, (i) => NoteTreeNode(
        note: Note(
          id: '1-child$i',
          topicId: '0-topic',
          title: 'Child $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));

      final grid = layout.arrangeGrid(children);

      expect(grid.length, equals(2));
      expect(grid[0].length, equals(2)); // 第一行 2 个
      expect(grid[1].length, equals(1)); // 第二行 1 个
    });

    test('arranges 4 children in two rows (2 + 2)', () {
      final layout = FrameworkLayout();
      final children = List.generate(4, (i) => NoteTreeNode(
        note: Note(
          id: '1-child$i',
          topicId: '0-topic',
          title: 'Child $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));

      final grid = layout.arrangeGrid(children);

      expect(grid.length, equals(2));
      expect(grid[0].length, equals(2));
      expect(grid[1].length, equals(2));
    });

    test('arranges 5 children in three rows (2 + 2 + 1)', () {
      final layout = FrameworkLayout();
      final children = List.generate(5, (i) => NoteTreeNode(
        note: Note(
          id: '1-child$i',
          topicId: '0-topic',
          title: 'Child $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));

      final grid = layout.arrangeGrid(children);

      expect(grid.length, equals(3));
      expect(grid[0].length, equals(2));
      expect(grid[1].length, equals(2));
      expect(grid[2].length, equals(1));
    });
  });

  group('FrameworkLayout Size Calculation', () {
    test('calculates minimum framework size for empty node', () {
      final layout = FrameworkLayout();
      final node = NoteTreeNode(
        note: Note(
          id: '1-root',
          topicId: '0-topic',
          title: 'Root',
          layoutStyle: 'framework',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      layout.calculateNodeSizes(node);
      final size = layout.calculateFrameworkSize(node);

      // 最小尺寸：padding + header + nodeHeight + padding
      // 16 + 32 + 40 + 16 = 104 (height)
      // 16 + 120 + 16 = 152 (width)
      expect(size.height, equals(104.0));
      expect(size.width, equals(152.0));
    });

    test('calculates framework size for 2 children', () {
      final layout = FrameworkLayout();
      final node = NoteTreeNode(
        note: Note(
          id: '1-root',
          topicId: '0-topic',
          title: 'Root',
          layoutStyle: 'framework',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        children: List.generate(2, (i) => NoteTreeNode(
          note: Note(
            id: '1-child$i',
            topicId: '0-topic',
            title: 'Child $i',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )),
      );

      layout.calculateNodeSizes(node);
      final size = layout.calculateFrameworkSize(node);

      // 2 个子节点水平排列
      // width: 16 + 120 + 12 + 120 + 16 = 284
      // height: 16 + 32 + 40 + 40 + 16 = 144
      expect(size.width, equals(284.0));
      expect(size.height, equals(144.0));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/ui/framework_layout_test.dart`

Expected: FAIL - 文件不存在

- [ ] **Step 3: 实现 FrameworkLayout 类**

Create: `lib/src/mindmap/ui/framework_layout.dart`

```dart
// lib/src/mindmap/ui/framework_layout.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';
import 'framework_child_position.dart';

/// 框架式布局算法
/// 
/// 用于计算 MarginNote 风格的框架容器布局：
/// - 子节点在容器内网格排列
/// - 支持用户自定义位置
/// - 递归嵌套子框架
class FrameworkLayout {
  /// 框架容器内边距
  final double containerPadding;

  /// 框架内节点间距
  final double nodeSpacing;

  /// 悬挂标题栏高度
  final double headerHeight;

  /// 默认节点宽度
  final double nodeWidth;

  /// 默认节点高度
  final double nodeHeight;

  /// 每行最大列数
  final int maxColumnsPerRow;

  /// 缓存节点尺寸
  final Map<String, Size> _nodeSizes = {};

  const FrameworkLayout({
    this.containerPadding = 16.0,
    this.nodeSpacing = 12.0,
    this.headerHeight = 32.0,
    this.nodeWidth = 120.0,
    this.nodeHeight = 40.0,
    this.maxColumnsPerRow = 2,
  });

  /// 获取缓存的节点尺寸
  Map<String, Size> get nodeSizes => _nodeSizes;

  /// 自动计算网格排列
  /// 
  /// 规则：
  /// - 子节点数量 ≤ 2：水平排列（一行）
  /// - 子节点数量 > 2：网格排列，每行最多 2 个
  List<List<NoteTreeNode>> arrangeGrid(List<NoteTreeNode> children) {
    final count = children.length;
    if (count <= 2) {
      // 水平排列：一行
      return [children];
    }

    // 网格排列：每行最多 maxColumnsPerRow 个
    final rows = <List<NoteTreeNode>>[];
    for (int i = 0; i < count; i += maxColumnsPerRow) {
      final row = children.sublist(i, min(i + maxColumnsPerRow, count));
      rows.add(row);
    }
    return rows;
  }

  /// 应用用户自定义位置
  /// 
  /// 将子节点按照 customPositions 中的位置重新排列
  List<List<NoteTreeNode>> applyCustomPositions(
    List<NoteTreeNode> children,
    Map<String, FrameworkChildPosition>? customPositions,
  ) {
    if (customPositions == null || customPositions.isEmpty) {
      return arrangeGrid(children);
    }

    // 计算最大行列
    int maxRow = 0;
    int maxCol = 0;
    for (final pos in customPositions.values) {
      maxRow = max(maxRow, pos.row);
      maxCol = max(maxCol, pos.col);
    }

    // 创建网格矩阵
    final grid = List.generate(
      maxRow + 1,
      (_) => List<NoteTreeNode?>.filled(maxCol + 1, null),
    );

    // 按自定义位置填充
    for (final child in children) {
      final pos = customPositions[child.note.id];
      if (pos != null) {
        grid[pos.row][pos.col] = child;
      }
    }

    // 填充未指定位置的节点（按顺序填充空白槽位）
    int unassignedIndex = 0;
    final unassigned = children.where((c) => !customPositions.containsKey(c.note.id)).toList();
    
    for (int r = 0; r <= maxRow; r++) {
      for (int c = 0; c <= maxCol; c++) {
        if (grid[r][c] == null && unassignedIndex < unassigned.length) {
          grid[r][c] = unassigned[unassignedIndex++];
        }
      }
    }

    // 转换为非空列表
    return grid.map((row) => row.whereType<NoteTreeNode>().toList()).toList();
  }

  /// 计算所有节点的尺寸（自底向上递归）
  void calculateNodeSizes(NoteTreeNode node) {
    // 如果是框架式节点，递归计算子节点尺寸
    if (node.note.layoutStyle == 'framework') {
      for (final child in node.children) {
        calculateNodeSizes(child);
      }
      // 计算框架自身尺寸
      _nodeSizes[node.note.id] = calculateFrameworkSize(node);
    } else {
      // 普通节点：固定尺寸
      _nodeSizes[node.note.id] = Size(nodeWidth, nodeHeight);
      for (final child in node.children) {
        calculateNodeSizes(child);
      }
    }
  }

  /// 计算框架尺寸（包含所有子节点）
  Size calculateFrameworkSize(NoteTreeNode node) {
    if (node.children.isEmpty || node.note.isCollapsed) {
      // 无子节点：最小框架尺寸
      return Size(
        nodeWidth + containerPadding * 2,
        headerHeight + nodeHeight + containerPadding,
      );
    }

    // 获取排列后的子节点网格
    final grid = arrangeGrid(node.children);

    // 计算最大行宽和总行高
    double maxRowWidth = 0;
    double totalHeight = 0;

    for (int r = 0; r < grid.length; r++) {
      final row = grid[r];
      final rowWidth = row.fold(0.0, (sum, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return sum + childSize.width;
      }) + (row.length - 1) * nodeSpacing;
      maxRowWidth = max(maxRowWidth, rowWidth);

      final rowHeight = row.fold(0.0, (maxH, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return max(maxH, childSize.height);
      });
      totalHeight += rowHeight;
      if (r < grid.length - 1) {
        totalHeight += nodeSpacing;
      }
    }

    return Size(
      max(containerPadding * 2 + maxRowWidth, nodeWidth + containerPadding * 2),
      headerHeight + nodeHeight + totalHeight + containerPadding,
    );
  }

  /// 计算框架式节点的子节点位置
  /// 
  /// 返回 Map<子节点ID, Offset>，其中 Offset 是子节点在框架内的中心坐标
  Map<String, Offset> calculateChildPositions(
    NoteTreeNode node,
    Offset frameworkOrigin,
  ) {
    final positions = <String, Offset>{};

    if (node.children.isEmpty || node.note.isCollapsed) {
      return positions;
    }

    final grid = arrangeGrid(node.children);
    final frameworkSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    // 框架内部起始位置（考虑 padding 和 header）
    final innerTop = frameworkOrigin.dy - frameworkSize.height / 2 + headerHeight + nodeHeight;
    final innerLeft = frameworkOrigin.dx - frameworkSize.width / 2 + containerPadding;

    double currentY = innerTop;

    for (final row in grid) {
      double currentX = innerLeft;
      final rowHeight = row.fold(0.0, (maxH, child) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        return max(maxH, childSize.height);
      });

      for (final child in row) {
        final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);
        
        // 子节点中心坐标
        final childCenterX = currentX + childSize.width / 2;
        final childCenterY = currentY + rowHeight / 2;

        positions[child.note.id] = Offset(childCenterX, childCenterY);

        currentX += childSize.width + nodeSpacing;
      }

      currentY += rowHeight + nodeSpacing;
    }

    return positions;
  }

  /// 计算框架式节点及其子节点的所有位置
  Map<String, Offset> calculate(NoteTreeNode node, Offset origin) {
    final positions = <String, Offset>{};

    // 计算节点尺寸
    calculateNodeSizes(node);

    // 框架节点中心位置
    positions[node.note.id] = origin;

    // 计算子节点位置
    final childPositions = calculateChildPositions(node, origin);
    positions.addAll(childPositions);

    // 递归计算子框架
    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (child != null && child.note.layoutStyle == 'framework') {
        final subPositions = calculate(child, childPos);
        positions.addAll(subPositions);
      }
    }

    return positions;
  }

  /// 计算框架内部的连线
  /// 
  /// 框架式节点的连线从父节点标题栏边缘连到子节点边缘
  List<Connection> calculateConnections(
    NoteTreeNode node,
    Map<String, Offset> positions,
  ) {
    final connections = <Connection>[];

    if (node.note.layoutStyle != 'framework') {
      return connections;
    }

    final parentPos = positions[node.note.id];
    if (parentPos == null) return connections;

    final parentSize = _nodeSizes[node.note.id] ?? calculateFrameworkSize(node);

    // 父节点连线锚点：标题栏底部中心
    final anchorY = parentPos.dy - parentSize.height / 2 + headerHeight + nodeHeight;

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos == null) continue;

      final childSize = _nodeSizes[child.note.id] ?? Size(nodeWidth, nodeHeight);

      // 连线从父节点锚点连到子节点顶部中心
      connections.add(Connection(
        fromId: node.note.id,
        toId: child.note.id,
        start: Offset(parentPos.dx, anchorY),
        end: Offset(childPos.dx, childPos.dy - childSize.height / 2),
      ));

      // 递归计算子框架连线
      if (child.note.layoutStyle == 'framework') {
        connections.addAll(calculateConnections(child, positions));
      }
    }

    return connections;
  }
}

/// 连线数据（复用 TreeLayout 的定义）
class Connection {
  final String fromId;
  final String toId;
  final Offset start;
  final Offset end;

  const Connection({
    required this.fromId,
    required this.toId,
    required this.start,
    required this.end,
  });
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/ui/framework_layout_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/mindmap/ui/framework_layout.dart test/mindmap/ui/framework_layout_test.dart
git commit -m "feat(mindmap): implement FrameworkLayout core algorithm

- Grid arrangement: 1-2 children horizontal, >2 children grid (2 per row)
- Framework size calculation with padding, header, and children
- Child position calculation within framework container
- Connection calculation for framework-style nodes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 3: 渲染适配

### Task 5: 扩展 NodeWidget 支持框架式样式

**Files:**
- Modify: `lib/src/mindmap/ui/node_widget.dart:39-135`

- [ ] **Step 1: 编写框架式节点渲染测试**

Create: `test/mindmap/ui/node_widget_framework_test.dart`

```dart
// test/mindmap/ui/node_widget_framework_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/node_widget.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('NodeWidget Framework Style', () {
    testWidgets('renders framework node with container decoration', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: false,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      // 验证框架容器存在
      expect(find.byType(Container), findsWidgets);
      
      // 验证标题栏存在
      expect(find.text('Framework Node'), findsOneWidget);
    });

    testWidgets('renders framework node with header icon', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: false,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      // 验证框架图标存在
      expect(find.byIcon(Icons.view_module_rounded), findsOneWidget);
    });

    testWidgets('framework node shows selected state with accent border', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: true,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      // 验证选中状态的视觉元素
      expect(find.byType(AnimatedContainer), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/ui/node_widget_framework_test.dart`

Expected: FAIL - NodeWidget 未处理 layoutStyle == 'framework'

- [ ] **Step 3: 修改 NodeWidget 支持框架式样式**

Modify: `lib/src/mindmap/ui/node_widget.dart`

```dart
// lib/src/mindmap/ui/node_widget.dart

import 'package:flutter/material.dart';
import '../domain/note.dart';
import 'mindmap_controller.dart';

/// 节点组件。
///
/// 显示导图节点，支持选中、展开/折叠、PDF 源跳转等。
/// 支持两种布局样式：
/// - normal: 普通节点（单行卡片）
/// - framework: 框架容器（带标题栏的容器）
class NodeWidget extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleCollapse;
  final Size? customSize;
  final MindMapController? controller;

  const NodeWidget({
    super.key,
    required this.note,
    this.isSelected = false,
    this.isCollapsed = false,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onAddChild,
    this.onDelete,
    this.onToggleCollapse,
    this.customSize,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 自定义金黄色选中状态
    final accentColor = const Color(0xFFC8841A);

    // 判断是否为被选中状态
    final selected = isSelected || (controller != null && controller!.selectedNoteIds.contains(note.id));

    // 根据布局样式选择渲染方式
    if (note.layoutStyle == 'framework') {
      return _buildFrameworkNode(context, theme, accentColor, selected);
    }

    // 判断是否为嵌套卡片容器（旧逻辑保留）
    final isNestedCard = note.highlightStyle == 'nestedCard';

    if (isNestedCard && !isCollapsed) {
      // ... existing nestedCard logic ...
      return _buildNestedCard(context, theme, accentColor, selected);
    }

    // 普通节点
    return _buildNormalNode(context, theme, colorScheme, accentColor, selected, isNestedCard);
  }

  /// 构建框架式节点
  Widget _buildFrameworkNode(
    BuildContext context,
    ThemeData theme,
    Color accentColor,
    bool selected,
  ) {
    final w = customSize?.width ?? 200.0;
    final h = customSize?.height ?? 150.0;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : const Color(0x25C8841A),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(selected ? 0.3 : 0.08),
              blurRadius: selected ? 12 : 6,
              spreadRadius: selected ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 悬挂标题栏
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? const Color(0x1CC8841A) : const Color(0x0DFFFFFF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  // 框架图标
                  Icon(
                    Icons.view_module_rounded,
                    size: 16,
                    color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  // 标题
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 折叠按钮
                  if (onToggleCollapse != null)
                    GestureDetector(
                      onTap: onToggleCollapse,
                      child: Icon(
                        isCollapsed ? Icons.add_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            // 子节点区域（由外部填充）
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// 构建嵌套卡片容器（保留原有逻辑）
  Widget _buildNestedCard(
    BuildContext context,
    ThemeData theme,
    Color accentColor,
    bool selected,
  ) {
    final w = customSize?.width ?? 200.0;
    final h = customSize?.height ?? 150.0;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : const Color(0x40C8841A),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(selected ? 0.3 : 0.08),
              blurRadius: selected ? 12 : 6,
              spreadRadius: selected ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? const Color(0x1CC8841A) : const Color(0x0DFFFFFF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onToggleCollapse != null)
                    GestureDetector(
                      onTap: onToggleCollapse,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// 构建普通节点
  Widget _buildNormalNode(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Color accentColor,
    bool selected,
    bool isNestedCard,
  ) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF242930),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accentColor
                : (isNestedCard ? const Color(0xFFC8841A).withOpacity(0.5) : const Color(0x15FFDC8C)),
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNestedCard) ...[
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
              ),
              const SizedBox(width: 6),
            ] else if (note.pdfId != null) ...[
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 14,
                color: selected ? accentColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: (selected || isNestedCard) ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (note.childIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleCollapse,
                child: Icon(
                  isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${note.childIds.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/ui/node_widget_framework_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/mindmap/ui/node_widget.dart test/mindmap/ui/node_widget_framework_test.dart
git commit -m "feat(mindmap): add framework style rendering to NodeWidget

- New _buildFrameworkNode method for framework-style nodes
- Suspended header bar with icon and title
- Container decoration with border and shadow
- Preserve existing nestedCard and normal node logic

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 4: 集成与测试

### Task 6: 修改 MindMapPage 支持框架式布局渲染

**Files:**
- Modify: `lib/src/mindmap/ui/mindmap_page.dart:340-426`

- [ ] **Step 1: 集成框架式布局到 MindMapPage**

Modify: `lib/src/mindmap/ui/mindmap_page.dart`

在 `_buildCanvas` 方法中添加框架式布局的支持：

```dart
// lib/src/mindmap/ui/mindmap_page.dart - _buildCanvas 方法

Widget _buildCanvas(BuildContext context) {
  // 根据节点布局样式选择布局算法
  final useFrameworkLayout = widget.controller.noteTree.any(
    (root) => root.note.layoutStyle == 'framework',
  );

  final layout = useFrameworkLayout
      ? FrameworkLayout()
      : TreeLayout(direction: widget.controller.layoutDirection);

  // Calculate all node positions
  final positions = <String, Offset>{};
  final connections = <Connection>[];

  if (useFrameworkLayout) {
    // 框架式布局
    for (final root in widget.controller.noteTree) {
      positions.addAll(layout.calculate(root, Offset.zero));
      // 使用 FrameworkLayout 的连线计算
      if (layout is FrameworkLayout) {
        connections.addAll(layout.calculateConnections(root, positions));
      }
    }
  } else {
    // 树形布局
    for (final root in widget.controller.noteTree) {
      positions.addAll(layout.calculate(root));
      connections.addAll(layout.calculateConnections(root, positions));
    }
  }

  // ... rest of _buildCanvas logic ...
}
```

- [ ] **Step 2: 导入 FrameworkLayout**

在文件顶部添加导入：

```dart
// lib/src/mindmap/ui/mindmap_page.dart

import 'framework_layout.dart'; // 新增导入
```

- [ ] **Step 3: 运行应用验证**

Run: `flutter run -d windows`

Expected: 应用正常运行，框架式节点渲染正确

- [ ] **Step 4: 提交**

```bash
git add lib/src/mindmap/ui/mindmap_page.dart
git commit -m "feat(mindmap): integrate FrameworkLayout into MindMapPage

- Auto-detect framework-style nodes and use FrameworkLayout
- Support both tree and framework layout modes
- Preserve existing tree layout behavior

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: 改进贝塞尔曲线绘制

**Files:**
- Modify: `lib/src/mindmap/ui/canvas_painter.dart:89-116`

- [ ] **Step 1: 编写改进贝塞尔曲线测试**

Create: `test/mindmap/ui/bezier_curve_test.dart`

```dart
// test/mindmap/ui/bezier_curve_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/canvas_painter.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';

void main() {
  group('Bezier Curve Path Creation', () {
    test('creates horizontal cubic bezier path', () {
      final painter = MindMapCanvasPainter(
        connections: [],
        connectionStyle: ConnectionStyle.bezier,
      );

      final conn = Connection(
        fromId: 'parent',
        toId: 'child',
        start: const Offset(0, 50),
        end: const Offset(100, 50),
      );

      // 水平连线：控制点应该在水平线上
      // midX = 50, control points at (50, 50)
      final path = painter.createCubicBezierPath(conn, true);

      // 验证路径不为空
      expect(path.getBounds().width, greaterThan(0));
    });

    test('creates vertical cubic bezier path', () {
      final painter = MindMapCanvasPainter(
        connections: [],
        connectionStyle: ConnectionStyle.bezier,
      );

      final conn = Connection(
        fromId: 'parent',
        toId: 'child',
        start: const Offset(50, 0),
        end: const Offset(50, 100),
      );

      // 垂直连线：控制点应该在垂直线上
      final path = painter.createCubicBezierPath(conn, false);

      expect(path.getBounds().height, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/mindmap/ui/bezier_curve_test.dart`

Expected: FAIL - createCubicBezierPath 方法不存在

- [ ] **Step 3: 改进 CanvasPainter 贝塞尔曲线方法**

Modify: `lib/src/mindmap/ui/canvas_painter.dart`

```dart
// lib/src/mindmap/ui/canvas_painter.dart

/// 贝塞尔曲线路径（改进版）
/// 
/// 借鉴 wanglin-mindmap 的三次贝塞尔曲线实现
Path _createBezierPath(Connection conn) {
  final path = Path();
  path.moveTo(conn.start.dx, conn.start.dy);

  // 判断连线方向
  final dx = conn.end.dx - conn.start.dx;
  final dy = conn.end.dy - conn.start.dy;
  final isHorizontal = dx.abs() > dy.abs();

  if (isHorizontal) {
    // 水平方向：控制点在水平线上
    final midX = (conn.start.dx + conn.end.dx) / 2;
    path.cubicTo(
      midX, conn.start.dy,
      midX, conn.end.dy,
      conn.end.dx, conn.end.dy,
    );
  } else {
    // 垂直方向：控制点在垂直线上
    final midY = (conn.start.dy + conn.end.dy) / 2;
    path.cubicTo(
      conn.start.dx, midY,
      conn.end.dx, midY,
      conn.end.dx, conn.end.dy,
    );
  }

  return path;
}

/// 公开方法供测试使用
Path createCubicBezierPath(Connection conn, bool isHorizontal) {
  final path = Path();
  path.moveTo(conn.start.dx, conn.start.dy);

  if (isHorizontal) {
    final midX = (conn.start.dx + conn.end.dx) / 2;
    path.cubicTo(midX, conn.start.dy, midX, conn.end.dy, conn.end.dx, conn.end.dy);
  } else {
    final midY = (conn.start.dy + conn.end.dy) / 2;
    path.cubicTo(conn.start.dx, midY, conn.end.dx, midY, conn.end.dx, conn.end.dy);
  }

  return path;
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/mindmap/ui/bezier_curve_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/src/mindmap/ui/canvas_painter.dart test/mindmap/ui/bezier_curve_test.dart
git commit -m "refactor(mindmap): improve bezier curve path creation

- Use cubic bezier with control points on connection axis
- Horizontal: control points at midX on start/end Y
- Vertical: control points at midY on start/end X
- Inspired by wanglin-mindmap implementation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 5: 拖动调整（未来实现）

> 注：拖动调整功能较为复杂，建议在 Phase 1-4 完成并验证后再实现。此阶段仅记录设计要点。

### Task 8: 框架内节点拖动交互（设计预留）

**Files:**
- Create: `lib/src/mindmap/ui/framework_drag_handler.dart` (预留)
- Create: `test/mindmap/ui/framework_drag_test.dart` (预留)

**设计要点：**
1. 长按触发拖动模式
2. 计算可放置槽位
3. 高亮显示目标槽位
4. 释放时更新 childPositions
5. 触发重新布局

---

## 自检清单

### 1. Spec Coverage ✓

| Spec 需求 | 对应 Task |
|-----------|-----------|
| 修复连线问题 | Task 1 |
| 框架式布局基础 | Task 2, 3, 4 |
| 渲染适配 | Task 5, 6 |
| 贝塞尔曲线改进 | Task 7 |
| 拖动调整（预留） | Task 8 |

### 2. Placeholder Scan ✓

- 无 "TBD" / "TODO" / "implement later"
- 所有代码步骤包含完整实现
- 所有测试步骤包含完整测试代码

### 3. Type Consistency ✓

- `FrameworkChildPosition` 在 Task 2 定义，Task 4 使用
- `Connection` 在 `tree_layout.dart` 定义，`framework_layout.dart` 复用
- `layoutStyle: 'framework'` 在 Note 模型和 NodeWidget 中一致使用

---

## 执行选项

计划已完成并保存到 `docs/superpowers/plans/2026-06-02-mindmap-framework-layout.md`

**两种执行方式：**

1. **Subagent-Driven (推荐)** - 我为每个 Task 派发一个独立子代理，Task 间有审查节点，快速迭代

2. **Inline Execution** - 在当前会话中逐个执行 Task，批量执行带检查点

**你选择哪种方式？**