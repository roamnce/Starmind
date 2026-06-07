import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/export/gurumind_exporter.dart';
import 'package:starmind/src/mindmap/import/gurumind_importer.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  test('GuruMind export and import preserves topic and notes', () async {
    final now = DateTime.utc(2026, 6, 3);
    final topic = Topic(
      id: '0-topic',
      title: 'Topic',
      rootNoteIds: const ['1-root'],
      createdAt: now,
      updatedAt: now,
    );
    final notes = [
      Note(id: '1-root', topicId: topic.id, title: 'Root', childIds: const ['1-child'], createdAt: now, updatedAt: now),
      Note(id: '1-child', topicId: topic.id, parentId: '1-root', title: 'Child', createdAt: now, updatedAt: now),
    ];
    final dir = await Directory.systemTemp.createTemp('starmind_gurumind_');
    final outputPath = '${dir.path}/topic.gurumind';

    await GuruMindDataExporter().exportTopic(topic: topic, notes: notes, outputPath: outputPath);

    final repository = InMemoryMindMapRepository();
    final result = await GuruMindImporter(repository: repository).importFile(outputPath);

    expect(result.isSuccess, isTrue);
    expect((await repository.getTopic(topic.id))!.title, 'Topic');
    expect(await repository.getNotesByTopic(topic.id), hasLength(2));
  });

  test('GuruMind export uses documents directory with meta and hive payloads', () async {
    final now = DateTime.utc(2026, 6, 3);
    final topic = Topic(
      id: '0-topic',
      title: 'Topic',
      rootNoteIds: const ['1-root'],
      createdAt: now,
      updatedAt: now,
    );
    final notes = [
      Note(id: '1-root', topicId: topic.id, title: 'Root', createdAt: now, updatedAt: now),
    ];
    final dir = await Directory.systemTemp.createTemp('starmind_gurumind_shape_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final outputPath = '${dir.path}/topic.gurumind';

    await GuruMindDataExporter().exportTopic(topic: topic, notes: notes, outputPath: outputPath);

    final archive = ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
    final files = {for (final file in archive.files) file.name: file};
    expect(files, contains('manifest.json'));
    expect(files, contains('documents/0-topic/meta.json'));
    expect(files, contains('documents/0-topic/doc_0-topic.hive'));
    expect(files, contains('documents/root/meta.json'));
    expect(files, contains('documents/root/doc_root.hive'));
    expect(files, contains('documents/0-topic/assets/thumb.png'));

    final manifest = jsonDecode(utf8.decode(files['manifest.json']!.content as List<int>)) as Map<String, dynamic>;
    expect(manifest['documents'], [
      {'id': '0-topic', 'type': 'mindMap', 'title': 'Topic'},
    ]);
    final hive = files['documents/0-topic/doc_0-topic.hive']!.content as List<int>;
    expect(hive.take(4).toList(), [0xFA, 0x42, 0x00, 0x00]);
  });

}
