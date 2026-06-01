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
      expect(grid[0].length, equals(2));
      expect(grid[1].length, equals(1));
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

      // 最小尺寸（空节点）：
      // 实际计算：
      // height: headerHeight + nodeHeight + containerPadding = 32 + 40 + 16 = 88
      // width: nodeWidth + containerPadding * 2 = 120 + 32 = 152
      expect(size.height, equals(88.0));
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

      // 2 个子节点水平排列（一行）
      // 实际计算：
      // - 网格行高：max(nodeHeight) = 40
      // - 总内部高度 = 40（无 rowSpacing 因为只有一行）
      // - totalHeight = headerHeight + nodeHeight + childrenHeight = 32 + 40 + 40 = 112
      // - width = containerPadding * 2 + (120 + 12 + 120) = 16 * 2 + 252 = 284
      // 实际代码计算：headerHeight + nodeHeight + totalHeight + containerPadding
      //            = 32 + 40 + 40 + 16 = 128
      expect(size.width, equals(284.0));
      expect(size.height, equals(128.0));
    });
  });
}
