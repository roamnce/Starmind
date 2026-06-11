// lib/src/mindmap/storage/in_memory_mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import 'mindmap_repository.dart';
import '../../rust/storage/tags.dart' show TagNode;

/// 内存中的简单标签模型
class _MemoryTag {
  final String id;
  final String name;
  final String? parentId;
  final String? colorHex;

  _MemoryTag({
    required this.id,
    required this.name,
    this.parentId,
    this.colorHex,
  });
}

/// 内存仓库（测试环境）。
///
/// 使用 Map 存储数据，用于单元测试。
class InMemoryMindMapRepository implements MindMapRepository {
  final Map<String, Topic> _topics = {};
  final Map<String, Note> _notes = {};
  final Map<String, MindMapRelation> _relations = {};
  final Map<String, MindMapSummary> _summaries = {};
  final Map<String, Set<String>> _noteTagIds = {};
  final Map<String, _MemoryTag> _tags = {};
  int _topicSequence = 0;
  int _noteSequence = 0;
  int _relationSequence = 0;
  int _summarySequence = 0;
  int _tagSequence = 0;

  @override
  Future<String> createTopic(String title, {String? author}) async {
    final id = '0-${++_topicSequence}';
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
      _topics[id] = topic.copyWith(
        isTrashed: true,
        updatedAt: DateTime.now(),
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
    final id = '1-${++_noteSequence}';
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
    // 级联删除关联线、概要和标签绑定
    await deleteRelationsForNote(id);
    await deleteSummariesForNote(id);
    await deleteNoteTagBindingsForNote(id);
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

  // ==================== Relation CRUD ====================

  @override
  Future<String> createRelation({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
    String text = defaultRelationText,
  }) async {
    // 同方向重复检查
    final existing = await findRelationByEndpoints(
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
    );
    if (existing != null) return existing.id;

    final id = 'rel-${++_relationSequence}';
    final now = DateTime.now();
    _relations[id] = MindMapRelation(
      id: id,
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    return id;
  }

  @override
  Future<MindMapRelation?> getRelation(String id) async {
    return _relations[id];
  }

  @override
  Future<void> updateRelation(MindMapRelation relation) async {
    _relations[relation.id] = relation;
  }

  @override
  Future<void> deleteRelation(String id) async {
    _relations.remove(id);
  }

  @override
  Future<List<MindMapRelation>> listRelations(String topicId) async {
    return _relations.values
        .where((r) => r.topicId == topicId)
        .toList();
  }

  @override
  Future<MindMapRelation?> findRelationByEndpoints({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
  }) async {
    for (final relation in _relations.values) {
      if (relation.topicId == topicId &&
          relation.sourceNoteId == sourceNoteId &&
          relation.targetNoteId == targetNoteId) {
        return relation;
      }
    }
    return null;
  }

  @override
  Future<void> deleteRelationsForNote(String noteId) async {
    final toRemove = _relations.values
        .where((r) => r.sourceNoteId == noteId || r.targetNoteId == noteId)
        .map((r) => r.id)
        .toList();
    for (final id in toRemove) {
      _relations.remove(id);
    }
  }

  // ==================== Summary CRUD ====================

  @override
  Future<String> createSummary({
    required String topicId,
    required String parentId,
    required int startIndex,
    required int endIndex,
    String text = defaultSummaryText,
  }) async {
    // 同区间重复检查
    for (final summary in _summaries.values) {
      if (summary.topicId == topicId &&
          summary.parentId == parentId &&
          summary.startIndex == startIndex &&
          summary.endIndex == endIndex) {
        return summary.id;
      }
    }

    final id = 'sum-${++_summarySequence}';
    final now = DateTime.now();
    _summaries[id] = MindMapSummary(
      id: id,
      topicId: topicId,
      parentId: parentId,
      startIndex: startIndex,
      endIndex: endIndex,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    return id;
  }

  @override
  Future<MindMapSummary?> getSummary(String id) async {
    return _summaries[id];
  }

  @override
  Future<void> updateSummary(MindMapSummary summary) async {
    _summaries[summary.id] = summary;
  }

  @override
  Future<void> deleteSummary(String id) async {
    _summaries.remove(id);
  }

  @override
  Future<List<MindMapSummary>> listSummaries(String topicId) async {
    return _summaries.values
        .where((s) => s.topicId == topicId)
        .toList()
      ..sort((a, b) {
        final parentCompare = a.parentId.compareTo(b.parentId);
        if (parentCompare != 0) return parentCompare;
        return a.startIndex.compareTo(b.startIndex);
      });
  }

  @override
  Future<void> deleteSummariesForNote(String noteId) async {
    final toRemove = _summaries.values
        .where((s) => s.parentId == noteId)
        .map((s) => s.id)
        .toList();
    for (final id in toRemove) {
      _summaries.remove(id);
    }
  }

  // ==================== Note-Tag Binding ====================

  @override
  Future<void> bindTagToNote({required String noteId, required String tagId}) async {
    _noteTagIds.putIfAbsent(noteId, () => {}).add(tagId);
  }

  @override
  Future<void> unbindTagFromNote({required String noteId, required String tagId}) async {
    _noteTagIds[noteId]?.remove(tagId);
  }

  @override
  Future<List<String>> listTagIdsForNote(String noteId) async {
    return _noteTagIds[noteId]?.toList() ?? [];
  }

  @override
  Future<Map<String, List<String>>> listTagIdsForTopic(String topicId) async {
    final result = <String, List<String>>{};
    for (final entry in _noteTagIds.entries) {
      final note = _notes[entry.key];
      if (note != null && note.topicId == topicId && entry.value.isNotEmpty) {
        result[entry.key] = entry.value.toList();
      }
    }
    return result;
  }

  @override
  Future<void> deleteNoteTagBindingsForNote(String noteId) async {
    _noteTagIds.remove(noteId);
  }

  // ==================== Tag Tree ====================

  @override
  Future<TagNode> getTagTree() async {
    // 内存实现：返回空树或已创建的标签作为根节点
    final rootTags = _tags.values
        .where((t) => t.parentId == null)
        .map((t) => _buildTagNode(t))
        .toList();
    return TagNode(
      id: 'root',
      name: 'Root',
      children: rootTags,
      documentCount: 0,
    );
  }

  TagNode _buildTagNode(_MemoryTag tag) {
    final children = _tags.values
        .where((t) => t.parentId == tag.id)
        .map((t) => _buildTagNode(t))
        .toList();
    return TagNode(
      id: tag.id,
      name: tag.name,
      children: children,
      colorHex: tag.colorHex,
      documentCount: 0,
    );
  }

  @override
  Future<String> createTag(String name, String? parentId, String? colorHex) async {
    final id = 'tag-${++_tagSequence}';
    _tags[id] = _MemoryTag(
      id: id,
      name: name,
      parentId: parentId,
      colorHex: colorHex,
    );
    return id;
  }

  /// 清空所有数据（测试辅助方法）
  void clear() {
    _topics.clear();
    _notes.clear();
    _relations.clear();
    _summaries.clear();
    _noteTagIds.clear();
    _tags.clear();
  }
}