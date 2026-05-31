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
              key: const Key('mindmap_canvas'),
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

      // Verify CustomPaint with our key exists
      expect(find.byKey(const Key('mindmap_canvas')), findsOneWidget);
    });
  });
}
