import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/layout/tree_layout_engine.dart';
import 'package:starmind/src/mindmap/layout/layout_config.dart';
import 'package:starmind/src/mindmap/layout/layout_result.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'dart:ui';

void main() {
  group('TreeLayoutEngine', () {
    late TreeLayoutEngine engine;

    setUp(() {
      engine = const TreeLayoutEngine();
    });

    NoteTreeNode createTestNode(String id, String title, {List<NoteTreeNode> children = const []}) {
      return NoteTreeNode(
        note: Note(
          id: id,
          topicId: 'test-topic',
          title: title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        children: children,
      );
    }

    test('places root at origin', () {
      final root = createTestNode('root', 'Root');
      final result = engine.layout(root, LayoutConfig.defaultConfig);

      expect(result.nodePositions['root'], Offset.zero);
    });

    test('places children to the right in rightOnly strategy', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1'),
        createTestNode('child2', 'Child 2'),
      ]);

      final config = LayoutConfig(strategy: LayoutStrategy.rightOnly);
      final result = engine.layout(root, config);

      expect(result.nodePositions['child1']!.dx, greaterThan(0));
      expect(result.nodePositions['child2']!.dx, greaterThan(0));
    });

    test('places children on both sides in bothSides strategy', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1'),
        createTestNode('child2', 'Child 2'),
        createTestNode('child3', 'Child 3'),
      ]);

      final config = LayoutConfig(strategy: LayoutStrategy.bothSides);
      final result = engine.layout(root, config);

      expect(result.nodePositions['child1']!.dx, greaterThan(0));
      expect(result.nodePositions['child3']!.dx, greaterThan(0));
      expect(result.nodePositions['child2']!.dx, lessThan(0));
    });

    test('creates connections between parent and children', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1'),
        createTestNode('child2', 'Child 2'),
      ]);

      final result = engine.layout(root, LayoutConfig.defaultConfig);

      expect(result.connections.length, 2);
      final connectionIds = result.connections.map((c) => '${c.fromId}->${c.toId}').toSet();
      expect(connectionIds, containsAll(['root->child1', 'root->child2']));
    });

    test('anchor points are on node edges', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1'),
      ]);

      final result = engine.layout(root, LayoutConfig.defaultConfig);

      final rootPos = result.nodePositions['root']!;
      final rootSize = result.nodeSizes['root']!;
      final conn = result.connections.first;

      if (conn.isRightward) {
        expect(conn.startPoint.dx, rootPos.dx + rootSize.width / 2);
        expect(conn.startPoint.dy, rootPos.dy);
      }
    });

    test('handles nested children', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1', children: [
          createTestNode('grandchild1', 'Grandchild 1'),
        ]),
      ]);

      final result = engine.layout(root, LayoutConfig(strategy: LayoutStrategy.rightOnly));

      expect(result.nodePositions.length, 3);
      expect(result.nodePositions['grandchild1']!.dx, greaterThan(result.nodePositions['child1']!.dx));
    });

    test('calculates correct content bounds', () {
      final root = createTestNode('root', 'Root', children: [
        createTestNode('child1', 'Child 1'),
      ]);

      final result = engine.layout(root, LayoutConfig.defaultConfig);

      expect(result.contentBounds.width, greaterThan(0));
      expect(result.contentBounds.height, greaterThan(0));
    });
  });
}