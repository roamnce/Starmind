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
      bool fitScreenCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () => fitScreenCalled = true,
            ),
          ),
        ),
      ));

      // Zoom out, zoom in, and zoom scale percentage text
      expect(find.byKey(const ValueKey('zoom_out')), findsOneWidget);
      expect(find.byKey(const ValueKey('zoom_in')), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Fit screen button
      expect(find.byKey(const ValueKey('zoom_fit')), findsOneWidget);

      // Canvas mode toggle
      expect(find.byKey(const ValueKey('mode_toggle')), findsOneWidget);
      expect(find.byIcon(Icons.pan_tool_rounded), findsOneWidget);

      // Layout popup selector
      expect(find.byKey(const ValueKey('layout_selector')), findsOneWidget);
      expect(find.text('两侧布局'), findsOneWidget);

      // Lock button
      expect(find.byKey(const ValueKey('edit_lock')), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('zooming in and out updates scale and UI', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
            ),
          ),
        ),
      ));

      expect(find.text('100%'), findsOneWidget);

      // Zoom in
      await tester.tap(find.byKey(const ValueKey('zoom_in')));
      await tester.pumpAndSettle();
      expect(controller.viewportScale, greaterThan(1.0));
      expect(find.text('${(controller.viewportScale * 100).toInt()}%'), findsOneWidget);

      // Zoom out
      await tester.tap(find.byKey(const ValueKey('zoom_out')));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('zoom fit calls onFitToScreen callback', (tester) async {
      bool fitScreenCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BottomActionBar(
            controller: controller,
            onFitToScreen: () => fitScreenCalled = true,
          ),
        ),
      ));

      await tester.tap(find.byKey(const ValueKey('zoom_fit')));
      await tester.pump();
      expect(fitScreenCalled, isTrue);
    });

    testWidgets('mode toggle changes interaction mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
            ),
          ),
        ),
      ));

      expect(controller.interactMode, equals(CanvasInteractMode.drag));
      expect(find.byIcon(Icons.pan_tool_rounded), findsOneWidget);

      // Tap toggle -> lasso mode
      await tester.tap(find.byKey(const ValueKey('mode_toggle')));
      await tester.pumpAndSettle();
      expect(controller.interactMode, equals(CanvasInteractMode.lasso));
      expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);

      // Tap toggle again -> drag mode
      await tester.tap(find.byKey(const ValueKey('mode_toggle')));
      await tester.pumpAndSettle();
      expect(controller.interactMode, equals(CanvasInteractMode.drag));
      expect(find.byIcon(Icons.pan_tool_rounded), findsOneWidget);
    });

    testWidgets('lock button toggles lock state and icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => BottomActionBar(
              controller: controller,
              onFitToScreen: () {},
            ),
          ),
        ),
      ));

      expect(controller.isLocked, isFalse);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

      // Lock
      await tester.tap(find.byKey(const ValueKey('edit_lock')));
      await tester.pumpAndSettle();
      expect(controller.isLocked, isTrue);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // Unlock
      await tester.tap(find.byKey(const ValueKey('edit_lock')));
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
            ),
          ),
        ),
      ));

      expect(controller.layoutDirection, equals(LayoutDirection.bothSides));

      // Tap layout selector to open menu
      await tester.tap(find.byKey(const ValueKey('layout_selector')));
      await tester.pumpAndSettle();

      // Verify menu items are present
      expect(find.text('两侧布局'), findsWidgets); // One in button, one in menu
      expect(find.text('左侧布局'), findsOneWidget);
      expect(find.text('右侧布局'), findsOneWidget);
      expect(find.text('嵌套卡片'), findsOneWidget);

      // Select Left layout
      await tester.tap(find.text('左侧布局'));
      await tester.pumpAndSettle();

      expect(controller.layoutDirection, equals(LayoutDirection.left));
      expect(find.text('左侧布局'), findsOneWidget); // Displayed on button now
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

      // 1. With unlock, tab key should open the dialog
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Create Child Node'), findsOneWidget);

      // Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Lock the editor via controller
      controller.toggleLock();
      await tester.pumpAndSettle();
      expect(controller.isLocked, isTrue);

      // 3. With lock, tab key should be ignored and dialog not shown
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Create Child Node'), findsNothing);

      // 4. With lock, tapping FAB should show lock message toast and not open dialog
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Create Child Node'), findsNothing);
      expect(find.text('思维导图已锁定，无法编辑'), findsOneWidget);
    });
  });
}
