import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/rust/api/pdf.dart';
import 'package:starmind/src/pdf/text_selection_model.dart';
import 'package:starmind/src/pdf/widgets/selection_handles_overlay.dart';

void main() {
  group('TextSelectionModel unit tests', () {
    test('should manage start, update, and direct index selection updates', () async {
      final model = TextSelectionModel();
      final charList = [
        const CharInfo(text: 'H', index: 0, left: 10, top: 100, right: 20, bottom: 80),
        const CharInfo(text: 'e', index: 1, left: 20, top: 100, right: 30, bottom: 80),
        const CharInfo(text: 'l', index: 2, left: 30, top: 100, right: 40, bottom: 80),
        const CharInfo(text: 'l', index: 3, left: 40, top: 100, right: 50, bottom: 80),
        const CharInfo(text: 'o', index: 4, left: 50, top: 100, right: 60, bottom: 80),
      ];

      Future<List<CharInfo>> getPageChars(int pageIdx) async => charList;

      // Initial state
      expect(model.selectingPageIndex, isNull);
      expect(model.selectionStartCharIndex, isNull);
      expect(model.selectionEndCharIndex, isNull);

      // Start selection at page 0, near character 'H' (left: 10, top: 100, right: 20, bottom: 80)
      await model.startSelection(0, const Offset(15, 90), getPageChars);
      expect(model.selectingPageIndex, 0);
      expect(model.selectionStartCharIndex, 0);
      expect(model.selectionEndCharIndex, 0);

      // Drag to 'l' at index 2 (left: 30, top: 100, right: 40, bottom: 80)
      await model.updateSelection(const Offset(35, 90), getPageChars);
      expect(model.selectionStartCharIndex, 0);
      expect(model.selectionEndCharIndex, 2);

      // Drag to 'o' at index 4 (left: 50, top: 100, right: 60, bottom: 80)
      await model.updateSelection(const Offset(55, 90), getPageChars);
      expect(model.selectionEndCharIndex, 4);

      // Direct selection start update (simulating dragging the start handle)
      model.updateSelectionStart(1);
      expect(model.selectionStartCharIndex, 1);
      expect(model.selectionEndCharIndex, 4);

      // Direct selection end update (simulating dragging the end handle)
      model.updateSelectionEnd(3);
      expect(model.selectionStartCharIndex, 1);
      expect(model.selectionEndCharIndex, 3);

      // Conclude selection (should set toolbar position)
      model.endSelection(const Offset(100, 200));
      expect(model.selectionToolbarPosition, const Offset(100, 200));

      // Clear selection
      model.clearSelection();
      expect(model.selectingPageIndex, isNull);
      expect(model.selectionStartCharIndex, isNull);
      expect(model.selectionEndCharIndex, isNull);
      expect(model.selectionToolbarPosition, isNull);
    });

    test('findClosestChar returns correct indexes and -1 for empty lists', () {
      final model = TextSelectionModel();
      expect(model.findClosestChar([], const Offset(0, 0)), -1);

      final charList = [
        const CharInfo(text: 'A', index: 0, left: 0, top: 20, right: 10, bottom: 0),
        const CharInfo(text: 'B', index: 1, left: 10, top: 20, right: 20, bottom: 0),
      ];

      expect(model.findClosestChar(charList, const Offset(5, 10)), 0);
      expect(model.findClosestChar(charList, const Offset(15, 10)), 1);
    });
  });

  group('SelectionHandlesOverlay Widget Tests', () {
    testWidgets('renders selection handles when positions are not null', (WidgetTester tester) async {
      Offset? draggedHandlePos;
      SelectionHandleType? draggedHandle;
      bool dragEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: SelectionHandlesOverlay(
                zoom: 1.0,
                startHandlePosition: const Offset(50, 100),
                startLineHeight: 20,
                endHandlePosition: const Offset(200, 100),
                endLineHeight: 20,
                onHandleDrag: (handle, pos) {
                  draggedHandle = handle;
                  draggedHandlePos = pos;
                },
                onDragEnd: () {
                  dragEnded = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify that two handles are rendered
      expect(find.byType(GestureDetector), findsNWidgets(2));

      // Drag start handle (positioned left: 50 - 36 / 2 = 32, top: 100 - 12 / 2 = 94)
      final startHandleFinder = find.byType(GestureDetector).first;
      await tester.drag(startHandleFinder, const Offset(20, 0));
      await tester.pump();

      expect(draggedHandle, SelectionHandleType.start);
      expect(draggedHandlePos, isNotNull);
      expect(draggedHandlePos!.dx, closeTo(70, 0.1)); // 50 + 20 delta

      // Drag end handle (positioned left: 200 - 36 / 2 = 182, top: 100)
      final endHandleFinder = find.byType(GestureDetector).last;
      await tester.drag(endHandleFinder, const Offset(-30, 10));
      await tester.pump();

      expect(draggedHandle, SelectionHandleType.end);
      expect(draggedHandlePos, isNotNull);
      expect(draggedHandlePos!.dx, closeTo(170, 0.1)); // 200 - 30 delta
      expect(draggedHandlePos!.dy, closeTo(110, 0.1)); // 100 + 10 delta

      // Verifying drag end
      final gesture = await tester.startGesture(tester.getCenter(startHandleFinder));
      await gesture.moveBy(const Offset(10, 0));
      await gesture.up();
      await tester.pump();

      expect(dragEnded, isTrue);
    });

    testWidgets('renders nothing when handle positions are null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectionHandlesOverlay(
              zoom: 1.0,
              startHandlePosition: null,
              endHandlePosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
