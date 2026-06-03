# MindMap UI Layer Implementation Plan (Enhanced)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 MindMap UI 层，包括笔记本列表、导图画布（自动布局+连线绘制+缩放控制）、节点编辑等核心界面

**Architecture:** 采用 Flutter MVVM 模式，Controller 管理 MindMap 状态和视口变换，Service 提供业务逻辑，Repository 提供数据访问。使用树形自动布局算法 + CustomPainter 贝塞尔连线 + InteractiveViewer 缩放。

**Tech Stack:** Flutter, flutter_rust_bridge, Provider (ChangeNotifier), InteractiveViewer (画布缩放), CustomPaint (贝塞尔连线), 树形布局算法

---

## File Structure

```
lib/src/mindmap/
├── domain/              # 已完成
│   ├── topic.dart
│   ├── note.dart
│   ├── note_content.dart
│   └── pdf_position.dart
├── storage/             # 已完成
│   ├── mindmap_repository.dart
│   ├── ffi_mindmap_repository.dart
│   └── in_memory_mindmap_repository.dart
├── service/             # 新增：业务逻辑层
│   └── mindmap_service.dart
└── ui/                  # 新增：UI 层
    ├── topic_list_page.dart       # 笔记本列表页
    ├── topic_card.dart            # 笔记本卡片组件
    ├── mindmap_page.dart          # 导图画布页
    ├── mindmap_controller.dart    # 导图状态管理（含视口）
    ├── node_widget.dart           # 节点组件
    ├── node_editor_sheet.dart     # 节点编辑底部弹窗
    ├── canvas_painter.dart        # 贝塞尔连线绘制
    └── tree_layout.dart           # 树形自动布局算法

test/mindmap/
├── service/
│   └── mindmap_service_test.dart
└── ui/
    ├── topic_list_page_test.dart
    ├── mindmap_controller_test.dart
    ├── tree_layout_test.dart
    └── canvas_painter_test.dart
```

---

### Task 1: 创建 MindMap 服务层

**Files:**
- Create: `lib/src/mindmap/service/mindmap_service.dart`
- Test: `test/mindmap/service/mindmap_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/service/mindmap_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('MindMapService', () {
    late MindMapService service;

    setUp(() {
      service = MindMapService(InMemoryMindMapRepository());
    });

    test('createTopic returns Topic with correct title', () async {
      final topic = await service.createTopic('我的笔记本');
      
      expect(topic.title, equals('我的笔记本'));
      expect(topic.id.startsWith('0-'), isTrue);
    });

    test('createNoteInTopic creates note linked to topic', () async {
      final topic = await service.createTopic('测试笔记本');
      final note = await service.createNote(
        topicId: topic.id,
        title: '第一个节点',
      );
      
      expect(note.title, equals('第一个节点'));
      expect(note.topicId, equals(topic.id));
      expect(note.id.startsWith('1-'), isTrue);
    });

    test('addChildNote creates parent-child relationship', () async {
      final topic = await service.createTopic('测试笔记本');
      final parent = await service.createNote(
        topicId: topic.id,
        title: '父节点',
      );
      final child = await service.createNote(
        topicId: topic.id,
        title: '子节点',
        parentId: parent.id,
      );
      
      await service.addChild(parentId: parent.id, childId: child.id);
      
      final children = await service.getChildren(parent.id);
      expect(children.length, equals(1));
      expect(children.first.id, equals(child.id));
    });

    test('getTopicTree returns all notes in tree structure', () async {
      final topic = await service.createTopic('测试笔记本');
      final root = await service.createNote(
        topicId: topic.id,
        title: '根节点',
      );
      final child1 = await service.createNote(
        topicId: topic.id,
        title: '子节点1',
        parentId: root.id,
      );
      final child2 = await service.createNote(
        topicId: topic.id,
        title: '子节点2',
        parentId: root.id,
      );
      
      await service.addChild(parentId: root.id, childId: child1.id);
      await service.addChild(parentId: root.id, childId: child2.id);
      
      // 添加为根节点
      await service.addRootNote(topicId: topic.id, noteId: root.id);
      
      final tree = await service.getTopicTree(topic.id);
      expect(tree.length, equals(1));
      expect(tree.first.note.id, equals(root.id));
      expect(tree.first.children.length, equals(2));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/service/mindmap_service_test.dart`
Expected: FAIL with "Error: Could not find mindmap_service.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/service/mindmap_service.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import '../storage/mindmap_repository.dart';

/// 节点树结构（用于 UI 渲染）
class NoteTreeNode {
  final Note note;
  final List<NoteTreeNode> children;

  const NoteTreeNode({
    required this.note,
    this.children = const [],
  });
  
  /// 递归计算所有节点数量
  int get totalNodes => 1 + children.fold(0, (sum, child) => sum + child.totalNodes);
  
  /// 计算树的最大深度
  int get maxDepth => children.isEmpty ? 1 : 1 + children.map((c) => c.maxDepth).reduce((a, b) => a > b ? a : b);
}

/// MindMap 业务服务层。
///
/// 封装 Repository 操作，提供高级业务功能：
/// - 创建笔记本和节点
/// - 构建节点树结构
/// - PDF 摘录节点创建
/// - 批量操作
class MindMapService {
  final MindMapRepository _repository;

  MindMapService(this._repository);

  // ==================== Topic 操作 ====================

  /// 创建新笔记本
  Future<Topic> createTopic(String title, {String? author}) async {
    final id = await _repository.createTopic(title, author: author);
    final topic = await _repository.getTopic(id);
    return topic!;
  }

  /// 获取笔记本
  Future<Topic?> getTopic(String id) async {
    return await _repository.getTopic(id);
  }

  /// 获取所有笔记本（排除已删除）
  Future<List<Topic>> getAllTopics() async {
    return await _repository.getAllTopics();
  }

  /// 更新笔记本
  Future<void> updateTopic(Topic topic) async {
    await _repository.updateTopic(topic);
  }

  /// 软删除笔记本
  Future<void> trashTopic(String id) async {
    await _repository.trashTopic(id);
  }

  /// 添加根节点到笔记本
  Future<void> addRootNote({
    required String topicId,
    required String noteId,
  }) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return;

    final updatedTopic = topic.copyWith(
      rootNoteIds: [...topic.rootNoteIds, noteId],
      updatedAt: DateTime.now(),
    );
    await _repository.updateTopic(updatedTopic);
  }

  /// 移除根节点
  Future<void> removeRootNote({
    required String topicId,
    required String noteId,
  }) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return;

    final updatedTopic = topic.copyWith(
      rootNoteIds: topic.rootNoteIds.where((id) => id != noteId).toList(),
      updatedAt: DateTime.now(),
    );
    await _repository.updateTopic(updatedTopic);
  }

  // ==================== Note 操作 ====================

  /// 创建节点
  Future<Note> createNote({
    required String topicId,
    required String title,
    String? parentId,
  }) async {
    final id = await _repository.createNote(topicId, title, parentId: parentId);
    final note = await _repository.getNote(id);
    return note!;
  }

  /// 获取节点
  Future<Note?> getNote(String id) async {
    return await _repository.getNote(id);
  }

  /// 更新节点
  Future<void> updateNote(Note note) async {
    await _repository.updateNote(note);
  }

  /// 删除节点
  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
  }

  /// 添加子节点
  Future<void> addChild({
    required String parentId,
    required String childId,
  }) async {
    await _repository.addChild(parentId, childId);
  }

  /// 移除子节点
  Future<void> removeChild({
    required String parentId,
    required String childId,
  }) async {
    await _repository.removeChild(parentId, childId);
  }

  /// 获取子节点列表
  Future<List<Note>> getChildren(String parentId) async {
    return await _repository.getChildren(parentId);
  }

  /// 获取笔记本内所有节点
  Future<List<Note>> getNotesByTopic(String topicId) async {
    return await _repository.getNotesByTopic(topicId);
  }

  /// 获取 PDF 关联的所有节点
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    return await _repository.getNotesByPdf(pdfId);
  }

  // ==================== 树结构操作 ====================

  /// 获取笔记本的节点树（用于 UI 渲染）
  Future<List<NoteTreeNode>> getTopicTree(String topicId) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return [];

    final List<NoteTreeNode> roots = [];
    for (final rootId in topic.rootNoteIds) {
      final node = await _buildTreeNode(rootId);
      if (node != null) roots.add(node);
    }
    return roots;
  }

  /// 递归构建节点树
  Future<NoteTreeNode?> _buildTreeNode(String noteId) async {
    final note = await _repository.getNote(noteId);
    if (note == null) return null;

    final children = await _repository.getChildren(noteId);
    final childNodes = <NoteTreeNode>[];

    for (final child in children) {
      final childNode = await _buildTreeNode(child.id);
      if (childNode != null) childNodes.add(childNode);
    }

    return NoteTreeNode(note: note, children: childNodes);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/service/mindmap_service_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/service/mindmap_service.dart test/mindmap/service/mindmap_service_test.dart
git commit -m "feat(mindmap): add MindMapService for business logic

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: 创建树形自动布局算法

**Files:**
- Create: `lib/src/mindmap/ui/tree_layout.dart`
- Test: `test/mindmap/ui/tree_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/tree_layout_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('TreeLayout', () {
    late TreeLayout layout;
    
    setUp(() {
      layout = TreeLayout(
        nodeWidth: 120,
        nodeHeight: 40,
        horizontalSpacing: 60,
        verticalSpacing: 30,
      );
    });

    test('calculates single root position', () {
      final root = NoteTreeNode(
        note: Note(
          id: '1-root',
          topicId: '0-topic',
          title: 'Root',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      final positions = layout.calculate(root);
      
      expect(positions.length, equals(1));
      expect(positions['1-root'], equals(const Offset(0, 0)));
    });

    test('calculates parent-child positions vertically', () {
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
      
      // 根节点在顶部居中
      expect(positions['1-root']?.dy, equals(0));
      // 子节点在下方
      expect(positions['1-child']?.dy, greaterThan(0));
    });

    test('calculates multiple children spread horizontally', () {
      final child1 = NoteTreeNode(
        note: Note(
          id: '1-child1',
          topicId: '0-topic',
          title: 'Child1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final child2 = NoteTreeNode(
        note: Note(
          id: '1-child2',
          topicId: '0-topic',
          title: 'Child2',
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
        children: [child1, child2],
      );
      
      final positions = layout.calculate(root);
      
      // 子节点应该水平分散
      final child1X = positions['1-child1']!.dx;
      final child2X = positions['1-child2']!.dx;
      expect(child1X, isNot(equals(child2X)));
    });

    test('calculates bounding box', () {
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
      
      final bounds = layout.calculateBounds(root);
      
      expect(bounds.width, greaterThanOrEqualTo(120));
      expect(bounds.height, greaterThanOrEqualTo(70)); // 40 + 30 + 40
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/tree_layout_test.dart`
Expected: FAIL with "Error: Could not find tree_layout.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/tree_layout.dart

import 'package:flutter/material.dart';
import '../service/mindmap_service.dart';

/// 树形自动布局算法。
///
/// 采用自顶向下的层次布局策略：
/// 1. 根节点居中在顶部
/// 2. 子节点在下方水平分散
/// 3. 自动计算边界框
class TreeLayout {
  /// 节点宽度
  final double nodeWidth;
  
  /// 节点高度
  final double nodeHeight;
  
  /// 水平间距
  final double horizontalSpacing;
  
  /// 垂直间距
  final double verticalSpacing;
  
  /// 布局方向
  final LayoutDirection direction;

  const TreeLayout({
    this.nodeWidth = 120,
    this.nodeHeight = 40,
    this.horizontalSpacing = 60,
    this.verticalSpacing = 30,
    this.direction = LayoutDirection.vertical,
  });

  /// 计算所有节点的位置
  ///
  /// 返回 Map<noteId, Offset>，Offset 是节点中心点坐标
  Map<String, Offset> calculate(NoteTreeNode root) {
    final positions = <String, Offset>{};
    _layoutSubtree(root, Offset.zero, positions);
    return positions;
  }

  /// 递归布局子树
  ///
  /// [node] 当前节点
  /// [origin] 当前子树的原点（顶部中心）
  /// [positions] 位置映射（输出参数）
  double _layoutSubtree(
    NoteTreeNode node,
    Offset origin,
    Map<String, Offset> positions,
  ) {
    if (node.children.isEmpty) {
      // 叶子节点：直接放在原点
      positions[node.note.id] = origin;
      return nodeWidth;
    }

    // 先递归布局所有子节点，计算子树总宽度
    final childWidths = <double>[];
    for (final child in node.children) {
      final childOrigin = Offset(
        origin.dx + _sumWidths(childWidths) + childWidths.length * horizontalSpacing,
        origin.dy + nodeHeight + verticalSpacing,
      );
      final width = _layoutSubtree(child, childOrigin, positions);
      childWidths.add(width);
    }

    final totalChildrenWidth = _sumWidths(childWidths) + 
        (childWidths.length - 1) * horizontalSpacing;

    // 父节点居中在子节点上方
    final parentX = origin.dx + totalChildrenWidth / 2;
    positions[node.note.id] = Offset(parentX, origin.dy);

    // 调整子节点位置使其相对于父节点居中
    final shiftX = parentX - totalChildrenWidth / 2 - origin.dx;
    if (shiftX != 0) {
      _shiftSubtree(node.children, shiftX, positions);
    }

    return max(nodeWidth, totalChildrenWidth);
  }

  /// 计算宽度总和
  double _sumWidths(List<double> widths) {
    return widths.fold(0.0, (sum, w) => sum + w);
  }

  /// 平移子树
  void _shiftSubtree(
    List<NoteTreeNode> nodes,
    double shiftX,
    Map<String, Offset> positions,
  ) {
    for (final node in nodes) {
      final current = positions[node.note.id];
      if (current != null) {
        positions[node.note.id] = Offset(current.dx + shiftX, current.dy);
      }
      _shiftSubtree(node.children, shiftX, positions);
    }
  }

  /// 计算树的边界框
  Rect calculateBounds(NoteTreeNode root) {
    final positions = calculate(root);
    
    if (positions.isEmpty) {
      return Rect.fromLTWH(0, 0, nodeWidth, nodeHeight);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in positions.values) {
      minX = min(minX, pos.dx - nodeWidth / 2);
      maxX = max(maxX, pos.dx + nodeWidth / 2);
      minY = min(minY, pos.dy);
      maxY = max(maxY, pos.dy + nodeHeight);
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// 计算两节点之间的连线
  List<Connection> calculateConnections(
    NoteTreeNode root,
    Map<String, Offset> positions,
  ) {
    final connections = <Connection>[];
    _collectConnections(root, positions, connections);
    return connections;
  }

  void _collectConnections(
    NoteTreeNode node,
    Map<String, Offset> positions,
    List<Connection> connections,
  ) {
    final parentPos = positions[node.note.id];
    if (parentPos == null) return;

    for (final child in node.children) {
      final childPos = positions[child.note.id];
      if (childPos != null) {
        connections.add(Connection(
          fromId: node.note.id,
          toId: child.note.id,
          start: Offset(parentPos.dx, parentPos.dy + nodeHeight / 2),
          end: Offset(childPos.dx, childPos.dy - nodeHeight / 2),
        ));
      }
      _collectConnections(child, positions, connections);
    }
  }
}

/// 布局方向
enum LayoutDirection {
  /// 垂直布局（根在上，子在下）
  vertical,
  /// 水平布局（根在左，子在右）
  horizontal,
}

/// 连线数据
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

/// 辅助函数
double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/tree_layout_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/tree_layout.dart test/mindmap/ui/tree_layout_test.dart
git commit -m "feat(mindmap): add TreeLayout algorithm for automatic node positioning

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: 创建贝塞尔连线绘制器

**Files:**
- Create: `lib/src/mindmap/ui/canvas_painter.dart`
- Test: `test/mindmap/ui/canvas_painter_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/canvas_painter_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/canvas_painter.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';

void main() {
  group('MindMapCanvasPainter', () {
    test('shouldRepaint returns true when connections change', () {
      final connections1 = [
        Connection(
          fromId: 'a',
          toId: 'b',
          start: Offset.zero,
          end: const Offset(100, 100),
        ),
      ];
      final connections2 = [
        Connection(
          fromId: 'a',
          toId: 'b',
          start: Offset.zero,
          end: const Offset(200, 200),
        ),
      ];

      final painter1 = MindMapCanvasPainter(connections: connections1);
      final painter2 = MindMapCanvasPainter(connections: connections2);

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when connections are same', () {
      final connections = [
        Connection(
          fromId: 'a',
          toId: 'b',
          start: Offset.zero,
          end: const Offset(100, 100),
        ),
      ];

      final painter1 = MindMapCanvasPainter(connections: connections);
      final painter2 = MindMapCanvasPainter(connections: connections);

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    testWidgets('paints bezier curves', (tester) async {
      final connections = [
        Connection(
          fromId: 'parent',
          toId: 'child',
          start: const Offset(100, 50),
          end: const Offset(100, 150),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: MindMapCanvasPainter(
                connections: connections,
                lineColor: Colors.blue,
                lineWidth: 2,
              ),
              size: const Size(300, 300),
            ),
          ),
        ),
      );

      // 验证 CustomPaint 存在
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/canvas_painter_test.dart`
Expected: FAIL with "Error: Could not find canvas_painter.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/canvas_painter.dart

import 'package:flutter/material.dart';
import 'tree_layout.dart';

/// MindMap 画布绘制器。
///
/// 使用贝塞尔曲线绘制节点之间的连线。
/// 支持多种连线样式：直线、贝塞尔曲线、阶梯线。
class MindMapCanvasPainter extends CustomPainter {
  /// 连线数据
  final List<Connection> connections;
  
  /// 连线颜色
  final Color lineColor;
  
  /// 连线宽度
  final double lineWidth;
  
  /// 连线样式
  final ConnectionStyle connectionStyle;

  MindMapCanvasPainter({
    required this.connections,
    this.lineColor = Colors.grey,
    this.lineWidth = 2.0,
    this.connectionStyle = ConnectionStyle.bezier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (connections.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final conn in connections) {
      final path = _createPath(conn);
      canvas.drawPath(path, paint);
    }
  }

  /// 创建连线路径
  Path _createPath(Connection conn) {
    switch (connectionStyle) {
      case ConnectionStyle.straight:
        return _createStraightPath(conn);
      case ConnectionStyle.bezier:
        return _createBezierPath(conn);
      case ConnectionStyle.stepped:
        return _createSteppedPath(conn);
    }
  }

  /// 直线路径
  Path _createStraightPath(Connection conn) {
    return Path()
      ..moveTo(conn.start.dx, conn.start.dy)
      ..lineTo(conn.end.dx, conn.end.dy);
  }

  /// 贝塞尔曲线路径
  ///
  /// 使用三次贝塞尔曲线，控制点在垂直方向上偏移
  Path _createBezierPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // 计算控制点
    final dy = (conn.end.dy - conn.start.dy).abs();
    final controlOffset = dy * 0.5; // 控制点偏移量

    final control1 = Offset(
      conn.start.dx,
      conn.start.dy + controlOffset,
    );
    final control2 = Offset(
      conn.end.dx,
      conn.end.dy - controlOffset,
    );

    path.cubicTo(
      control1.dx, control1.dy,
      control2.dx, control2.dy,
      conn.end.dx, conn.end.dy,
    );

    return path;
  }

  /// 阶梯线路径（正交连接）
  Path _createSteppedPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // 中间转折点
    final midY = (conn.start.dy + conn.end.dy) / 2;

    path.lineTo(conn.start.dx, midY);
    path.lineTo(conn.end.dx, midY);
    path.lineTo(conn.end.dx, conn.end.dy);

    return path;
  }

  @override
  bool shouldRepaint(covariant MindMapCanvasPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        connectionStyle != oldDelegate.connectionStyle;
  }
}

/// 连线样式
enum ConnectionStyle {
  /// 直线
  straight,
  
  /// 贝塞尔曲线（默认）
  bezier,
  
  /// 阶梯线（正交）
  stepped,
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/canvas_painter_test.dart`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/canvas_painter.dart test/mindmap/ui/canvas_painter_test.dart
git commit -m "feat(mindmap): add MindMapCanvasPainter with bezier connections

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: 创建 MindMap Controller（含视口控制）

**Files:**
- Create: `lib/src/mindmap/ui/mindmap_controller.dart`
- Test: `test/mindmap/ui/mindmap_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/mindmap_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('MindMapController', () {
    late MindMapController controller;

    setUp(() {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has empty topic list', () {
      expect(controller.topics, isEmpty);
      expect(controller.selectedTopic, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('loadTopics populates topic list', () async {
      await controller.createTopic('笔记本1');
      await controller.createTopic('笔记本2');
      await controller.loadTopics();

      expect(controller.topics.length, equals(2));
    });

    test('createTopic adds to list and selects it', () async {
      final topic = await controller.createTopic('新笔记本');

      expect(controller.topics.contains(topic), isTrue);
      expect(controller.selectedTopic, equals(topic));
    });

    test('selectTopic updates selectedTopic', () async {
      final topic = await controller.createTopic('测试笔记本');
      
      controller.selectTopic(null);
      expect(controller.selectedTopic, isNull);

      controller.selectTopic(topic);
      expect(controller.selectedTopic, equals(topic));
    });

    test('trashTopic removes from list', () async {
      final topic = await controller.createTopic('待删除笔记本');
      expect(controller.topics.contains(topic), isTrue);

      await controller.trashTopic(topic.id);
      expect(controller.topics.contains(topic), isFalse);
    });

    group('Viewport', () {
      test('initial viewport is identity', () {
        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });

      test('zoom in increases scale', () {
        controller.zoomIn();
        expect(controller.viewportScale, greaterThan(1.0));
      });

      test('zoom out decreases scale', () {
        controller.zoomOut();
        expect(controller.viewportScale, lessThan(1.0));
      });

      test('zoom has limits', () {
        // 多次放大
        for (var i = 0; i < 20; i++) {
          controller.zoomIn();
        }
        expect(controller.viewportScale, lessThanOrEqualTo(4.0));

        // 多次缩小
        for (var i = 0; i < 20; i++) {
          controller.zoomOut();
        }
        expect(controller.viewportScale, greaterThanOrEqualTo(0.1));
      });

      test('resetViewport restores identity', () {
        controller.zoomIn();
        controller.pan(const Offset(100, 100));
        
        controller.resetViewport();
        
        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`
Expected: FAIL with "Error: Could not find mindmap_controller.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/mindmap_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/topic.dart';
import '../domain/note.dart';
import '../service/mindmap_service.dart';

/// MindMap UI 状态管理 Controller。
///
/// 管理笔记本列表、当前选中笔记本、节点树等 UI 状态。
/// 同时管理视口变换（缩放、平移）。
/// 遵循项目现有的 WorkspaceController 模式。
class MindMapController extends ChangeNotifier {
  final MindMapService _service;

  MindMapController(this._service);

  // ==================== 状态 ====================

  /// 所有笔记本列表
  List<Topic> _topics = [];
  List<Topic> get topics => List.unmodifiable(_topics);

  /// 当前选中的笔记本
  Topic? _selectedTopic;
  Topic? get selectedTopic => _selectedTopic;

  /// 当前笔记本的节点树
  List<NoteTreeNode> _noteTree = [];
  List<NoteTreeNode> get noteTree => List.unmodifiable(_noteTree);

  /// 选中的节点
  Note? _selectedNote;
  Note? get selectedNote => _selectedNote;

  /// 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ==================== 视口状态 ====================

  /// 视口缩放比例
  double _viewportScale = 1.0;
  double get viewportScale => _viewportScale;

  /// 视口偏移
  Offset _viewportOffset = Offset.zero;
  Offset get viewportOffset => _viewportOffset;

  /// 缩放限制
  static const double minScale = 0.1;
  static const double maxScale = 4.0;
  static const double zoomStep = 1.2;

  // ==================== Topic 操作 ====================

  /// 加载所有笔记本
  Future<void> loadTopics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _topics = await _service.getAllTopics();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建笔记本
  Future<Topic> createTopic(String title, {String? author}) async {
    final topic = await _service.createTopic(title, author: author);
    _topics = [..._topics, topic];
    _selectedTopic = topic;
    notifyListeners();
    return topic;
  }

  /// 选择笔记本
  void selectTopic(Topic? topic) {
    _selectedTopic = topic;
    _selectedNote = null;
    notifyListeners();

    if (topic != null) {
      _loadNoteTree(topic.id);
    } else {
      _noteTree = [];
      notifyListeners();
    }
  }

  /// 软删除笔记本
  Future<void> trashTopic(String id) async {
    await _service.trashTopic(id);
    _topics = _topics.where((t) => t.id != id).toList();
    
    if (_selectedTopic?.id == id) {
      _selectedTopic = null;
      _noteTree = [];
    }
    notifyListeners();
  }

  // ==================== Note 操作 ====================

  /// 加载笔记本的节点树
  Future<void> _loadNoteTree(String topicId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _noteTree = await _service.getTopicTree(topicId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建节点
  Future<Note> createNote({
    required String title,
    String? parentId,
  }) async {
    if (_selectedTopic == null) {
      throw StateError('No topic selected');
    }

    final note = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    // 如果没有父节点，添加为根节点
    if (parentId == null) {
      await _service.addRootNote(
        topicId: _selectedTopic!.id,
        noteId: note.id,
      );
    } else {
      await _service.addChild(parentId: parentId, childId: note.id);
    }

    // 刷新节点树
    await _loadNoteTree(_selectedTopic!.id);
    return note;
  }

  /// 选择节点
  void selectNote(Note? note) {
    _selectedNote = note;
    notifyListeners();
  }

  /// 更新节点标题
  Future<void> updateNoteTitle(String noteId, String newTitle) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 删除节点
  Future<void> deleteNote(String noteId) async {
    await _service.deleteNote(noteId);

    if (_selectedNote?.id == noteId) {
      _selectedNote = null;
    }

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  // ==================== 视口操作 ====================

  /// 放大
  void zoomIn() {
    _viewportScale = (_viewportScale * zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 缩小
  void zoomOut() {
    _viewportScale = (_viewportScale / zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 设置缩放
  void setZoom(double scale) {
    _viewportScale = scale.clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 平移
  void pan(Offset delta) {
    _viewportOffset = _viewportOffset + delta;
    notifyListeners();
  }

  /// 设置偏移
  void setOffset(Offset offset) {
    _viewportOffset = offset;
    notifyListeners();
  }

  /// 重置视口
  void resetViewport() {
    _viewportScale = 1.0;
    _viewportOffset = Offset.zero;
    notifyListeners();
  }

  /// 适应屏幕（根据边界框计算合适的缩放）
  void fitToScreen(Size screenSize, Rect contentBounds) {
    if (contentBounds.isEmpty) return;

    final scaleX = screenSize.width / contentBounds.width;
    final scaleY = screenSize.height / contentBounds.height;
    _viewportScale = min(scaleX, scaleY) * 0.9; // 留 10% 边距
    
    // 居中
    _viewportOffset = Offset(
      (screenSize.width - contentBounds.width * _viewportScale) / 2,
      (screenSize.height - contentBounds.height * _viewportScale) / 2,
    );
    
    notifyListeners();
  }
}

/// 辅助函数
double min(double a, double b) => a < b ? a : b;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`
Expected: All 11 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart
git commit -m "feat(mindmap): add MindMapController with viewport management

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: 创建笔记本卡片组件

**Files:**
- Create: `lib/src/mindmap/ui/topic_card.dart`
- Test: `test/mindmap/ui/topic_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/topic_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/topic_card.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('TopicCard', () {
    late Topic testTopic;

    setUp(() {
      testTopic = Topic(
        id: '0-test-uuid',
        title: '测试笔记本',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    testWidgets('displays topic title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('测试笔记本'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(TopicCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows PDF count when pdfIds is not empty', (tester) async {
      final topicWithPdfs = Topic(
        id: '0-test-uuid',
        title: '带PDF的笔记本',
        pdfIds: ['pdf1', 'pdf2'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: topicWithPdfs,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('2 PDF'), findsOneWidget);
    });

    testWidgets('shows delete button when onDelete is provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/topic_card_test.dart`
Expected: FAIL with "Error: Could not find topic_card.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/topic_card.dart

import 'package:flutter/material.dart';
import '../domain/topic.dart';

/// 笔记本卡片组件。
///
/// 显示笔记本标题、关联 PDF 数量、创建时间等信息。
/// 支持点击进入、删除等操作。
class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const TopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (topic.pdfIds.isNotEmpty) ...[
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${topic.pdfIds.length} PDF',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _formatDate(topic.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按钮
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  color: colorScheme.error,
                  tooltip: '删除笔记本',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/topic_card_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/topic_card.dart test/mindmap/ui/topic_card_test.dart
git commit -m "feat(mindmap): add TopicCard widget

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: 创建笔记本列表页

**Files:**
- Create: `lib/src/mindmap/ui/topic_list_page.dart`
- Test: `test/mindmap/ui/topic_list_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/topic_list_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/topic_list_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('TopicListPage', () {
    late MindMapController controller;

    setUp(() {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('shows empty state when no topics', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('暂无笔记本'), findsOneWidget);
      expect(find.text('点击右下角按钮创建第一个笔记本'), findsOneWidget);
    });

    testWidgets('shows create button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows topic list after creation', (tester) async {
      await controller.createTopic('测试笔记本1');
      await controller.createTopic('测试笔记本2');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('测试笔记本1'), findsOneWidget);
      expect(find.text('测试笔记本2'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/topic_list_page_test.dart`
Expected: FAIL with "Error: Could not find topic_list_page.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/topic_list_page.dart

import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'topic_card.dart';

/// 笔记本列表页面。
///
/// 显示所有笔记本，支持创建、删除、进入笔记本。
class TopicListPage extends StatelessWidget {
  final MindMapController controller;
  final void Function(dynamic topic)? onTopicSelected;

  const TopicListPage({
    super.key,
    required this.controller,
    this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思维导图'),
        centerTitle: true,
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.topics.isEmpty
              ? _buildEmptyState(context)
              : _buildTopicList(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无笔记本',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建第一个笔记本',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.topics.length,
      itemBuilder: (context, index) {
        final topic = controller.topics[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TopicCard(
            topic: topic,
            onTap: () {
              controller.selectTopic(topic);
              onTopicSelected?.call(topic);
            },
            onDelete: () => _confirmDelete(context, topic.id),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建笔记本'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入笔记本标题',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await this.controller.createTopic(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String topicId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记本'),
        content: const Text('确定要删除这个笔记本吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.trashTopic(topicId);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/topic_list_page_test.dart`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/topic_list_page.dart test/mindmap/ui/topic_list_page_test.dart
git commit -m "feat(mindmap): add TopicListPage for notebook listing

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: 创建节点组件

**Files:**
- Create: `lib/src/mindmap/ui/node_widget.dart`
- Test: `test/mindmap/ui/node_widget_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/node_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/node_widget.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('NodeWidget', () {
    late Note testNote;

    setUp(() {
      testNote = Note(
        id: '1-test-uuid',
        topicId: '0-topic-uuid',
        title: '测试节点',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    testWidgets('displays note title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('测试节点'), findsOneWidget);
    });

    testWidgets('shows PDF icon when note has pdfId', (tester) async {
      final noteWithPdf = Note(
        id: '1-test-uuid',
        topicId: '0-topic-uuid',
        title: 'PDF摘录节点',
        pdfId: 'pdf-md5',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: noteWithPdf,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('shows selection highlight when isSelected', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            isSelected: true,
            onTap: () {},
          ),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNotNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(NodeWidget));
      expect(tapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/node_widget_test.dart`
Expected: FAIL with "Error: Could not find node_widget.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/node_widget.dart

import 'package:flutter/material.dart';
import '../domain/note.dart';

/// 节点组件。
///
/// 显示导图节点，支持选中、展开/折叠、PDF 源跳转等。
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PDF 来源图标
            if (note.pdfId != null) ...[
              Icon(
                Icons.picture_as_pdf,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            // 标题
            Flexible(
              child: Text(
                note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 子节点数量
            if (note.childIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                isCollapsed ? Icons.chevron_right : Icons.expand_more,
                size: 16,
                color: colorScheme.onSurfaceVariant,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/node_widget_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/node_widget.dart test/mindmap/ui/node_widget_test.dart
git commit -m "feat(mindmap): add NodeWidget for displaying mindmap nodes

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 8: 创建导图画布页（集成布局+连线+缩放）

**Files:**
- Create: `lib/src/mindmap/ui/mindmap_page.dart`
- Test: `test/mindmap/ui/mindmap_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mindmap/ui/mindmap_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('MindMapPage', () {
    late MindMapController controller;

    setUp(() async {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
      // 创建测试数据
      await controller.createTopic('测试笔记本');
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('shows empty state when no nodes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('暂无节点'), findsOneWidget);
    });

    testWidgets('shows zoom controls', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);
    });

    testWidgets('shows nodes after creation', (tester) async {
      await controller.createNote(title: '根节点');
      await controller.createNote(title: '第二个节点');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('根节点'), findsOneWidget);
      expect(find.text('第二个节点'), findsOneWidget);
    });

    testWidgets('zoom in button increases scale', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      final initialScale = controller.viewportScale;
      
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      expect(controller.viewportScale, greaterThan(initialScale));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ui/mindmap_page_test.dart`
Expected: FAIL with "Error: Could not find mindmap_page.dart"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mindmap/ui/mindmap_page.dart

import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'node_widget.dart';
import 'tree_layout.dart';
import 'canvas_painter.dart';
import '../service/mindmap_service.dart' show NoteTreeNode;

/// 导图画布页面。
///
/// 使用 InteractiveViewer 实现缩放和平移。
/// 使用 TreeLayout 自动布局节点。
/// 使用 MindMapCanvasPainter 绘制贝塞尔连线。
class MindMapPage extends StatelessWidget {
  final MindMapController controller;

  const MindMapPage({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.selectedTopic?.title ?? '思维导图'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: controller.zoomOut,
            tooltip: '缩小',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: controller.zoomIn,
            tooltip: '放大',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: () => _fitToScreen(context),
            tooltip: '适应屏幕',
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.noteTree.isEmpty
              ? _buildEmptyState(context)
              : _buildCanvas(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无节点',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建根节点',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final layout = const TreeLayout();
    
    // 计算所有节点的位置
    final positions = <String, Offset>{};
    final connections = <Connection>[];
    
    for (final root in controller.noteTree) {
      positions.addAll(layout.calculate(root));
      connections.addAll(layout.calculateConnections(root, positions));
    }
    
    // 计算边界框
    final bounds = _calculateBounds(positions, layout);

    return InteractiveViewer(
      constrained: false,
      minScale: MindMapController.minScale,
      maxScale: MindMapController.maxScale,
      boundaryConstraints: BoxConstraints(
        minWidth: bounds.width + 100,
        minHeight: bounds.height + 100,
      ),
      child: Container(
        width: bounds.width + 200,
        height: bounds.height + 200,
        child: Stack(
          children: [
            // 连线层
            CustomPaint(
              painter: MindMapCanvasPainter(
                connections: connections,
                lineColor: Theme.of(context).colorScheme.outline,
                lineWidth: 2,
              ),
              size: Size(bounds.width + 200, bounds.height + 200),
            ),
            // 节点层
            ...positions.entries.map((entry) {
              final noteId = entry.key;
              final pos = entry.value;
              final note = _findNote(controller.noteTree, noteId);
              
              if (note == null) return const SizedBox.shrink();
              
              return Positioned(
                left: pos.dx - layout.nodeWidth / 2 + 100,
                top: pos.dy + 100,
                child: NodeWidget(
                  note: note,
                  isSelected: controller.selectedNote?.id == noteId,
                  onTap: () => controller.selectNote(note),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 计算所有节点的边界框
  Rect _calculateBounds(Map<String, Offset> positions, TreeLayout layout) {
    if (positions.isEmpty) {
      return Rect.fromLTWH(0, 0, 400, 400);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in positions.values) {
      minX = _min(minX, pos.dx - layout.nodeWidth / 2);
      maxX = _max(maxX, pos.dx + layout.nodeWidth / 2);
      minY = _min(minY, pos.dy);
      maxY = _max(maxY, pos.dy + layout.nodeHeight);
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// 在树中查找节点
  Note? _findNote(List<NoteTreeNode> roots, String id) {
    for (final root in roots) {
      final found = _findNoteInTree(root, id);
      if (found != null) return found;
    }
    return null;
  }

  Note? _findNoteInTree(NoteTreeNode node, String id) {
    if (node.note.id == id) return node.note;
    for (final child in node.children) {
      final found = _findNoteInTree(child, id);
      if (found != null) return found;
    }
    return null;
  }

  void _fitToScreen(BuildContext context) {
    final layout = const TreeLayout();
    final positions = <String, Offset>{};
    
    for (final root in controller.noteTree) {
      positions.addAll(layout.calculate(root));
    }
    
    final bounds = _calculateBounds(positions, layout);
    final screenSize = MediaQuery.of(context).size;
    
    controller.fitToScreen(screenSize, bounds);
  }

  Future<void> _showAddNodeDialog(BuildContext context) async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建节点'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入节点标题',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await controller.createNote(title: result);
    }
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ui/mindmap_page_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/mindmap/ui/mindmap_page.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "feat(mindmap): add MindMapPage with auto-layout, bezier connections and zoom

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec Coverage:**
- ✅ Topic 列表 UI - Task 5, 6
- ✅ MindMap 服务层 - Task 1
- ✅ MindMap Controller（含视口） - Task 4
- ✅ 树形自动布局 - Task 2
- ✅ 贝塞尔连线绘制 - Task 3
- ✅ 导图画布 UI（集成布局+连线+缩放） - Task 8
- ✅ 节点组件 - Task 7
- ⏳ 节点编辑器 - 后续任务
- ⏳ PDF 摘录集成 - 后续任务

**2. Placeholder Scan:**
- ✅ 所有代码都有完整实现
- ✅ 无 TBD 或 TODO 占位符
- ✅ 所有类型和函数都已定义

**3. Type Consistency:**
- ✅ MindMapService 使用 MindMapRepository 接口
- ✅ MindMapController 使用 MindMapService
- ✅ TreeLayout 使用 NoteTreeNode
- ✅ MindMapCanvasPainter 使用 Connection
- ✅ UI 组件使用 MindMapController

**4. Architecture Validation:**
- ✅ 树形布局算法独立于 UI，可单独测试
- ✅ 连线绘制器支持多种样式（直线、贝塞尔、阶梯）
- ✅ Controller 管理视口状态，与 UI 解耦
- ✅ InteractiveViewer 提供手势缩放/平移

---

Plan complete and saved to `docs/superpowers/plans/2026-05-31-mindmap-ui-layer.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
