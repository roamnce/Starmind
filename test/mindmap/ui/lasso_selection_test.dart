import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/lasso_painter.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';

void main() {
  group('Lasso Selection Coordinate Mapping', () {
    test('projections match exact mathematical formula with zoom and pan', () {
      // Mock zoom/pan scale
      const double scale = 2.0;
      const double tx = 50.0;
      const double ty = 50.0;

      // Screen space selection rectangle: from (100, 100) to (300, 300)
      const selectionRect = Rect.fromLTRB(100.0, 100.0, 300.0, 300.0);

      // Project back to InteractiveViewer canvas Stack space
      final canvasLeft = (selectionRect.left - tx) / scale;
      final canvasTop = (selectionRect.top - ty) / scale;
      final canvasRight = (selectionRect.right - tx) / scale;
      final canvasBottom = (selectionRect.bottom - ty) / scale;
      final canvasSelectionRect = Rect.fromLTRB(canvasLeft, canvasTop, canvasRight, canvasBottom);

      // Check math:
      // Left: (100 - 50) / 2.0 = 25.0
      // Top: (100 - 50) / 2.0 = 25.0
      // Right: (300 - 50) / 2.0 = 125.0
      // Bottom: (300 - 50) / 2.0 = 125.0
      expect(canvasSelectionRect.left, equals(25.0));
      expect(canvasSelectionRect.top, equals(25.0));
      expect(canvasSelectionRect.right, equals(125.0));
      expect(canvasSelectionRect.bottom, equals(125.0));

      // Node bounds inside Stack is Rect.fromLTWH(pos.dx - size.width/2 + 500, pos.dy + 500, size.width, size.height)
      const nodePos = Offset(-450.0, -450.0);
      const size = Size(100.0, 50.0);
      final nodeBounds = Rect.fromLTWH(
        nodePos.dx - size.width / 2 + 500,
        nodePos.dy + 500,
        size.width,
        size.height,
      );

      expect(nodeBounds.left, equals(0.0));
      expect(nodeBounds.top, equals(50.0));
      expect(nodeBounds.right, equals(100.0));
      expect(nodeBounds.bottom, equals(100.0));

      // It overlaps canvasSelectionRect
      expect(canvasSelectionRect.overlaps(nodeBounds), isTrue);
    });
  });

  group('Lasso UI Selection and Interaction', () {
    late MindMapController controller;

    setUp(() async {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
      await controller.createTopic('Test Lasso Topic');
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('selection highlights node and updates selectedNoteIds', (tester) async {
      // Create a single node
      await controller.createNote(title: 'Lasso Target Node');

      // Set lasso mode
      controller.setInteractMode(CanvasInteractMode.lasso);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, __) => MindMapPage(controller: controller),
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Perform a drag gesture inside the lasso gesture overlay
      final gestureOverlayFinder = find.byType(GestureDetector).last;
      expect(gestureOverlayFinder, findsOneWidget);

      final gesture = await tester.startGesture(const Offset(100, 100));
      await gesture.moveBy(const Offset(600, 500));
      await tester.pump();

      // Confirm LassoPainter is active and painted during dragging
      expect(find.byType(CustomPaint), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();

      // Verify that the node was selected
      expect(controller.selectedNoteIds, isNotEmpty);
      expect(controller.selectedNote?.title, equals('Lasso Target Node'));
    });
  });
}
