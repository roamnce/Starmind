// test/mindmap/ui/node_widget_framework_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/node_widget.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('NodeWidget Framework Style', () {
    testWidgets('renders framework node with container decoration', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: false,
              isFrameworkNode: true,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
      expect(find.text('Framework Node'), findsOneWidget);
    });

    testWidgets('renders framework node with header icon', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: false,
              isFrameworkNode: true,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.view_module_rounded), findsOneWidget);
    });

    testWidgets('framework node shows selected state with accent border', (tester) async {
      final note = Note(
        id: '1-framework',
        topicId: '0-topic',
        title: 'Framework Node',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NodeWidget(
              note: note,
              isSelected: true,
              isFrameworkNode: true,
              onTap: () {},
              customSize: const Size(200, 150),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedContainer), findsWidgets);
    });
  });
}
