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
  });
}
