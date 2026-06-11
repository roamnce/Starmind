// test/mindmap/ui/bottom_action_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/bottom_action_bar.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('BottomActionBar & Edit Lock Tests', () {
    late MindMapController controller;

    setUp(() async {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
      await controller.createTopic('Test Topic');
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders all buttons and controls correctly', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
              onAddChild: () {},
              onAddSibling: () {},
              onAddNote: () {},
            ),
          ),
        ),
      ));

      // Drag tool button
      expect(find.byIcon(Icons.pan_tool_rounded), findsOneWidget);

      // Lasso tool button
      expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);

      // Add child node button
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

      // Add sibling node button
      expect(find.byIcon(Icons.control_point_duplicate_rounded), findsOneWidget);

      // Lock button
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('mode toggle changes interaction mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
              onAddChild: () {},
              onAddSibling: () {},
              onAddNote: () {},
            ),
          ),
        ),
      ));

      expect(controller.interactMode, equals(CanvasInteractMode.drag));
      expect(find.byIcon(Icons.pan_tool_rounded), findsOneWidget);

      // Tap lasso mode button
      await tester.tap(find.byIcon(Icons.crop_free_rounded));
      await tester.pumpAndSettle();
      expect(controller.interactMode, equals(CanvasInteractMode.lasso));

      // Tap drag mode button
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pumpAndSettle();
      expect(controller.interactMode, equals(CanvasInteractMode.drag));
    });

    testWidgets('lock button toggles lock state and icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
              onAddChild: () {},
              onAddSibling: () {},
              onAddNote: () {},
            ),
          ),
        ),
      ));

      expect(controller.isLocked, isFalse);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

      // Lock
      await tester.tap(find.byIcon(Icons.lock_open_rounded));
      await tester.pumpAndSettle();
      expect(controller.isLocked, isTrue);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // Unlock
      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pumpAndSettle();
      expect(controller.isLocked, isFalse);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('layout selector opens showMenu and changes layout direction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
              onAddChild: () {},
              onAddSibling: () {},
              onAddNote: () {},
            ),
          ),
        ),
      ));

      expect(controller.layoutDirection, equals(LayoutDirection.bothSides));

      // Tap layout selector to open menu
      await tester.tap(find.byIcon(Icons.account_tree_rounded));
      await tester.pumpAndSettle();

      // Verify menu items are present
      expect(find.text('两侧布局'), findsWidgets);
      expect(find.text('左侧布局'), findsOneWidget);
      expect(find.text('右侧布局'), findsOneWidget);

      // Select Left layout
      await tester.tap(find.text('左侧布局'));
      await tester.pumpAndSettle();

      expect(controller.layoutDirection, equals(LayoutDirection.left));
    });

    testWidgets('locking restricts node edits and keyboard key events', (tester) async {
      // Create a root node so that tab/sibling actions can be performed if focused
      await controller.createNote(title: 'Root Node');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      // Select the root node to enable child/sibling creation
      final rootNode = controller.noteTree.first.note;
      controller.selectNote(rootNode);
      await tester.pumpAndSettle();

      // 1. With unlock, tab key should create child and enter inline editing
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(controller.editingNoteId, isNotNull);
      expect(find.byType(TextField), findsOneWidget);

      // Cancel editing via Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // 2. Lock the editor via controller
      controller.toggleLock();
      await tester.pumpAndSettle();
      expect(controller.isLocked, isTrue);

      // 3. With lock, tab key should be ignored
      final noteCountBefore = controller.noteTree.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(controller.noteTree.length, equals(noteCountBefore));
    });
  });
}
