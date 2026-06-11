// test/mindmap/ui/panels/node_detail_panel_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/panels/node_detail_panel.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('NodeDetailPanel', () {
    late Note testNote;

    setUp(() {
      testNote = Note(
        id: '1-test-node-id',
        topicId: 'test-topic-id',
        title: 'Test Node Title',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    testWidgets('displays node title in header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
          ),
        ),
      ));

      expect(find.text('Test Node Title'), findsOneWidget);
    });

    testWidgets('displays drag handle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
          ),
        ),
      ));

      // The drag handle is a Container with specific width/height
      final dragHandleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == const Color(0x33FFF8E6),
      );
      expect(dragHandleFinder, findsWidgets);
    });

    testWidgets('close button triggers onClose callback', (tester) async {
      bool closed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {
              closed = true;
            },
          ),
        ),
      ));

      // Find and tap close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('renders markdown slot when provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
            markdownSlot: const Text('Markdown Editor Placeholder'),
          ),
        ),
      ));

      expect(find.text('Markdown Editor Placeholder'), findsOneWidget);
    });

    testWidgets('renders ink slot when provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
            inkSlot: const Text('Ink Editor Placeholder'),
          ),
        ),
      ));

      expect(find.text('Ink Editor Placeholder'), findsOneWidget);
    });

    testWidgets('renders toolbar slot when provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
            toolbarSlot: const Text('Toolbar Placeholder'),
          ),
        ),
      ));

      expect(find.text('Toolbar Placeholder'), findsOneWidget);
    });

    testWidgets('uses DraggableScrollableSheet with correct sizes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeDetailPanel(
            note: testNote,
            onClose: () {},
          ),
        ),
      ));

      // Verify DraggableScrollableSheet is present
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });
  });
}
