import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mindmap_relation.dart';
import 'package:starmind/src/mindmap/domain/mindmap_summary.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/export/gurumind_exporter.dart';
import 'package:starmind/src/mindmap/import/gurumind_importer.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('starmind_v15_roundtrip_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  group('v15 export includes relations, summaries, and tags', () {
    test('exported manifest contains relations array', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', childIds: const ['1-a', '1-b'], createdAt: now, updatedAt: now),
        Note(id: '1-a', topicId: '0-t', parentId: '1-r', title: 'A', createdAt: now, updatedAt: now),
        Note(id: '1-b', topicId: '0-t', parentId: '1-r', title: 'B', createdAt: now, updatedAt: now),
      ];
      final relations = [
        MindMapRelation(id: 'rel-1', topicId: '0-t', sourceNoteId: '1-a', targetNoteId: '1-b', text: 'links', createdAt: now, updatedAt: now),
      ];
      final outputPath = '${tmpDir.path}/export.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic,
        notes: notes,
        outputPath: outputPath,
        relations: relations,
      );

      final archive = ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final manifestBytes = archive.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>;
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

      expect(manifest['relations'], isNotNull);
      final relList = manifest['relations'] as List;
      expect(relList, hasLength(1));
      expect((relList[0] as Map)['text'], 'links');
    });

    test('exported manifest contains summaries array', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', createdAt: now, updatedAt: now),
      ];
      final summaries = [
        MindMapSummary(id: 'sum-1', topicId: '0-t', parentId: '1-r', startIndex: 0, endIndex: 2, text: '总结', createdAt: now, updatedAt: now),
      ];
      final outputPath = '${tmpDir.path}/export.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic,
        notes: notes,
        outputPath: outputPath,
        summaries: summaries,
      );

      final archive = ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final manifestBytes = archive.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>;
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

      expect(manifest['summaries'], isNotNull);
      final sumList = manifest['summaries'] as List;
      expect(sumList, hasLength(1));
      expect((sumList[0] as Map)['text'], '总结');
    });

    test('exported manifest contains nodeTags map', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', createdAt: now, updatedAt: now),
      ];
      final tagsByNoteId = {'1-r': ['important', 'review']};
      final outputPath = '${tmpDir.path}/export.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic,
        notes: notes,
        outputPath: outputPath,
        tagsByNoteId: tagsByNoteId,
      );

      final archive = ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final manifestBytes = archive.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>;
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

      expect(manifest['nodeTags'], isNotNull);
      final tags = manifest['nodeTags'] as Map<String, dynamic>;
      expect(tags['1-r'], ['important', 'review']);
    });
  });

  group('v15 import restores relations, summaries, and tags', () {
    test('import round-trip preserves relations', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', childIds: const ['1-a', '1-b'], createdAt: now, updatedAt: now),
        Note(id: '1-a', topicId: '0-t', parentId: '1-r', title: 'A', createdAt: now, updatedAt: now),
        Note(id: '1-b', topicId: '0-t', parentId: '1-r', title: 'B', createdAt: now, updatedAt: now),
      ];
      final relations = [
        MindMapRelation(id: 'rel-1', topicId: '0-t', sourceNoteId: '1-a', targetNoteId: '1-b', text: 'related', createdAt: now, updatedAt: now),
      ];
      final outputPath = '${tmpDir.path}/roundtrip.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic, notes: notes, outputPath: outputPath, relations: relations,
      );

      final repo = InMemoryMindMapRepository();
      final result = await GuruMindImporter(repository: repo).importFile(outputPath);
      expect(result.isSuccess, isTrue);

      final imported = await repo.listRelations('0-t');
      expect(imported, hasLength(1));
      expect(imported.first.sourceNoteId, '1-a');
      expect(imported.first.targetNoteId, '1-b');
      expect(imported.first.text, 'related');
    });

    test('import round-trip preserves summaries', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', childIds: const ['1-a'], createdAt: now, updatedAt: now),
        Note(id: '1-a', topicId: '0-t', parentId: '1-r', title: 'A', createdAt: now, updatedAt: now),
      ];
      final summaries = [
        MindMapSummary(id: 'sum-1', topicId: '0-t', parentId: '1-r', startIndex: 0, endIndex: 0, text: '要点', createdAt: now, updatedAt: now),
      ];
      final outputPath = '${tmpDir.path}/roundtrip.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic, notes: notes, outputPath: outputPath, summaries: summaries,
      );

      final repo = InMemoryMindMapRepository();
      final result = await GuruMindImporter(repository: repo).importFile(outputPath);
      expect(result.isSuccess, isTrue);

      final imported = await repo.listSummaries('0-t');
      expect(imported, hasLength(1));
      expect(imported.first.parentId, '1-r');
      expect(imported.first.startIndex, 0);
      expect(imported.first.endIndex, 0);
      expect(imported.first.text, '要点');
    });

    test('import round-trip preserves node tags', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', createdAt: now, updatedAt: now),
      ];
      final tagsByNoteId = {'1-r': ['important', 'review']};
      final outputPath = '${tmpDir.path}/roundtrip.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic, notes: notes, outputPath: outputPath, tagsByNoteId: tagsByNoteId,
      );

      final repo = InMemoryMindMapRepository();
      final result = await GuruMindImporter(repository: repo).importFile(outputPath);
      expect(result.isSuccess, isTrue);

      final tagIds = await repo.listTagIdsForNote('1-r');
      expect(tagIds, hasLength(2));

      final tagTree = await repo.getTagTree();
      final tagNames = tagTree.children.map((t) => t.name).toSet();
      expect(tagNames, containsAll(['important', 'review']));
    });

    test('import without v15 data does not fail', () async {
      final now = DateTime.utc(2026, 6, 10);
      final topic = Topic(id: '0-t', title: 'T', rootNoteIds: const ['1-r'], createdAt: now, updatedAt: now);
      final notes = [
        Note(id: '1-r', topicId: '0-t', title: 'Root', createdAt: now, updatedAt: now),
      ];
      final outputPath = '${tmpDir.path}/legacy.gurumind';

      await GuruMindDataExporter().exportTopic(
        topic: topic, notes: notes, outputPath: outputPath,
      );

      final repo = InMemoryMindMapRepository();
      final result = await GuruMindImporter(repository: repo).importFile(outputPath);
      expect(result.isSuccess, isTrue);

      final relations = await repo.listRelations('0-t');
      expect(relations, isEmpty);
      final summaries = await repo.listSummaries('0-t');
      expect(summaries, isEmpty);
    });
  });

  group('v15 service export includes v15 data', () {
    test('exportGuruMindTopic serializes relations, summaries, and tags', () async {
      final repo = InMemoryMindMapRepository();
      final service = MindMapService(repo);

      final topic = await service.createTopic('Export Test');
      final root = await service.createNote(topicId: topic.id, title: 'Root');
      final child1 = await service.createNote(topicId: topic.id, title: 'C1', parentId: root.id);
      await Future.delayed(const Duration(milliseconds: 10));
      final child2 = await service.createNote(topicId: topic.id, title: 'C2', parentId: root.id);
      await service.addChild(parentId: root.id, childId: child1.id);
      await service.addChild(parentId: root.id, childId: child2.id);

      await service.createRelation(topicId: topic.id, sourceNoteId: child1.id, targetNoteId: child2.id, text: 'test-rel');
      await service.createSummariesFromSelectedNoteIds(topicId: topic.id, selectedNoteIds: {child1.id, child2.id});

      final tagId = await service.createTag('priority', null, null);
      await service.bindTagToNote(noteId: child1.id, tagId: tagId);

      final outputPath = '${tmpDir.path}/service_export.gurumind';
      await service.exportGuruMindTopic(topicId: topic.id, outputPath: outputPath);

      final archive = ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
      final manifestBytes = archive.files.firstWhere((f) => f.name == 'manifest.json').content as List<int>;
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

      expect(manifest['relations'], isNotNull);
      expect((manifest['relations'] as List), hasLength(1));

      expect(manifest['summaries'], isNotNull);
      expect((manifest['summaries'] as List), hasLength(1));

      expect(manifest['nodeTags'], isNotNull);
      final nodeTags = manifest['nodeTags'] as Map<String, dynamic>;
      expect(nodeTags[child1.id], contains('priority'));
    });
  });
}
