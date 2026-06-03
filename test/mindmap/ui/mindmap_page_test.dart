// test/mindmap/ui/mindmap_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('MindMapPage', () {
    late MindMapController controller;

    setUp(() async {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
      // Create test data
      await controller.createTopic('Test Notebook');
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('shows empty state when no nodes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('No nodes'), findsOneWidget);
    });

    testWidgets('shows zoom controls', (tester) async {
      await controller.createNote(title: 'Root Node');
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen_rounded), findsOneWidget);
    });

    testWidgets('shows nodes after creation', (tester) async {
      await controller.createNote(title: 'Root Node');
      await controller.createNote(title: 'Second Node');

      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Root Node'), findsOneWidget);
      expect(find.text('Second Node'), findsOneWidget);
    });

    testWidgets('zoom in button increases scale', (tester) async {
      await controller.createNote(title: 'Root Node');
      await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => MindMapPage(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      final initialScale = controller.viewportScale;

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(controller.viewportScale, greaterThan(initialScale));
    });
  });
}
