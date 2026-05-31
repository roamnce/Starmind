// lib/src/mindmap/storage/in_memory_mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import 'mindmap_repository.dart';

/// 内存仓库（测试环境）。
///
/// 使用 Map 存储数据，用于单元测试。
class InMemoryMindMapRepository implements MindMapRepository {
  final Map<String, Topic> _topics = {};
  final Map<String, Note> _notes = {};

  @override
  Future<String> createTopic(String title, {String? author}) async {
    final id = '0-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _topics[id] = Topic(
      id: id,
      title: title,
      author: author,
      createdAt: now,
      updatedAt: now,
    );

    return id;
  }

  @override
  Future<Topic?> getTopic(String id) async {
    return _topics[id];
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    _topics[topic.id] = topic;
  }

  @override
  Future<void> trashTopic(String id) async {
    final topic = _topics[id];
    if (topic != null) {
      _topics[id] = Topic(
        id: topic.id,
        title: topic.title,
        author: topic.author,
        pdfIds: topic.pdfIds,
        rootNoteIds: topic.rootNoteIds,
        thumbnailPath: topic.thumbnailPath,
        createdAt: topic.createdAt,
        updatedAt: DateTime.now(),
        lastVisitAt: topic.lastVisitAt,
        isTrashed: true,
        syncVersion: topic.syncVersion,
      );
    }
  }

  @override
  Future<List<Topic>> getAllTopics() async {
    return _topics.values.where((t) => !t.isTrashed).toList();
  }

  @override
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  }) async {
    final id = '1-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _notes[id] = Note(
      id: id,
      topicId: topicId,
      parentId: parentId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );

    return id;
  }

  @override
  Future<Note?> getNote(String id) async {
    return _notes[id];
  }

  @override
  Future<void> updateNote(Note note) async {
    _notes[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
  }

  @override
  Future<void> addChild(String parentId, String childId) async {
    final parent = _notes[parentId];
    final child = _notes[childId];

    if (parent != null && child != null) {
      // 更新父节点的 childIds
      final newChildIds = [...parent.childIds, childId];
      _notes[parentId] = parent.copyWith(
        childIds: newChildIds,
        updatedAt: DateTime.now(),
      );

      // 更新子节点的 parentId
      _notes[childId] = child.copyWith(
        parentId: parentId,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> removeChild(String parentId, String childId) async {
    final parent = _notes[parentId];
    final child = _notes[childId];

    if (parent != null && child != null) {
      // 从父节点的 childIds 中移除
      final newChildIds = parent.childIds.where((id) => id != childId).toList();
      _notes[parentId] = parent.copyWith(
        childIds: newChildIds,
        updatedAt: DateTime.now(),
      );

      // 清除子节点的 parentId
      _notes[childId] = child.copyWith(
        parentId: null,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<List<Note>> getChildren(String parentId) async {
    final parent = _notes[parentId];
    if (parent == null) return [];

    return parent.childIds
        .map((id) => _notes[id])
        .whereType<Note>()
        .toList();
  }

  @override
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    return _notes.values
        .where((note) => note.pdfId == pdfId)
        .toList();
  }

  @override
  Future<List<Note>> getNotesByTopic(String topicId) async {
    return _notes.values
        .where((note) => note.topicId == topicId)
        .toList();
  }

  /// 清空所有数据（测试辅助方法）
  void clear() {
    _topics.clear();
    _notes.clear();
  }
}
