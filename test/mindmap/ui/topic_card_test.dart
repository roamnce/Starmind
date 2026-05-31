// test/mindmap/ui/topic_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/topic_card.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('TopicCard', () {
    late Topic testTopic;

    setUp(() {
      testTopic = Topic(
        id: '0-test-uuid',
        title: '测试笔记本',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    testWidgets('displays topic title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('测试笔记本'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(TopicCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows PDF count when pdfIds is not empty', (tester) async {
      final topicWithPdfs = Topic(
        id: '0-test-uuid',
        title: '带PDF的笔记本',
        pdfIds: ['pdf1', 'pdf2'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: topicWithPdfs,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('2 PDF'), findsOneWidget);
    });

    testWidgets('shows delete button when onDelete is provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TopicCard(
            topic: testTopic,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
