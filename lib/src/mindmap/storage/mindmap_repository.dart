// lib/src/mindmap/storage/mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';

/// MindMap 仓库抽象接口。
///
/// 支持两种实现：
/// - FfiMindMapRepository: 生产环境（通过 FFI 调用 Rust）
/// - InMemoryMindMapRepository: 测试环境（内存存储）
abstract class MindMapRepository {
  // ==================== Topic CRUD ====================

  /// 创建笔记本
  Future<String> createTopic(String title, {String? author});

  /// 查询笔记本
  Future<Topic?> getTopic(String id);

  /// 更新笔记本
  Future<void> updateTopic(Topic topic);

  /// 删除笔记本（软删除）
  Future<void> trashTopic(String id);

  /// 获取所有笔记本
  Future<List<Topic>> getAllTopics();

  // ==================== Note CRUD ====================

  /// 创建节点
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  });

  /// 查询节点
  Future<Note?> getNote(String id);

  /// 更新节点
  Future<void> updateNote(Note note);

  /// 删除节点
  Future<void> deleteNote(String id);

  /// 添加子节点
  Future<void> addChild(String parentId, String childId);

  /// 移除子节点
  Future<void> removeChild(String parentId, String childId);

  /// 获取子节点列表
  Future<List<Note>> getChildren(String parentId);

  /// 根据 PDF 查询节点
  Future<List<Note>> getNotesByPdf(String pdfId);

  /// 根据导图查询节点
  Future<List<Note>> getNotesByTopic(String topicId);
}
