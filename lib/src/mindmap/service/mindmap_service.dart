// lib/src/mindmap/service/mindmap_service.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import '../export/gurumind_exporter.dart';
import '../import/gurumind_importer.dart';
import '../storage/mindmap_repository.dart';
import '../../rust/storage/tags.dart' show TagNode;

/// 节点树结构（用于 UI 渲染）
class NoteTreeNode {
  final Note note;
  final List<NoteTreeNode> children;

  const NoteTreeNode({
    required this.note,
    this.children = const [],
  });

  /// 递归计算所有节点数量
  int get totalNodes =>
      1 + children.fold(0, (sum, child) => sum + child.totalNodes);

  /// 计算树的最大深度
  int get maxDepth => children.isEmpty
      ? 1
      : 1 + children.map((c) => c.maxDepth).reduce((a, b) => a > b ? a : b);
}

/// MindMap 业务服务层。
///
/// 封装 Repository 操作，提供高级业务功能：
/// - 创建笔记本和节点
/// - 构建节点树结构
/// - PDF 摘录节点创建
/// - 批量操作
class MindMapService {
  final MindMapRepository _repository;

  MindMapService(this._repository);

  Future<ImportResult> importGuruMindFile(String filePath) {
    return GuruMindImporter(repository: _repository).importFile(filePath);
  }

  Future<void> exportGuruMindTopic({
    required String topicId,
    required String outputPath,
  }) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) {
      throw StateError('Topic not found: $topicId');
    }
    final notes = await _repository.getNotesByTopic(topicId);
    final relations = await _repository.listRelations(topicId);
    final summaries = await _repository.listSummaries(topicId);

    final tagTree = await _repository.getTagTree();
    final tagNameById = _flattenTagNames(tagTree);

    // 批量查询所有节点的标签绑定，避免逐节点 N+1 查询
    final tagsByNoteId = await _repository.listTagIdsForTopic(topicId);
    final resolvedTagsByNoteId = <String, List<String>>{};
    for (final entry in tagsByNoteId.entries) {
      if (entry.value.isNotEmpty) {
        resolvedTagsByNoteId[entry.key] = entry.value
            .map((id) => tagNameById[id] ?? id)
            .toList();
      }
    }

    await GuruMindDataExporter().exportTopic(
      topic: topic,
      notes: notes,
      outputPath: outputPath,
      relations: relations,
      summaries: summaries,
      tagsByNoteId: resolvedTagsByNoteId,
    );
  }

  // ==================== Topic 操作 ====================

  /// 创建新笔记本
  Future<Topic> createTopic(String title, {String? author}) async {
    final id = await _repository.createTopic(title, author: author);
    final topic = await _repository.getTopic(id);
    return topic!;
  }

  /// 获取笔记本
  Future<Topic?> getTopic(String id) async {
    return await _repository.getTopic(id);
  }

  /// 获取所有笔记本（排除已删除）
  Future<List<Topic>> getAllTopics() async {
    return await _repository.getAllTopics();
  }

  /// 更新笔记本
  Future<void> updateTopic(Topic topic) async {
    await _repository.updateTopic(topic);
  }

  /// 软删除笔记本
  Future<void> trashTopic(String id) async {
    await _repository.trashTopic(id);
  }

  /// 添加根节点到笔记本
  Future<void> addRootNote({
    required String topicId,
    required String noteId,
  }) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return;

    final updatedTopic = topic.copyWith(
      rootNoteIds: [...topic.rootNoteIds, noteId],
      updatedAt: DateTime.now(),
    );
    await _repository.updateTopic(updatedTopic);
  }

  /// 移除根节点
  Future<void> removeRootNote({
    required String topicId,
    required String noteId,
  }) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return;

    final updatedTopic = topic.copyWith(
      rootNoteIds: topic.rootNoteIds.where((id) => id != noteId).toList(),
      updatedAt: DateTime.now(),
    );
    await _repository.updateTopic(updatedTopic);
  }

  // ==================== Note 操作 ====================

  /// 创建节点
  Future<Note> createNote({
    required String topicId,
    required String title,
    String? parentId,
  }) async {
    final id = await _repository.createNote(topicId, title, parentId: parentId);
    final note = await _repository.getNote(id);
    return note!;
  }

  /// 获取节点
  Future<Note?> getNote(String id) async {
    return await _repository.getNote(id);
  }

  /// 更新节点
  Future<void> updateNote(Note note) async {
    await _repository.updateNote(note);
  }

  /// 删除节点
  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
  }

  /// 添加子节点
  Future<void> addChild({
    required String parentId,
    required String childId,
  }) async {
    await _repository.addChild(parentId, childId);
  }

  /// 移除子节点
  Future<void> removeChild({
    required String parentId,
    required String childId,
  }) async {
    await _repository.removeChild(parentId, childId);
  }

  /// 获取子节点列表
  Future<List<Note>> getChildren(String parentId) async {
    return await _repository.getChildren(parentId);
  }

  /// 获取笔记本内所有节点
  Future<List<Note>> getNotesByTopic(String topicId) async {
    return await _repository.getNotesByTopic(topicId);
  }

  /// 获取 PDF 关联的所有节点
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    return await _repository.getNotesByPdf(pdfId);
  }

  // ==================== 树结构操作 ====================

  /// 获取笔记本的节点树（用于 UI 渲染）。
  ///
  /// 单次批量查询所有节点，内存中组装树结构，
  /// 避免递归逐节点查询的 N+1 问题。
  Future<List<NoteTreeNode>> getTopicTree(String topicId) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return [];

    final allNotes = await _repository.getNotesByTopic(topicId);
    final byId = <String, Note>{for (final n in allNotes) n.id: n};

    NoteTreeNode buildNode(String noteId) {
      final note = byId[noteId]!;
      final childIds = note.childIds;
      final children = childIds
          .where((id) => byId.containsKey(id))
          .map(buildNode)
          .toList();
      return NoteTreeNode(note: note, children: children);
    }

    return topic.rootNoteIds
        .where((id) => byId.containsKey(id))
        .map(buildNode)
        .toList();
  }

  // ==================== Relation 操作 ====================

  /// 创建关联线（自关联抛出 StateError，同方向重复返回已有）
  Future<MindMapRelation> createRelation({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
    String text = defaultRelationText,
  }) async {
    if (sourceNoteId == targetNoteId) {
      throw StateError('Relation source and target must be different notes');
    }
    final id = await _repository.createRelation(
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      text: text,
    );
    final relation = await _repository.getRelation(id);
    return relation!;
  }

  /// 获取关联线
  Future<MindMapRelation?> getRelation(String id) async {
    return await _repository.getRelation(id);
  }

  /// 更新关联线文本
  Future<void> updateRelationText(String relationId, String text) async {
    final relation = await _repository.getRelation(relationId);
    if (relation == null) return;
    final normalized = text.trim().isEmpty ? defaultRelationText : text.trim();
    await _repository.updateRelation(relation.copyWith(
      text: normalized,
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除关联线
  Future<void> deleteRelation(String id) async {
    await _repository.deleteRelation(id);
  }

  /// 查询 Topic 下所有关联线
  Future<List<MindMapRelation>> listRelations(String topicId) async {
    return await _repository.listRelations(topicId);
  }

  /// 删除节点相关的所有关联线
  Future<void> deleteRelationsForNote(String noteId) async {
    await _repository.deleteRelationsForNote(noteId);
  }

  // ==================== Summary 操作 ====================

  /// 从选中节点创建概要
  ///
  /// 将选中的节点按父节点分组，为每组创建连续区间概要。
  Future<List<MindMapSummary>> createSummariesFromSelectedNoteIds({
    required String topicId,
    required Set<String> selectedNoteIds,
  }) async {
    final notes = await _repository.getNotesByTopic(topicId);
    final byId = {for (final note in notes) note.id: note};
    final parentToChildIndexes = <String, List<int>>{};

    for (final noteId in selectedNoteIds) {
      final note = byId[noteId];
      if (note == null) continue;
      final parentId = note.parentId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      if (parent == null) continue;
      final childIndex = parent.childIds.indexOf(note.id);
      if (childIndex < 0) continue;
      parentToChildIndexes.putIfAbsent(parentId, () => []).add(childIndex);
    }

    final result = <MindMapSummary>[];
    for (final entry in parentToChildIndexes.entries) {
      final indexes = entry.value..sort();
      final id = await _repository.createSummary(
        topicId: topicId,
        parentId: entry.key,
        startIndex: indexes.first,
        endIndex: indexes.last,
      );
      final summary = await _repository.getSummary(id);
      if (summary != null) result.add(summary);
    }
    return result;
  }

  /// 获取概要
  Future<MindMapSummary?> getSummary(String id) async {
    return await _repository.getSummary(id);
  }

  /// 更新概要文本
  Future<void> updateSummaryText(String summaryId, String text) async {
    final summary = await _repository.getSummary(summaryId);
    if (summary == null) return;
    final normalized = text.trim().isEmpty ? defaultSummaryText : text.trim();
    await _repository.updateSummary(summary.copyWith(
      text: normalized,
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除概要
  Future<void> deleteSummary(String id) async {
    await _repository.deleteSummary(id);
  }

  /// 查询 Topic 下所有概要
  Future<List<MindMapSummary>> listSummaries(String topicId) async {
    return await _repository.listSummaries(topicId);
  }

  /// 删除节点相关的所有概要
  Future<void> deleteSummariesForNote(String noteId) async {
    await _repository.deleteSummariesForNote(noteId);
  }

  // ==================== Node-Tag Binding 操作 ====================

  /// 绑定标签到节点（直接使用 tagId）
  Future<void> bindTagToNote({
    required String noteId,
    required String tagId,
  }) async {
    await _repository.bindTagToNote(noteId: noteId, tagId: tagId);
  }

  /// 解绑节点标签
  Future<void> unbindTagFromNote({
    required String noteId,
    required String tagId,
  }) async {
    await _repository.unbindTagFromNote(noteId: noteId, tagId: tagId);
  }

  /// 查询节点绑定的标签 ID 列表
  Future<List<String>> listTagIdsForNote(String noteId) async {
    return await _repository.listTagIdsForNote(noteId);
  }

  /// 批量查询 Topic 下所有节点的标签绑定
  Future<Map<String, List<String>>> listTagIdsForTopic(String topicId) async {
    return await _repository.listTagIdsForTopic(topicId);
  }

  /// 删除节点的所有标签绑定
  Future<void> deleteNoteTagBindingsForNote(String noteId) async {
    await _repository.deleteNoteTagBindingsForNote(noteId);
  }

  // ==================== Tag Tree ====================

  /// 获取全局标签树
  Future<TagNode> getTagTree() async {
    return await _repository.getTagTree();
  }

  /// 创建标签
  Future<String> createTag(String name, String? parentId, String? colorHex) async {
    return await _repository.createTag(name, parentId, colorHex);
  }

  Map<String, String> _flattenTagNames(TagNode root) {
    final result = <String, String>{};
    void visit(TagNode node) {
      if (node.id.isNotEmpty) {
        result[node.id] = node.name;
      }
      for (final child in node.children) {
        visit(child);
      }
    }
    visit(root);
    return result;
  }
}
