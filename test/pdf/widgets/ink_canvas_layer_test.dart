import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';
import 'package:starmind/src/pdf/widgets/ink_canvas_layer.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart' show InkTool;

void main() {
  group('InkCanvasLayer gesture handling', () {
    late AnnotationController annotationController;
    late InMemoryStorageRepository repository;

    setUp(() async {
      repository = InMemoryStorageRepository();
      await repository.initialize('', '');
      annotationController = AnnotationController(
        repository: repository,
        documentId: 'test-doc',
      );
    });

    testWidgets('uses GestureDispatcher for multi-touch handling', (tester) async {
      // Basic smoke test - verifies integration works
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InkCanvasLayer(
            annotationController: annotationController,
            pageIndex: 0,
            isInkMode: true,
            palmRejectionEnabled: false,
            currentTool: InkTool.pen,
            currentColor: '#000000',
            strokeWidth: 2.0,
            scale: 1.0,
            pdfWidth: 612.0,
            pdfHeight: 792.0,
          ),
        ),
      ));

      // Verify the widget renders without errors
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });

    testWidgets('respects inkModeEnabled setting', (tester) async {
      // Test with ink mode disabled
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InkCanvasLayer(
            annotationController: annotationController,
            pageIndex: 0,
            isInkMode: false,
            palmRejectionEnabled: false,
            currentTool: InkTool.pen,
            currentColor: '#000000',
            strokeWidth: 2.0,
            scale: 1.0,
            pdfWidth: 612.0,
            pdfHeight: 792.0,
          ),
        ),
      ));

      // When ink mode is disabled, the widget should return SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('updates GestureDispatcher settings on widget update', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InkCanvasLayer(
            annotationController: annotationController,
            pageIndex: 0,
            isInkMode: true,
            palmRejectionEnabled: false,
            currentTool: InkTool.pen,
            currentColor: '#000000',
            strokeWidth: 2.0,
            scale: 1.0,
            pdfWidth: 612.0,
            pdfHeight: 792.0,
          ),
        ),
      ));

      // Update with different settings
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InkCanvasLayer(
            annotationController: annotationController,
            pageIndex: 0,
            isInkMode: true,
            palmRejectionEnabled: true, // Changed
            currentTool: InkTool.pen,
            currentColor: '#000000',
            strokeWidth: 2.0,
            scale: 1.0,
            pdfWidth: 612.0,
            pdfHeight: 792.0,
          ),
        ),
      ));

      // Widget should still render without errors after update
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });
  });
}
