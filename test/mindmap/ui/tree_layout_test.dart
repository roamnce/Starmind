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