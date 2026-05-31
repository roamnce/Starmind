// test/mindmap/ui/mindmap_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('MindMapController', () {
    late MindMapController controller;

    setUp(() {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has empty topic list', () {
      expect(controller.topics, isEmpty);
      expect(controller.selectedTopic, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('loadTopics populates topic list', () async {
      await controller.createTopic('笔记本1');
      await controller.createTopic('笔记本2');
      await controller.loadTopics();

      expect(controller.topics.length, equals(2));
    });

    test('createTopic adds to list and selects it', () async {
      final topic = await controller.createTopic('新笔记本');

      expect(controller.topics.contains(topic), isTrue);
      expect(controller.selectedTopic, equals(topic));
    });

    test('selectTopic updates selectedTopic', () async {
      final topic = await controller.createTopic('测试笔记本');

      controller.selectTopic(null);
      expect(controller.selectedTopic, isNull);

      controller.selectTopic(topic);
      expect(controller.selectedTopic, equals(topic));
    });

    test('trashTopic removes from list', () async {
      final topic = await controller.createTopic('待删除笔记本');
      expect(controller.topics.contains(topic), isTrue);

      await controller.trashTopic(topic.id);
      expect(controller.topics.contains(topic), isFalse);
    });

    group('Viewport', () {
      test('initial viewport is identity', () {
        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });

      test('zoom in increases scale', () {
        controller.zoomIn();
        expect(controller.viewportScale, greaterThan(1.0));
      });

      test('zoom out decreases scale', () {
        controller.zoomOut();
        expect(controller.viewportScale, lessThan(1.0));
      });

      test('zoom has limits', () {
        // 多次放大
        for (var i = 0; i < 20; i++) {
          controller.zoomIn();
        }
        expect(controller.viewportScale, lessThanOrEqualTo(4.0));

        // 多次缩小
        for (var i = 0; i < 20; i++) {
          controller.zoomOut();
        }
        expect(controller.viewportScale, greaterThanOrEqualTo(0.1));
      });

      test('resetViewport restores identity', () {
        controller.zoomIn();
        controller.pan(const Offset(100, 100));

        controller.resetViewport();

        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });
    });
  });
}
