import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/import/gurumind_importer.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  final sample = File(r'D:\个人文件\Downloads\演示.gurumind');

  test('imports the real GuruMind sample when available', () async {
    final repository = InMemoryMindMapRepository();
    final importer = GuruMindImporter(repository: repository);

    final result = await importer.importFile(sample.path);

    expect(result.isSuccess, isTrue);
    expect(result.topic?.title, isNotEmpty);
    expect(result.notes.length, greaterThan(1));
  }, skip: sample.existsSync() ? false : 'Real GuruMind sample file is not available on this machine.');
}
