// test/mindmap/ui/node_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/node_widget.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('NodeWidget', () {
    late Note testNote;

    setUp(() {
      testNote = Note(
        id: '1-test-uuid',
        topicId: '0-topic-uuid',
        title: '测试节点',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    testWidgets('displays note title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('测试节点'), findsOneWidget);
    });

    testWidgets('shows PDF icon when note has pdfId', (tester) async {
      final noteWithPdf = Note(
        id: '1-test-uuid',
        topicId: '0-topic-uuid',
        title: 'PDF摘录节点',
        pdfId: 'pdf-md5',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: noteWithPdf,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('shows selection highlight when isSelected', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            isSelected: true,
            onTap: () {},
          ),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNotNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NodeWidget(
            note: testNote,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(NodeWidget));
      expect(tapped, isTrue);
    });
  });
}
