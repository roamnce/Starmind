// test/mindmap/storage/ffi_mindmap_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/storage/ffi_mindmap_repository.dart';

/// FFI 集成测试
///
/// 这些测试需要 Rust 后端已初始化（RustLib.init）。
/// 通常在应用启动时调用 RustLib.init()。
///
/// 注意：这些测试依赖于实际的 SQLite 数据库，
/// 需要在测试环境中提供数据库路径。
void main() {
  group('FfiMindMapRepository', () {
    late FfiMindMapRepository repository;

    setUpAll(() async {
      // 初始化 Rust FFI
      // 在实际测试中，需要提供数据库路径
      // await RustLib.init();
      // await init_storage(db_path: 'test.db', sandbox_dir: 'test_sandbox');
    });

    setUp(() {
      repository = FfiMindMapRepository();
    });

    group('Topic CRUD', () {
      test('createTopic returns ID with prefix "0-"', () async {
        // 这个测试需要 Rust 后端已初始化
        // 实际运行时取消 skip

        final id = await repository.createTopic('测试笔记本');
        expect(id.startsWith('0-'), isTrue);
        expect(id.length, greaterThan(2)); // "0-" + UUID
      });

      test('getTopic returns created topic', () async {
        final id = await repository.createTopic('测试笔记本', author: '测试作者');
        final topic = await repository.getTopic(id);

        expect(topic, isNotNull);
        expect(topic!.id, equals(id));
        expect(topic.title, equals('测试笔记本'));
        expect(topic.author, equals('测试作者'));
      });

      test('updateTopic modifies title', () async {
        final id = await repository.createTopic('原标题');
        final topic = await repository.getTopic(id);

        final updatedTopic = topic!.copyWith(
          title: '新标题',
          updatedAt: DateTime.now(),
        );
        await repository.updateTopic(updatedTopic);

        final retrieved = await repository.getTopic(id);
        expect(retrieved!.title, equals('新标题'));
      });

      test('trashTopic marks topic as trashed', () async {
        final id = await repository.createTopic('待删除笔记本');
        await repository.trashTopic(id);

        final topic = await repository.getTopic(id);
        expect(topic!.isTrashed, isTrue);
      });

      test('getAllTopics returns only non-trashed topics', () async {
        final id1 = await repository.createTopic('活跃笔记本');
        final id2 = await repository.createTopic('已删除笔记本');
        await repository.trashTopic(id2);

        final topics = await repository.getAllTopics();
        expect(topics.any((t) => t.id == id1), isTrue);
        expect(topics.any((t) => t.id == id2), isFalse);
      });
    });

    group('Note CRUD', () {
      late String topicId;

      setUp(() async {
        topicId = await repository.createTopic('测试导图');
      });

      test('createNote returns ID with prefix "1-"', () async {
        final id = await repository.createNote(topicId, '测试节点');
        expect(id.startsWith('1-'), isTrue);
      });

      test('createNote with parentId sets parent relationship', () async {
        final parentId = await repository.createNote(topicId, '父节点');
        final childId = await repository.createNote(
          topicId,
          '子节点',
          parentId: parentId,
        );

        final child = await repository.getNote(childId);
        expect(child!.parentId, equals(parentId));
      });

      test('getNote returns created note', () async {
        final id = await repository.createNote(topicId, '测试节点');
        final note = await repository.getNote(id);

        expect(note, isNotNull);
        expect(note!.id, equals(id));
        expect(note.title, equals('测试节点'));
        expect(note.topicId, equals(topicId));
      });

      test('updateNote modifies title', () async {
        final id = await repository.createNote(topicId, '原标题');
        final note = await repository.getNote(id);

        final updatedNote = note!.copyWith(
          title: '新标题',
          updatedAt: DateTime.now(),
        );
        await repository.updateNote(updatedNote);

        final retrieved = await repository.getNote(id);
        expect(retrieved!.title, equals('新标题'));
      });

      test('deleteNote removes note', () async {
        final id = await repository.createNote(topicId, '待删除节点');
        await repository.deleteNote(id);

        final note = await repository.getNote(id);
        expect(note, isNull);
      });
    });

    group('Child Relationships', () {
      late String topicId;
      late String parentId;

      setUp(() async {
        topicId = await repository.createTopic('测试导图');
        parentId = await repository.createNote(topicId, '父节点');
      });

      test('addChild appends child to parent', () async {
        final childId = await repository.createNote(topicId, '子节点');
        await repository.addChild(parentId, childId);

        final children = await repository.getChildren(parentId);
        expect(children.length, equals(1));
        expect(children.first.id, equals(childId));
      });

      test('addChild multiple children maintains order', () async {
        final child1 = await repository.createNote(topicId, '子节点1');
        final child2 = await repository.createNote(topicId, '子节点2');
        final child3 = await repository.createNote(topicId, '子节点3');

        await repository.addChild(parentId, child1);
        await repository.addChild(parentId, child2);
        await repository.addChild(parentId, child3);

        final children = await repository.getChildren(parentId);
        expect(children.length, equals(3));
        expect(children[0].id, equals(child1));
        expect(children[1].id, equals(child2));
        expect(children[2].id, equals(child3));
      });

      test('removeChild removes from parent', () async {
        final child1 = await repository.createNote(topicId, '子节点1');
        final child2 = await repository.createNote(topicId, '子节点2');

        await repository.addChild(parentId, child1);
        await repository.addChild(parentId, child2);
        await repository.removeChild(parentId, child1);

        final children = await repository.getChildren(parentId);
        expect(children.length, equals(1));
        expect(children.first.id, equals(child2));
      });
    });

    group('Query Operations', () {
      late String topicId;

      setUp(() async {
        topicId = await repository.createTopic('测试导图');
      });

      test('getNotesByTopic returns all notes in topic', () async {
        final note1 = await repository.createNote(topicId, '节点1');
        final note2 = await repository.createNote(topicId, '节点2');

        final notes = await repository.getNotesByTopic(topicId);
        expect(notes.length, equals(2));
        expect(notes.any((n) => n.id == note1), isTrue);
        expect(notes.any((n) => n.id == note2), isTrue);
      });

      test('getNotesByPdf returns notes with pdfId', () async {
        // pdfId 用于测试 PDF 摘录节点查询
        // 当前 Rust create_note API 不支持直接设置 pdfId
        // 需要通过 updateNote 设置或扩展 Rust API

        final noteWithPdf = await repository.createNote(topicId, 'PDF摘录节点');
        final note = await repository.getNote(noteWithPdf);

        // 获取 pdfId 用于后续查询（待 API 扩展）
        // final pdfId = 'test-pdf-md5';

        final updatedNote = note!.copyWith(
          updatedAt: DateTime.now(),
        );
        await repository.updateNote(updatedNote);

        // 实际测试需要在创建时提供 pdfId
        // 当前 Rust API 不支持 create_note 时设置 pdfId
        // 这个测试用例待 Rust API 扩展后再完善
      });
    });
  });
}