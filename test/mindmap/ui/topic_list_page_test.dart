// test/mindmap/ui/topic_list_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/topic_list_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('TopicListPage', () {
    late MindMapController controller;

    setUp(() {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('shows empty state when no topics', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('暂无笔记本'), findsOneWidget);
      expect(find.text('点击右下角按钮创建第一个笔记本'), findsOneWidget);
    });

    testWidgets('shows create button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows topic list after creation', (tester) async {
      await controller.createTopic('测试笔记本1');
      await controller.createTopic('测试笔记本2');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => TopicListPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('测试笔记本1'), findsOneWidget);
      expect(find.text('测试笔记本2'), findsOneWidget);
    });
  });
}
