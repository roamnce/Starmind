// lib/src/mindmap/storage/mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import '../../rust/storage/tags.dart' show TagNode;

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

  // ==================== Relation CRUD ====================

  /// 创建关联线（同方向重复时返回已有 ID）
  Future<String> createRelation({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
    String text = defaultRelationText,
  });

  /// 查询关联线
  Future<MindMapRelation?> getRelation(String id);

  /// 更新关联线
  Future<void> updateRelation(MindMapRelation relation);

  /// 删除关联线
  Future<void> deleteRelation(String id);

  /// 查询 Topic 下所有关联线
  Future<List<MindMapRelation>> listRelations(String topicId);

  /// 按端点查找关联线
  Future<MindMapRelation?> findRelationByEndpoints({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
  });

  /// 删除节点相关的所有关联线
  Future<void> deleteRelationsForNote(String noteId);

  // ==================== Summary CRUD ====================

  /// 创建概要（同区间重复时返回已有 ID）
  Future<String> createSummary({
    required String topicId,
    required String parentId,
    required int startIndex,
    required int endIndex,
    String text = defaultSummaryText,
  });

  /// 查询概要
  Future<MindMapSummary?> getSummary(String id);

  /// 更新概要
  Future<void> updateSummary(MindMapSummary summary);

  /// 删除概要
  Future<void> deleteSummary(String id);

  /// 查询 Topic 下所有概要
  Future<List<MindMapSummary>> listSummaries(String topicId);

  /// 删除节点相关的所有概要
  Future<void> deleteSummariesForNote(String noteId);

  // ==================== Note-Tag Binding ====================

  /// 绑定标签到节点
  Future<void> bindTagToNote({required String noteId, required String tagId});

  /// 解绑节点标签
  Future<void> unbindTagFromNote({required String noteId, required String tagId});

  /// 查询节点绑定的标签 ID 列表
  Future<List<String>> listTagIdsForNote(String noteId);

  /// 批量查询 Topic 下所有节点的标签绑定。
  ///
  /// 返回 `Map<noteId, List<tagId>>`，仅包含有绑定的节点。
  Future<Map<String, List<String>>> listTagIdsForTopic(String topicId);

  /// 删除节点的所有标签绑定
  Future<void> deleteNoteTagBindingsForNote(String noteId);

  // ==================== Tag Tree ====================

  /// 获取全局标签树
  Future<TagNode> getTagTree();

  /// 创建标签，返回新标签 ID
  Future<String> createTag(String name, String? parentId, String? colorHex);
}
