// test/mindmap/ui/shortcuts_mapping_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('Shortcuts Mapping Tests', () {
    late WorkspaceController workspaceController;
    late MindMapController mindMapController;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      workspaceController = WorkspaceController(InMemoryStorageRepository());
      workspaceController.injectPaths(dbPath: ':memory:', sandboxDir: './test_sandbox');
      await workspaceController.init();

      mindMapController = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
      await mindMapController.createTopic('Test Shortcut Notebook');
      await mindMapController.createNote(title: 'Root Node');
    });

    tearDown(() {
      mindMapController.dispose();
      workspaceController.dispose();
    });

    Widget buildTestWidget() {
      return WorkspaceControllerProvider(
        controller: workspaceController,
        child: MaterialApp(
          home: Material(
            child: ListenableBuilder(
              listenable: mindMapController,
              builder: (_, __) => MindMapPage(controller: mindMapController),
            ),
          ),
        ),
      );
    }

    testWidgets('Alt + Q toggles edit lock', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(mindMapController.isLocked, isFalse);

      // Simulate Alt + Q
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(mindMapController.isLocked, isTrue);

      // Simulate Alt + Q again to unlock
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(mindMapController.isLocked, isFalse);
    });

    testWidgets('Ctrl + Alt + S toggles local split mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Split view not visible initially
      expect(find.textContaining('关联 PDF 矢量双向分屏视口'), findsNothing);

      // Simulate Ctrl + Alt + S
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Split view should be visible now
      expect(find.textContaining('关联 PDF 矢量双向分屏视口'), findsOneWidget);

      // Toggle split mode off
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.textContaining('关联 PDF 矢量双向分屏视口'), findsNothing);
    });

    testWidgets('Ctrl + Alt + \\ cycles layout direction', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(mindMapController.layoutDirection, equals(LayoutDirection.bothSides));

      // Simulate Ctrl + Alt + \
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(mindMapController.layoutDirection, equals(LayoutDirection.left));
    });

    testWidgets('Ctrl + Alt + ] toggles sidebar tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(mindMapController.isSidebarExpanded, isFalse);

      // Simulate Ctrl + Alt + ]
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(mindMapController.isSidebarExpanded, isTrue);
    });

    testWidgets('Ctrl + Alt + [ closes workspace sidebar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(workspaceController.sidebarOpen, isTrue);

      // Simulate Ctrl + Alt + [
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(workspaceController.sidebarOpen, isFalse);
    });

    testWidgets('Space key toggles note collapse when selected', (tester) async {
      // Create child node to allow collapsing
      final rootNode = mindMapController.noteTree.first.note;
      await mindMapController.createChildNode(title: 'Child Node');
      mindMapController.selectNote(rootNode);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(mindMapController.noteTree.first.note.isCollapsed, isFalse);

      // Request focus on the main canvas focus node
      final focusFinder = find.byType(Focus);
      await tester.tap(focusFinder.first);
      await tester.pump();

      // Simulate Space
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(mindMapController.noteTree.first.note.isCollapsed, isTrue);
    });

    testWidgets('F2 key shows rename node dialog when selected', (tester) async {
      final rootNode = mindMapController.noteTree.first.note;
      mindMapController.selectNote(rootNode);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Request focus on the main canvas focus node
      final focusFinder = find.byType(Focus);
      await tester.tap(focusFinder.first);
      await tester.pump();

      // Simulate F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(find.text('Rename Node'), findsOneWidget);
    });
  });
}
