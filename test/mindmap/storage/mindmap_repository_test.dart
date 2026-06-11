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

  group('Relation CRUD', () {
    test('relation CRUD prevents same-direction duplicates', () async {
      final topicId = await repository.createTopic('topic');
      final sourceId = await repository.createNote(topicId, 'source');
      await Future.delayed(const Duration(milliseconds: 10));
      final targetId = await repository.createNote(topicId, 'target');

      final created = await repository.createRelation(
        topicId: topicId,
        sourceNoteId: sourceId,
        targetNoteId: targetId,
      );
      final duplicate = await repository.createRelation(
        topicId: topicId,
        sourceNoteId: sourceId,
        targetNoteId: targetId,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      final reverse = await repository.createRelation(
        topicId: topicId,
        sourceNoteId: targetId,
        targetNoteId: sourceId,
      );

      expect(duplicate, created);
      expect(reverse, isNot(created));
      expect(await repository.listRelations(topicId), hasLength(2));
    });

    test('deleting a note removes connected relations', () async {
      final topicId = await repository.createTopic('topic');
      final sourceId = await repository.createNote(topicId, 'source');
      await Future.delayed(const Duration(milliseconds: 10));
      final targetId = await repository.createNote(topicId, 'target');
      await repository.createRelation(
        topicId: topicId,
        sourceNoteId: sourceId,
        targetNoteId: targetId,
      );

      await repository.deleteNote(targetId);

      expect(await repository.listRelations(topicId), isEmpty);
    });

    test('updateRelation persists text changes', () async {
      final topicId = await repository.createTopic('topic');
      final sourceId = await repository.createNote(topicId, 'source');
      await Future.delayed(const Duration(milliseconds: 10));
      final targetId = await repository.createNote(topicId, 'target');

      final id = await repository.createRelation(
        topicId: topicId,
        sourceNoteId: sourceId,
        targetNoteId: targetId,
      );

      final relation = await repository.getRelation(id);
      await repository.updateRelation(relation!.copyWith(text: 'depends on'));

      final updated = await repository.getRelation(id);
      expect(updated!.text, 'depends on');
    });
  });

  group('Summary CRUD', () {
    test('summary CRUD prevents duplicate ranges', () async {
      final topicId = await repository.createTopic('topic');
      final parentId = await repository.createNote(topicId, 'parent');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createNote(topicId, 'child1');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createNote(topicId, 'child2');

      final first = await repository.createSummary(
        topicId: topicId,
        parentId: parentId,
        startIndex: 0,
        endIndex: 1,
      );
      final duplicate = await repository.createSummary(
        topicId: topicId,
        parentId: parentId,
        startIndex: 0,
        endIndex: 1,
      );

      expect(duplicate, first);
      expect(await repository.listSummaries(topicId), hasLength(1));
    });

    test('deleting a parent note removes its summaries', () async {
      final topicId = await repository.createTopic('topic');
      final parentId = await repository.createNote(topicId, 'parent');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createNote(topicId, 'child1');

      await repository.createSummary(
        topicId: topicId,
        parentId: parentId,
        startIndex: 0,
        endIndex: 0,
      );

      await repository.deleteNote(parentId);

      expect(await repository.listSummaries(topicId), isEmpty);
    });

    test('listSummaries returns sorted by parent then start index', () async {
      final topicId = await repository.createTopic('topic');
      final parent1 = await repository.createNote(topicId, 'parent1');
      await Future.delayed(const Duration(milliseconds: 10));
      final parent2 = await repository.createNote(topicId, 'parent2');

      await repository.createSummary(
        topicId: topicId,
        parentId: parent2,
        startIndex: 0,
        endIndex: 0,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createSummary(
        topicId: topicId,
        parentId: parent1,
        startIndex: 1,
        endIndex: 2,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createSummary(
        topicId: topicId,
        parentId: parent1,
        startIndex: 0,
        endIndex: 0,
      );

      final summaries = await repository.listSummaries(topicId);
      expect(summaries, hasLength(3));
      expect(summaries[0].parentId, parent1);
      expect(summaries[0].startIndex, 0);
      expect(summaries[1].parentId, parent1);
      expect(summaries[1].startIndex, 1);
      expect(summaries[2].parentId, parent2);
    });
  });

  group('Tag Binding', () {
    test('bindTagToNote and listTagIdsForNote', () async {
      final topicId = await repository.createTopic('topic');
      final noteId = await repository.createNote(topicId, 'note');
      final tagId = await repository.createTag('标签1', null, '#FF6B6B');

      await repository.bindTagToNote(noteId: noteId, tagId: tagId);

      final tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds, contains(tagId));
    });

    test('unbindTagFromNote removes binding', () async {
      final topicId = await repository.createTopic('topic');
      final noteId = await repository.createNote(topicId, 'note');
      final tagId = await repository.createTag('标签1', null, '#FF6B6B');

      await repository.bindTagToNote(noteId: noteId, tagId: tagId);
      await repository.unbindTagFromNote(noteId: noteId, tagId: tagId);

      final tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds, isEmpty);
    });

    test('deleteNoteTagBindingsForNote removes all bindings', () async {
      final topicId = await repository.createTopic('topic');
      final noteId = await repository.createNote(topicId, 'note');
      final tag1 = await repository.createTag('标签1', null, '#FF6B6B');
      final tag2 = await repository.createTag('标签2', null, '#6BCB77');

      await repository.bindTagToNote(noteId: noteId, tagId: tag1);
      await repository.bindTagToNote(noteId: noteId, tagId: tag2);

      await repository.deleteNoteTagBindingsForNote(noteId);

      final tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds, isEmpty);
    });

    test('getTagTree returns hierarchical tags', () async {
      final parentId = await repository.createTag('父标签', null, '#FF6B6B');
      final childId = await repository.createTag('子标签', parentId, '#6BCB77');

      final tree = await repository.getTagTree();

      // 树中应包含父标签和子标签
      expect(tree.children, isNotEmpty);

      // 查找父标签
      final parentTag = tree.children.firstWhere((t) => t.id == parentId, orElse: () => tree);
      expect(parentTag.name, '父标签');
      expect(parentTag.children.any((t) => t.id == childId), isTrue);
    });

    test('note can have multiple tags', () async {
      final topicId = await repository.createTopic('topic');
      final noteId = await repository.createNote(topicId, 'note');
      final tag1 = await repository.createTag('标签1', null, '#FF6B6B');
      final tag2 = await repository.createTag('标签2', null, '#6BCB77');
      final tag3 = await repository.createTag('标签3', null, '#4D96FF');

      await repository.bindTagToNote(noteId: noteId, tagId: tag1);
      await repository.bindTagToNote(noteId: noteId, tagId: tag2);
      await repository.bindTagToNote(noteId: noteId, tagId: tag3);

      final tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds.length, 3);
      expect(tagIds, containsAll([tag1, tag2, tag3]));
    });
  });
}