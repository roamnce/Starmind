// test/mindmap/ui/tree_layout_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('TreeLayout', () {
    test('calculates single root position', () {
      final layout = const TreeLayout();
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

    test('calculates positions for LayoutDirection.bothSides', () {
      final layout = const TreeLayout(direction: LayoutDirection.bothSides);
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

      // Root is at (0, 0)
      expect(positions['1-root'], equals(const Offset(0, 0)));
      
      // child1 is first child (index 0), goes to rightChildren
      // right child X = horizontalSpacing + nodeWidth = 60 + 120 = 180
      expect(positions['1-child1']?.dx, equals(180));
      expect(positions['1-child1']?.dy, equals(0));

      // child2 is second child (index 1), goes to leftChildren
      // left child X = -horizontalSpacing - nodeWidth = -60 - 120 = -180
      expect(positions['1-child2']?.dx, equals(-180));
      expect(positions['1-child2']?.dy, equals(0));
    });

    test('calculates positions for LayoutDirection.left', () {
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

      expect(positions['1-root'], equals(const Offset(0, 0)));
      // childX = -nodeWidth - horizontalSpacing = -180
      expect(positions['1-child']?.dx, equals(-180));
    });

    test('calculates positions for LayoutDirection.horizontal', () {
      final layout = const TreeLayout(direction: LayoutDirection.horizontal);
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

      expect(positions['1-root'], equals(const Offset(0, 0)));
      // childX = nodeWidth + horizontalSpacing = 180
      expect(positions['1-child']?.dx, equals(180));
    });

    test('calculates bounding box for bothSides', () {
      final layout = const TreeLayout(direction: LayoutDirection.bothSides);
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

      // Root center: (0,0), bounds: x in [-60, 60], y in [0, 40]
      // Child center: (180,0), bounds: x in [120, 240], y in [0, 40]
      // Total bounds: x in [-60, 240] (width 300), y in [0, 40] (height 40)
      expect(bounds.width, equals(300));
      expect(bounds.height, equals(40));
    });

    group('Nested Card Layout', () {
      test('calculates size for empty nestedCard container', () {
        final layout = const TreeLayout();
        final root = NoteTreeNode(
          note: Note(
            id: '1-root',
            topicId: '0-topic',
            title: 'Root',
            highlightStyle: 'nestedCard',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        layout.calculate(root);
        final size = layout.nodeSizes['1-root'];
        expect(size, equals(const Size(152, 72))); // 120 + 32, 40 + 32
      });

      test('calculates size and positions for nestedCard with children', () {
        final layout = const TreeLayout(direction: LayoutDirection.horizontal);
        final child1 = NoteTreeNode(
          note: Note(
            id: '1-child1',
            topicId: '0-topic',
            title: 'Child 1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final child2 = NoteTreeNode(
          note: Note(
            id: '1-child2',
            topicId: '0-topic',
            title: 'Child 2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final container = NoteTreeNode(
          note: Note(
            id: '1-container',
            topicId: '0-topic',
            title: 'Container Group',
            highlightStyle: 'nestedCard',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          children: [child1, child2],
        );

        final positions = layout.calculate(container);

        // Children sizes: 120x40.
        // childMaxW = 120.
        // childTotalH = 40 (child1) + 12 (spacing) + 40 (child2) = 92.
        // container size: w = max(120, 120) + 32 = 152.
        //                 h = 40 (nodeHeight) + 92 (childTotalH) + 32 = 164.
        final containerSize = layout.nodeSizes['1-container'];
        expect(containerSize?.width, equals(152.0));
        expect(containerSize?.height, equals(164.0));

        // 新坐标系统：positions 存储节点中心坐标
        // Container is placed at origin (center at 0, 0).
        expect(positions['1-container'], equals(const Offset(0, 0)));

        // Container center is at (0, 0), container height = 164.
        // Container top = 0 - 164/2 = -82.
        // Child 1 starts at containerTop + nodeHeight + 16 = -82 + 40 + 16 = -26 (top edge).
        // Child 1 center X = 0 (horizontal center aligned with container).
        // Child 1 center Y = -26 + 40/2 = -6.
        expect(positions['1-child1'], equals(const Offset(0, -6)));

        // Child 2 starts at Child 1 top + child1Height + 12 = -26 + 40 + 12 = 26 (top edge).
        // Child 2 center X = 0.
        // Child 2 center Y = 26 + 40/2 = 46.
        expect(positions['1-child2'], equals(const Offset(0, 46)));
      });

      test('does not draw connections inside nestedCard container', () {
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
        final container = NoteTreeNode(
          note: Note(
            id: '1-container',
            topicId: '0-topic',
            title: 'Container',
            highlightStyle: 'nestedCard',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          children: [child],
        );
        final root = NoteTreeNode(
          note: Note(
            id: '1-root',
            topicId: '0-topic',
            title: 'Root',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          children: [container],
        );

        final positions = layout.calculate(root);
        final connections = layout.calculateConnections(root, positions);

        // Connections should only be between root and container.
        // The connection between container and child should be skipped.
        expect(connections.length, equals(1));
        expect(connections.first.fromId, equals('1-root'));
        expect(connections.first.toId, equals('1-container'));
      });
    });
  });
}