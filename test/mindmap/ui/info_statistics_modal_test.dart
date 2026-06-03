// test/mindmap/ui/info_statistics_modal_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/ui/bottom_action_bar.dart';
import 'package:starmind/src/mindmap/ui/info_statistics_modal.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('InfoStatisticsModal Tests', () {
    late InMemoryMindMapRepository repo;
    late MindMapService service;
    late MindMapController controller;

    setUp(() {
      repo = InMemoryMindMapRepository();
      service = MindMapService(repo);
      controller = MindMapController(service);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders all statistical values mathematically correct', (tester) async {
      // 1. Create a Topic and select it
      final topic = await controller.createTopic('Stats Topic', author: 'Author');
      final updatedTopic = topic.copyWith(pdfIds: ['pdf1', 'pdf2', 'pdf3']);
      await service.updateTopic(updatedTopic);
      controller.selectTopic(updatedTopic);
      await tester.pump();

      // 2. Create nodes (recursive tree)
      // Root Node
      final rootNode = await controller.createNote(title: 'Root');
      controller.selectNote(rootNode);
      await controller.updateNoteContent(rootNode.id, 'Root note content text');

      // Child 1
      final child1 = await controller.createChildNode(title: 'Child 1 Title');
      await controller.updateNoteContent(child1!.id, 'C1 Content');
      // Set highlightStyle to nestedCard to test container counts
      await controller.toggleNestedCard(child1.id);

      // Child 2 (sibling of Child 1)
      final child2 = await controller.createSiblingNode(title: 'Child 2 Title');
      await controller.updateNoteContent(child2!.id, 'C2 Content Text');

      // Grandchild under Child 2
      controller.selectNote(child2);
      final grandchild = await controller.createChildNode(title: 'Grandchild');
      await controller.updateNoteContent(grandchild!.id, 'Grandchild text');

      // Ensure all rendering and stream states are finished
      await tester.pump();

      // Expected calculation results:
      // - Total Node Count: Root, Child 1, Child 2, Grandchild = 4 nodes
      // - Title Character Count:
      //   Root: 'Root'.length = 4
      //   Child 1: 'Child 1 Title'.length = 13
      //   Child 2: 'Child 2 Title'.length = 13
      //   Grandchild: 'Grandchild'.length = 10
      //   Sum: 4 + 13 + 13 + 10 = 40 characters
      // - Note Character Count:
      //   Root: 'Root note content text'.length = 22
      //   Child 1: 'C1 Content'.length = 10
      //   Child 2: 'C2 Content Text'.length = 15
      //   Grandchild: 'Grandchild text'.length = 15
      //   Sum: 22 + 10 + 15 + 15 = 62 characters
      // - Total Words Count: Title + Note = 40 + 62 = 102 characters
      // - Container Count (highlightStyle == 'nestedCard'): Child 1 = 1
      // - Max Depth: Root (1) -> Child 2 (2) -> Grandchild (3) = 3 layers
      // - Associated Documents: ['pdf1', 'pdf2', 'pdf3'] = 3

      // Verify mathematical logic inside the InfoStatisticsModal build
      bool closeCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InfoStatisticsModal(
            controller: controller,
            onClose: () => closeCalled = true,
          ),
        ),
      ));

      expect(find.text('关于导图'), findsOneWidget);
      expect(find.text('4 个'), findsOneWidget); // 节点总数
      expect(find.text('1 个'), findsOneWidget); // 嵌套容器
      expect(find.text('40 字'), findsOneWidget); // 标题字数
      expect(find.text('62 字'), findsOneWidget); // 笔记字数
      expect(find.text('102 字'), findsOneWidget); // 总字数统计
      expect(find.text('3 层'), findsOneWidget); // 最大深度
      expect(find.text('3 篇'), findsOneWidget); // 关联文档

      // Tap close button and check callback
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closeCalled, isTrue);
    });

    testWidgets('MindMapPage integrates statistics modal opening and closing', (tester) async {
      await controller.createTopic('Integration Topic');
      await controller.createNote(title: 'Root node');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      // Modal should not be visible initially
      expect(find.byType(InfoStatisticsModal), findsNothing);

      // Tap bottom action bar statistics button
      expect(find.byKey(const ValueKey('info_statistics')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('info_statistics')));
      await tester.pump();

      // Modal should be visible now
      expect(find.byType(InfoStatisticsModal), findsOneWidget);

      // Tap on the close button to close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Modal should be closed
      expect(find.byType(InfoStatisticsModal), findsNothing);

      // Open it again
      await tester.tap(find.byKey(const ValueKey('info_statistics')));
      await tester.pump();
      expect(find.byType(InfoStatisticsModal), findsOneWidget);

      // Tap the background black overlay at Offset(100, 100) to close it
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      // Modal should be closed
      expect(find.byType(InfoStatisticsModal), findsNothing);
    });
  });
}
