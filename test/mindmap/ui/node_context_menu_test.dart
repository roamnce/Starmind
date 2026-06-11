// test/mindmap/ui/node_context_menu_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:starmind/src/mindmap/ui/node_context_menu.dart';

void main() {
  group('NodeContextMenu', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeContextMenu(
            onAddChild: () {},
            onAddSibling: () {},
            onEditInk: () {},
            onDelete: () {},
            child: const Text('Test Node'),
          ),
        ),
      ));

      // Should find the child
      expect(find.text('Test Node'), findsOneWidget);
    });

    testWidgets('onEditInk is optional', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeContextMenu(
            // No onEditInk provided
            onAddChild: () {},
            onDelete: () {},
            child: const Text('Test Node'),
          ),
        ),
      ));

      expect(find.text('Test Node'), findsOneWidget);
    });

    testWidgets('shows context menu on long press', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeContextMenu(
            onAddChild: () {},
            onAddSibling: () {},
            onEditInk: () {},
            onDelete: () {},
            child: const Text('Test Node'),
          ),
        ),
      ));

      // Long press to show the menu
      await tester.longPress(find.text('Test Node'));
      await tester.pumpAndSettle();

      // Should find menu buttons
      expect(find.byIcon(FLucideIcons.plus), findsOneWidget);
      expect(find.byIcon(FLucideIcons.pencil), findsOneWidget);
      expect(find.byIcon(FLucideIcons.trash2), findsOneWidget);
    });

    testWidgets('invokes onEditDetail callback when edit detail button is tapped', (tester) async {
      var editDetailCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeContextMenu(
            onAddChild: () {},
            onAddSibling: () {},
            onEditInk: () {},
            onEditDetail: () {
              editDetailCalled = true;
            },
            onDelete: () {},
            child: const Text('Test Node'),
          ),
        ),
      ));

      // Long press to show the menu
      await tester.longPress(find.text('Test Node'));
      await tester.pumpAndSettle();

      // Tap the edit detail button (using info icon)
      await tester.tap(find.byIcon(FLucideIcons.info));
      await tester.pumpAndSettle();

      expect(editDetailCalled, isTrue);
    });
  });
}
