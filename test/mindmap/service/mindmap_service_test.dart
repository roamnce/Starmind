// test/mindmap/service/mindmap_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('MindMapService', () {
    late MindMapService service;

    setUp(() {
      service = MindMapService(InMemoryMindMapRepository());
    });

    test('createTopic returns Topic with correct title', () async {
      final topic = await service.createTopic('我的笔记本');

      expect(topic.title, equals('我的笔记本'));
      expect(topic.id.startsWith('0-'), isTrue);
    });

    test('createNoteInTopic creates note linked to topic', () async {
      final topic = await service.createTopic('测试笔记本');
      final note = await service.createNote(
        topicId: topic.id,
        title: '第一个节点',
      );

      expect(note.title, equals('第一个节点'));
      expect(note.topicId, equals(topic.id));
      expect(note.id.startsWith('1-'), isTrue);
    });

    test('addChildNote creates parent-child relationship', () async {
      final topic = await service.createTopic('测试笔记本');
      final parent = await service.createNote(
        topicId: topic.id,
        title: '父节点',
      );
      // Small delay to ensure unique IDs
      await Future.delayed(const Duration(milliseconds: 10));
      final child = await service.createNote(
        topicId: topic.id,
        title: '子节点',
        parentId: parent.id,
      );

      await service.addChild(parentId: parent.id, childId: child.id);

      final children = await service.getChildren(parent.id);
      expect(children.length, equals(1));
      expect(children.first.id, equals(child.id));
    });

    test('getTopicTree returns all notes in tree structure', () async {
      final topic = await service.createTopic('测试笔记本');
      final root = await service.createNote(
        topicId: topic.id,
        title: '根节点',
      );
      // Small delay to ensure unique IDs
      await Future.delayed(const Duration(milliseconds: 10));
      final child1 = await service.createNote(
        topicId: topic.id,
        title: '子节点1',
        parentId: root.id,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      final child2 = await service.createNote(
        topicId: topic.id,
        title: '子节点2',
        parentId: root.id,
      );

      await service.addChild(parentId: root.id, childId: child1.id);
      await service.addChild(parentId: root.id, childId: child2.id);

      // 添加为根节点
      await service.addRootNote(topicId: topic.id, noteId: root.id);

      final tree = await service.getTopicTree(topic.id);
      expect(tree.length, equals(1));
      expect(tree.first.note.id, equals(root.id));
      expect(tree.first.children.length, equals(2));
    });
  });
}
