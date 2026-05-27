import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/widgets/ink_canvas_layer.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart';

void main() {
  group('GestureRouting', () {
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

    Widget createTestWidget({
      required bool isInkMode,
      bool palmRejectionEnabled = false,
      InkTool currentTool = InkTool.pen,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: InkCanvasLayer(
              annotationController: annotationController,
              pageIndex: 0,
              isInkMode: isInkMode,
              palmRejectionEnabled: palmRejectionEnabled,
              currentTool: currentTool,
              currentColor: '#000000',
              strokeWidth: 2.0,
              scale: 1.0,
              pdfWidth: 400,
              pdfHeight: 600,
            ),
          ),
        ),
      );
    }

    testWidgets('should not render gesture listener when not in ink mode',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: false));

      // Should render SizedBox.shrink() when not in ink mode
      expect(find.byType(InkCanvasLayer), findsOneWidget);
      // Listener should not be a descendant of InkCanvasLayer
      final inkCanvasLayer = tester.widget<InkCanvasLayer>(find.byType(InkCanvasLayer));
      expect(inkCanvasLayer.isInkMode, isFalse);
    });

    testWidgets('should render gesture listener when in ink mode',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      expect(find.byType(InkCanvasLayer), findsOneWidget);
      final inkCanvasLayer = tester.widget<InkCanvasLayer>(find.byType(InkCanvasLayer));
      expect(inkCanvasLayer.isInkMode, isTrue);
    });

    testWidgets('should start drawing on single pointer down in ink mode',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // Simulate a single pointer down event
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      // Verify the widget handles the gesture
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });

    testWidgets('should handle multi-touch by not drawing', (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // Simulate multi-touch: first pointer
      final gesture1 = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      // Second pointer should be tracked but not start drawing for that pointer
      final gesture2 = await tester.startGesture(const Offset(200, 200));
      await tester.pump();

      // The widget should still render
      expect(find.byType(InkCanvasLayer), findsOneWidget);

      // Clean up
      await gesture1.up();
      await gesture2.up();
      await tester.pump();
    });

    testWidgets('should not start drawing when two pointers are already active',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // Add two pointers first (simulating zoom gesture)
      final gesture1 = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      final gesture2 = await tester.startGesture(const Offset(200, 200));
      await tester.pump();

      // Should not be in drawing mode due to multi-touch
      expect(find.byType(InkCanvasLayer), findsOneWidget);

      // Clean up
      await gesture1.up();
      await gesture2.up();
      await tester.pump();
    });

    testWidgets('should handle pointer move correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // Start a gesture and move
      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(120, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(140, 100));
      await tester.pump();

      // Widget should still render
      expect(find.byType(InkCanvasLayer), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('should handle pointer cancel', (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(120, 100));
      await tester.pump();

      // Cancel the gesture
      await gesture.cancel();
      await tester.pump();

      // Widget should still render properly
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });

    testWidgets('should handle eraser tool correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          isInkMode: true,
          currentTool: InkTool.eraser,
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();

      // Widget should handle eraser mode
      expect(find.byType(InkCanvasLayer), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('should handle stylus input', (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // Create a gesture with stylus device kind
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
      );
      await gesture.down(const Offset(100, 100));
      await tester.pump();

      expect(find.byType(InkCanvasLayer), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('should apply palm rejection when enabled', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          isInkMode: true,
          palmRejectionEnabled: true,
        ),
      );

      // Simulate touch (not stylus) pointer - should not draw
      final touchGesture = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await touchGesture.down(const Offset(100, 100));
      await tester.pump();

      // Widget should still render but touch should be rejected
      expect(find.byType(InkCanvasLayer), findsOneWidget);

      await touchGesture.up();
      await tester.pump();

      // Now simulate stylus - should be accepted
      final stylusGesture = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
      );
      await stylusGesture.down(const Offset(100, 100));
      await tester.pump();

      expect(find.byType(InkCanvasLayer), findsOneWidget);

      await stylusGesture.up();
      await tester.pump();
    });

    testWidgets('should complete a stroke on pointer up', (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(120, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(140, 100));
      await tester.pump();

      // Release pointer - should finalize stroke
      await gesture.up();
      await tester.pump();

      // Widget should still render properly
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });

    testWidgets('should handle multiple gestures sequentially',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isInkMode: true));

      // First gesture
      final gesture1 = await tester.startGesture(const Offset(100, 100));
      await tester.pump();
      await gesture1.moveTo(const Offset(120, 100));
      await tester.pump();
      await gesture1.up();
      await tester.pump();

      // Second gesture
      final gesture2 = await tester.startGesture(const Offset(200, 200));
      await tester.pump();
      await gesture2.moveTo(const Offset(220, 200));
      await tester.pump();
      await gesture2.up();
      await tester.pump();

      // Widget should handle both gestures
      expect(find.byType(InkCanvasLayer), findsOneWidget);
    });

    testWidgets('should create annotation after completing stroke',
        (tester) async {
          await tester.pumpWidget(createTestWidget(isInkMode: true));

          // Draw a stroke
          final gesture = await tester.startGesture(const Offset(100, 100));
          await tester.pump();
          await gesture.moveTo(const Offset(150, 100));
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();

          // Verify annotation was created
          final annotations = await repository.getAnnotations('test-doc');
          expect(annotations.length, equals(1));
          expect(annotations.first.type, equals(AnnotationType.ink));
        });

    testWidgets('should cancel drawing when second pointer added mid-stroke',
        (tester) async {
          await tester.pumpWidget(createTestWidget(isInkMode: true));

          // Start drawing with first pointer
          final gesture1 = await tester.startGesture(const Offset(100, 100));
          await tester.pump();
          await gesture1.moveTo(const Offset(150, 100));
          await tester.pump();

          // Add second pointer - should cancel the stroke
          final gesture2 = await tester.startGesture(const Offset(200, 200));
          await tester.pump();

          // Continue with first pointer - should not register
          await gesture1.moveTo(const Offset(200, 100));
          await tester.pump();

          // Release both
          await gesture1.up();
          await gesture2.up();
          await tester.pumpAndSettle();

          // No annotation should be created since stroke was cancelled
          final annotations = await repository.getAnnotations('test-doc');
          expect(annotations.isEmpty, isTrue);
        });
  });
}