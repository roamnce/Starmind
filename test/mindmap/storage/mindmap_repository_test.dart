// test/mindmap/storage/mindmap_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  late InMemoryMindMapRepository repository;

  setUp(() {
    repository = InMemoryMindMapRepository();
  });

  group('MindMapRepository', () {
    test('creates and retrieves topic', () async {
      final topicId = await repository.createTopic('Test Topic', author: 'Test Author');

      final topic = await repository.getTopic(topicId);

      expect(topic, isNotNull);
      expect(topic!.title, 'Test Topic');
      expect(topic.author, 'Test Author');
      expect(topic.id, startsWith('0-'));
    });

    test('creates note with parent-child relationship', () async {
      // 创建导图
      final topicId = await repository.createTopic('Test Topic');

      // 创建父节点
      final parentId = await repository.createNote(topicId, 'Parent Node');

      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一

      // 创建子节点
      final childId = await repository.createNote(topicId, 'Child Node');

      // 建立关系
      await repository.addChild(parentId, childId);

      // 验证关系
      final children = await repository.getChildren(parentId);
      expect(children.length, 1);
      expect(children[0].id, childId);
      expect(children[0].parentId, parentId);
    });

    test('queries notes by PDF ID', () async {
      final topicId = await repository.createTopic('Test Topic');

      // 创建带 PDF 关联的节点
      final note1Id = await repository.createNote(topicId, 'Note 1');
      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一
      final note2Id = await repository.createNote(topicId, 'Note 2');

      // 手动更新节点添加 PDF ID
      await repository.updateNote(Note(
        id: note1Id,
        topicId: topicId,
        title: 'Note 1',
        pdfId: 'pdf-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repository.updateNote(Note(
        id: note2Id,
        topicId: topicId,
        title: 'Note 2',
        pdfId: 'pdf-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 查询
      final notes = await repository.getNotesByPdf('pdf-123');
      expect(notes.length, 2);
    });

    test('removes child from parent', () async {
      final topicId = await repository.createTopic('Test Topic');
      final parentId = await repository.createNote(topicId, 'Parent');
      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一
      final childId = await repository.createNote(topicId, 'Child');

      await repository.addChild(parentId, childId);

      // 验证添加成功
      var children = await repository.getChildren(parentId);
      expect(children.length, 1);

      // 移除子节点
      await repository.removeChild(parentId, childId);

      // 验证移除成功
      children = await repository.getChildren(parentId);
      expect(children.length, 0);

      // 验证子节点的 parentId 被清除
      final child = await repository.getNote(childId);
      expect(child!.parentId, isNull);
    });

    test('soft deletes topic', () async {
      final topicId = await repository.createTopic('Test Topic');

      await repository.trashTopic(topicId);

      final topic = await repository.getTopic(topicId);
      expect(topic!.isTrashed, true);

      // getAllTopics 不应包含已删除的
      final allTopics = await repository.getAllTopics();
      expect(allTopics.where((t) => t.id == topicId).isEmpty, true);
    });

    test('queries notes by topic ID', () async {
      final topicId1 = await repository.createTopic('Topic 1');
      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一
      final topicId2 = await repository.createTopic('Topic 2');

      await repository.createNote(topicId1, 'Note 1-1');
      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一
      await repository.createNote(topicId1, 'Note 1-2');
      await Future.delayed(const Duration(milliseconds: 10)); // 确保ID唯一
      await repository.createNote(topicId2, 'Note 2-1');

      final notes1 = await repository.getNotesByTopic(topicId1);
      expect(notes1.length, 2);

      final notes2 = await repository.getNotesByTopic(topicId2);
      expect(notes2.length, 1);
    });
  });
}