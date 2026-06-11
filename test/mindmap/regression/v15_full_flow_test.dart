// test/mindmap/regression/v15_full_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';

void main() {
  group('v15 full flow regression', () {
    late InMemoryMindMapRepository repository;
    late MindMapService service;

    setUp(() {
      repository = InMemoryMindMapRepository();
      service = MindMapService(repository);
    });

    test('scenario 1: create topic, notes, relations, summaries, tags', () async {
      // 创建 topic
      final topic = await service.createTopic('Test Topic');
      expect(topic.title, 'Test Topic');

      // 创建节点
      final root = await service.createNote(topicId: topic.id, title: 'Root');
      final child1 = await service.createNote(topicId: topic.id, title: 'Child 1', parentId: root.id);
      await Future.delayed(const Duration(milliseconds: 10));
      final child2 = await service.createNote(topicId: topic.id, title: 'Child 2', parentId: root.id);

      // 添加子节点关系
      await service.addChild(parentId: root.id, childId: child1.id);
      await service.addChild(parentId: root.id, childId: child2.id);

      // 创建关联线
      final relation = await service.createRelation(
        topicId: topic.id,
        sourceNoteId: child1.id,
        targetNoteId: child2.id,
        text: 'relates to',
      );
      expect(relation.text, 'relates to');

      // 创建概要
      final summaries = await service.createSummariesFromSelectedNoteIds(
        topicId: topic.id,
        selectedNoteIds: {child1.id, child2.id},
      );
      expect(summaries.length, 1);

      // 绑定标签
      await service.bindTagToNote(noteId: child1.id, tagId: 'tag-1');
      await service.bindTagToNote(noteId: child2.id, tagId: 'tag-2');

      // 验证数据
      final relations = await service.listRelations(topic.id);
      expect(relations.length, 1);

      final allSummaries = await service.listSummaries(topic.id);
      expect(allSummaries.length, 1);

      final tags1 = await service.listTagIdsForNote(child1.id);
      expect(tags1, contains('tag-1'));

      final tags2 = await service.listTagIdsForNote(child2.id);
      expect(tags2, contains('tag-2'));
    });

    test('scenario 2: delete node cascades relations and tags', () async {
      final topic = await service.createTopic('Test');
      final root = await service.createNote(topicId: topic.id, title: 'Root');
      final child = await service.createNote(topicId: topic.id, title: 'Child', parentId: root.id);

      await service.addChild(parentId: root.id, childId: child.id);

      // 创建关联线
      await service.createRelation(
        topicId: topic.id,
        sourceNoteId: root.id,
        targetNoteId: child.id,
      );

      // 绑定标签
      await service.bindTagToNote(noteId: child.id, tagId: 'tag-1');

      // 删除子节点
      await service.deleteNote(child.id);

      // 验证级联删除
      final relations = await service.listRelations(topic.id);
      expect(relations, isEmpty);

      final tags = await service.listTagIdsForNote(child.id);
      expect(tags, isEmpty);
    });

    test('scenario 3: relation same-direction dedup', () async {
      final topic = await service.createTopic('Test');
      final n1 = await service.createNote(topicId: topic.id, title: 'A');
      await Future.delayed(const Duration(milliseconds: 10));
      final n2 = await service.createNote(topicId: topic.id, title: 'B');

      final first = await service.createRelation(
        topicId: topic.id,
        sourceNoteId: n1.id,
        targetNoteId: n2.id,
      );
      final second = await service.createRelation(
        topicId: topic.id,
        sourceNoteId: n1.id,
        targetNoteId: n2.id,
      );

      expect(second.id, first.id);

      // Reverse is different
      final reverse = await service.createRelation(
        topicId: topic.id,
        sourceNoteId: n2.id,
        targetNoteId: n1.id,
      );
      expect(reverse.id, isNot(first.id));

      final all = await service.listRelations(topic.id);
      expect(all.length, 2);
    });

    test('scenario 4: summary range normalization', () async {
      final topic = await service.createTopic('Test');
      final root = await service.createNote(topicId: topic.id, title: 'Root');
      final c1 = await service.createNote(topicId: topic.id, title: 'C1', parentId: root.id);
      await Future.delayed(const Duration(milliseconds: 10));
      final c2 = await service.createNote(topicId: topic.id, title: 'C2', parentId: root.id);
      await Future.delayed(const Duration(milliseconds: 10));
      final c3 = await service.createNote(topicId: topic.id, title: 'C3', parentId: root.id);

      // 添加子节点关系
      await service.addChild(parentId: root.id, childId: c1.id);
      await service.addChild(parentId: root.id, childId: c2.id);
      await service.addChild(parentId: root.id, childId: c3.id);

      // 创建概要（选择 C1 和 C3，应该扩展到 C1-C3 连续区间）
      await service.createSummariesFromSelectedNoteIds(
        topicId: topic.id,
        selectedNoteIds: {c1.id, c3.id},
      );

      // 验证概要创建
      final allSummaries = await service.listSummaries(topic.id);
      expect(allSummaries.length, 1);
      expect(allSummaries.first.startIndex, 0);
      expect(allSummaries.first.endIndex, 2);
    });

    test('scenario 5: topic layout settings persist', () async {
      final topic = await service.createTopic('Test');

      // 更新布局方向
      await repository.updateTopic(topic.copyWith(layoutDirection: 'left'));
      var updated = await service.getTopic(topic.id);
      expect(updated!.layoutDirection, 'left');

      // 更新布局样式
      await repository.updateTopic(updated.copyWith(layoutStyle: 'framework'));
      updated = await service.getTopic(topic.id);
      expect(updated!.layoutStyle, 'framework');
      expect(updated.layoutDirection, 'left'); // 不变
    });
  });
}
