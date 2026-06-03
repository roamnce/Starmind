import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/layout/tree_layout_engine.dart';
import 'package:starmind/src/mindmap/layout/layout_config.dart';
import 'package:starmind/src/mindmap/rendering/bezier_renderer.dart';
import 'package:starmind/src/mindmap/rendering/straight_renderer.dart';
import 'package:starmind/src/mindmap/rendering/ortho_renderer.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'dart:ui';

void main() {
  group('Layout Integration Tests', () {
    late TreeLayoutEngine engine;

    setUp(() {
      engine = const TreeLayoutEngine();
    });

    NoteTreeNode createNode(String id, String title, {List<NoteTreeNode> children = const []}) {
      return NoteTreeNode(
        note: Note(
          id: id,
          topicId: 'test',
          title: title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        children: children,
      );
    }

    test('full layout flow: bothSides strategy', () {
      final root = createNode('root', 'Root', children: [
        createNode('left', 'Left'),
        createNode('right', 'Right'),
      ]);

      final result = engine.layout(root, LayoutConfig(strategy: LayoutStrategy.bothSides));

      expect(result.nodePositions.length, 3);
      expect(result.connections.length, 2);

      for (final conn in result.connections) {
        final fromPos = result.nodePositions[conn.fromId]!;
        final fromSize = result.nodeSizes[conn.fromId]!;

        final isOnEdge = conn.startPoint.dx == fromPos.dx - fromSize.width / 2 ||
                        conn.startPoint.dx == fromPos.dx + fromSize.width / 2;
        expect(isOnEdge, isTrue, reason: 'Anchor should be on node edge');
      }
    });

    test('renderers create valid paths for all connections', () {
      final root = createNode('root', 'Root', children: [
        createNode('child', 'Child'),
      ]);

      final result = engine.layout(root, LayoutConfig.defaultConfig);

      final renderers = [
        BezierConnectionRenderer(),
        StraightConnectionRenderer(),
        OrthoConnectionRenderer(),
      ];

      for (final renderer in renderers) {
        for (final conn in result.connections) {
          final path = renderer.createPath(conn);
          expect(path.getBounds().width, greaterThan(0));
        }
      }
    });

    test('nested tree layout', () {
      final root = createNode('root', 'Root', children: [
        createNode('child1', 'Child 1', children: [
          createNode('grandchild1', 'Grandchild 1'),
          createNode('grandchild2', 'Grandchild 2'),
        ]),
        createNode('child2', 'Child 2'),
      ]);

      final result = engine.layout(root, LayoutConfig(strategy: LayoutStrategy.rightOnly));

      expect(result.nodePositions.length, 5);

      final rootX = result.nodePositions['root']!.dx;
      final child1X = result.nodePositions['child1']!.dx;
      final grandchild1X = result.nodePositions['grandchild1']!.dx;

      expect(child1X, greaterThan(rootX));
      expect(grandchild1X, greaterThan(child1X));
    });

    test('performance: 1000 nodes layout under 100ms', () {
      NoteTreeNode buildTree(String idPrefix, int depth) {
        if (depth == 0) {
          return createNode(idPrefix, 'Node $idPrefix');
        }

        final children = <NoteTreeNode>[];
        for (int i = 0; i < 3; i++) {
          children.add(buildTree('$idPrefix-$i', depth - 1));
        }

        return createNode(idPrefix, 'Node $idPrefix', children: children);
      }

      final root = buildTree('root', 5);

      final stopwatch = Stopwatch()..start();
      final result = engine.layout(root, LayoutConfig.defaultConfig);
      stopwatch.stop();

      expect(result.nodePositions.length, greaterThan(300));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
