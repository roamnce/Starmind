// lib/src/mindmap/service/mindmap_service.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import '../export/gurumind_exporter.dart';
import '../import/gurumind_importer.dart';
import '../storage/mindmap_repository.dart';

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
    await GuruMindDataExporter().exportTopic(
      topic: topic,
      notes: notes,
      outputPath: outputPath,
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

  /// 获取笔记本的节点树（用于 UI 渲染）
  Future<List<NoteTreeNode>> getTopicTree(String topicId) async {
    final topic = await _repository.getTopic(topicId);
    if (topic == null) return [];

    final List<NoteTreeNode> roots = [];
    for (final rootId in topic.rootNoteIds) {
      final node = await _buildTreeNode(rootId);
      if (node != null) roots.add(node);
    }
    return roots;
  }

  /// 递归构建节点树
  Future<NoteTreeNode?> _buildTreeNode(String noteId) async {
    final note = await _repository.getNote(noteId);
    if (note == null) return null;

    final children = await _repository.getChildren(noteId);
    final childNodes = <NoteTreeNode>[];

    for (final child in children) {
      final childNode = await _buildTreeNode(child.id);
      if (childNode != null) childNodes.add(childNode);
    }

    return NoteTreeNode(note: note, children: childNodes);
  }
}
