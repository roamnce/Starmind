// test/mindmap/regression/v15_persistence_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('v15 persistence smoke', () {
    late InMemoryMindMapRepository repository;

    setUp(() {
      repository = InMemoryMindMapRepository();
    });

    test('topic layout direction persists through update', () async {
      final topicId = await repository.createTopic('Test');
      var topic = await repository.getTopic(topicId);
      expect(topic!.layoutDirection, 'both');

      await repository.updateTopic(topic.copyWith(layoutDirection: 'left'));
      topic = await repository.getTopic(topicId);
      expect(topic!.layoutDirection, 'left');
    });

    test('topic layout style persists through update', () async {
      final topicId = await repository.createTopic('Test');
      var topic = await repository.getTopic(topicId);
      expect(topic!.layoutStyle, 'tree');

      await repository.updateTopic(topic.copyWith(layoutStyle: 'framework'));
      topic = await repository.getTopic(topicId);
      expect(topic!.layoutStyle, 'framework');
    });

    test('relation persists across topic reload', () async {
      final topicId = await repository.createTopic('Test');
      final n1 = await repository.createNote(topicId, 'A');
      await Future.delayed(const Duration(milliseconds: 10));
      final n2 = await repository.createNote(topicId, 'B');

      await repository.createRelation(
        topicId: topicId,
        sourceNoteId: n1,
        targetNoteId: n2,
        text: 'test relation',
      );

      var relations = await repository.listRelations(topicId);
      expect(relations.length, 1);
      expect(relations.first.text, 'test relation');

      // Simulate reload
      relations = await repository.listRelations(topicId);
      expect(relations.length, 1);
    });

    test('summary persists across topic reload', () async {
      final topicId = await repository.createTopic('Test');
      final root = await repository.createNote(topicId, 'Root');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createNote(topicId, 'C1');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createNote(topicId, 'C2');

      await repository.createSummary(
        topicId: topicId,
        parentId: root,
        startIndex: 0,
        endIndex: 1,
        text: 'Summary text',
      );

      var summaries = await repository.listSummaries(topicId);
      expect(summaries.length, 1);
      expect(summaries.first.text, 'Summary text');
    });

    test('node tag bindings persist across reload', () async {
      final topicId = await repository.createTopic('Test');
      final noteId = await repository.createNote(topicId, 'Node');

      await repository.bindTagToNote(noteId: noteId, tagId: 'tag-1');
      await repository.bindTagToNote(noteId: noteId, tagId: 'tag-2');

      var tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds.length, 2);
      expect(tagIds, containsAll(['tag-1', 'tag-2']));

      // Simulate reload
      tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds.length, 2);
    });

    test('unbind tag keeps global binding intact', () async {
      final topicId = await repository.createTopic('Test');
      final noteId = await repository.createNote(topicId, 'Node');

      await repository.bindTagToNote(noteId: noteId, tagId: 'tag-1');
      await repository.unbindTagFromNote(noteId: noteId, tagId: 'tag-1');

      var tagIds = await repository.listTagIdsForNote(noteId);
      expect(tagIds, isEmpty);
    });
  });
}
