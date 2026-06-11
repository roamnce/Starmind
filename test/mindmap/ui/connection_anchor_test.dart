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

      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);
      final childSize = layout.nodeSizes['1-child'] ?? const Size(120, 40);

      // Verify anchor points are at node edge center
      // 新坐标系统：positions 存储节点中心坐标，锚点 Y = parentPos.dy（中心）
      expect(conn.start.dy, equals(rootPos.dy));
      expect(conn.end.dy, equals(childPos.dy));

      // Verify anchor X at node edge
      expect(conn.start.dx, equals(rootPos.dx + rootSize.width / 2));
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
      final childPos = positions['1-child']!;
      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);
      final childSize = layout.nodeSizes['1-child'] ?? const Size(120, 40);

      // 左侧布局：父节点在右，子节点在左
      // start 应该是父节点左边缘
      expect(conn.start.dx, equals(rootPos.dx - rootSize.width / 2));
      // end 应该是子节点右边缘
      expect(conn.end.dx, equals(childPos.dx + childSize.width / 2));
      // Y 坐标应该是节点中心（positions 存储中心坐标）
      expect(conn.start.dy, equals(rootPos.dy));
      expect(conn.end.dy, equals(childPos.dy));
    });

    test('right layout long title anchor touches node right edge', () {
      final layout = const TreeLayout();
      final child = NoteTreeNode(
        note: Note(
          id: '1-child',
          topicId: '0-topic',
          title: 'This is a very long node title that should be wider than default',
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
      final childPos = positions['1-child']!;
      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);
      final childSize = layout.nodeSizes['1-child'] ?? const Size(120, 40);

      // 右侧布局：父节点右边缘 = 子节点左边缘
      expect(conn.start.dx, equals(rootPos.dx + rootSize.width / 2));
      expect(conn.end.dx, equals(childPos.dx - childSize.width / 2));
      expect(conn.start.dy, equals(rootPos.dy));
      expect(conn.end.dy, equals(childPos.dy));
    });

    test('left layout long title anchor touches node left edge', () {
      final layout = const TreeLayout(direction: LayoutDirection.left);
      final child = NoteTreeNode(
        note: Note(
          id: '1-child',
          topicId: '0-topic',
          title: 'This is a very long node title that should be wider than default',
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
      final childPos = positions['1-child']!;
      final rootSize = layout.nodeSizes['1-root'] ?? const Size(120, 40);
      final childSize = layout.nodeSizes['1-child'] ?? const Size(120, 40);

      // 左侧布局：父节点左边缘 = 子节点右边缘
      expect(conn.start.dx, equals(rootPos.dx - rootSize.width / 2));
      expect(conn.end.dx, equals(childPos.dx + childSize.width / 2));
      expect(conn.start.dy, equals(rootPos.dy));
      expect(conn.end.dy, equals(childPos.dy));
    });
  });
}
