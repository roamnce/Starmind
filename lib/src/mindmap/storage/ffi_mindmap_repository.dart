// lib/src/mindmap/storage/ffi_mindmap_repository.dart

import 'dart:convert';

import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import 'mindmap_repository.dart';
import '../../rust/frb_generated.dart';
import '../../rust/storage/mindmap.dart' as frb;
import '../../rust/storage/tags.dart' show TagNode;
import '../../utils/type_conversion.dart';

/// FFI 仓库适配器（生产环境）。
///
/// 通过 flutter_rust_bridge 调用 Rust 存储层。
class FfiMindMapRepository implements MindMapRepository {
  final RustLibApi _api;

  // ignore: invalid_use_of_internal_member
  FfiMindMapRepository({RustLibApi? api}) : _api = api ?? RustLib.instance.api;

  // ==================== Topic 操作 ====================

  @override
  Future<String> createTopic(String title, {String? author}) async {
    return await _api.crateApiStorageMindmapCreateTopic(
      title: title,
      author: author,
    );
  }

  @override
  Future<Topic?> getTopic(String id) async {
    final result = await _api.crateApiStorageMindmapGetTopic(id: id);
    return result != null ? _convertTopic(result) : null;
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    await _api.crateApiStorageMindmapUpdateTopic(
      topic: _convertToFrbTopic(topic),
    );
  }

  @override
  Future<void> trashTopic(String id) async {
    await _api.crateApiStorageMindmapTrashTopic(id: id);
  }

  @override
  Future<List<Topic>> getAllTopics() async {
    final results = await _api.crateApiStorageMindmapGetAllTopics();
    return results.map(_convertTopic).toList();
  }

  // ==================== Note 操作 ====================

  @override
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  }) async {
    return await _api.crateApiStorageMindmapCreateNote(
      topicId: topicId,
      title: title,
      parentId: parentId,
    );
  }

  @override
  Future<Note?> getNote(String id) async {
    final result = await _api.crateApiStorageMindmapGetNote(id: id);
    return result != null ? _convertNote(result) : null;
  }

  @override
  Future<void> updateNote(Note note) async {
    await _api.crateApiStorageMindmapUpdateNote(
      note: _convertToFrbNote(note),
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    await _api.crateApiStorageMindmapDeleteNote(id: id);
  }

  @override
  Future<void> addChild(String parentId, String childId) async {
    await _api.crateApiStorageMindmapAddChild(
      parentId: parentId,
      childId: childId,
    );
  }

  @override
  Future<void> removeChild(String parentId, String childId) async {
    await _api.crateApiStorageMindmapRemoveChild(
      parentId: parentId,
      childId: childId,
    );
  }

  @override
  Future<List<Note>> getChildren(String parentId) async {
    final results = await _api.crateApiStorageMindmapGetChildren(
      parentId: parentId,
    );
    return results.map(_convertNote).toList();
  }

  @override
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    final results = await _api.crateApiStorageMindmapGetNotesByPdf(
      pdfId: pdfId,
    );
    return results.map(_convertNote).toList();
  }

  @override
  Future<List<Note>> getNotesByTopic(String topicId) async {
    final results = await _api.crateApiStorageMindmapGetNotesByTopic(
      topicId: topicId,
    );
    return results.map(_convertNote).toList();
  }

  // ==================== 类型转换 ====================

  /// 将 FFI Topic 转换为 Domain Topic
  Topic _convertTopic(frb.Topic frbTopic) {
    return Topic(
      id: frbTopic.id,
      title: frbTopic.title,
      author: frbTopic.author,
      pdfIds: _parsePipedList(frbTopic.pdfIds),
      rootNoteIds: _parsePipedList(frbTopic.rootNoteIds),
      thumbnailPath: frbTopic.thumbnailPath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        i64ToInt(frbTopic.createdAt),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        i64ToInt(frbTopic.updatedAt),
      ),
      lastVisitAt: frbTopic.lastVisitAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              i64ToInt(frbTopic.lastVisitAt!),
            )
          : null,
      isTrashed: frbTopic.isTrashed,
      syncVersion: i64ToInt(frbTopic.syncVersion),
      layoutDirection: frbTopic.layoutDirection,
      layoutStyle: frbTopic.layoutStyle,
    );
  }

  /// 将 Domain Topic 转换为 FFI Topic
  frb.Topic _convertToFrbTopic(Topic topic) {
    return frb.Topic(
      id: topic.id,
      title: topic.title,
      author: topic.author,
      pdfIds: topic.pdfIds.isEmpty ? null : topic.pdfIds.join('|'),
      rootNoteIds: topic.rootNoteIds.isEmpty ? null : topic.rootNoteIds.join('|'),
      thumbnailPath: topic.thumbnailPath,
      createdAt: intToI64(topic.createdAt.millisecondsSinceEpoch),
      updatedAt: intToI64(topic.updatedAt.millisecondsSinceEpoch),
      lastVisitAt: topic.lastVisitAt != null
          ? intToI64(topic.lastVisitAt!.millisecondsSinceEpoch)
          : null,
      isTrashed: topic.isTrashed,
      syncVersion: intToI64(topic.syncVersion),
      layoutDirection: topic.layoutDirection,
      layoutStyle: topic.layoutStyle,
    );
  }

  /// 将 FFI Note 转换为 Domain Note
  Note _convertNote(frb.Note frbNote) {
    return Note(
      id: frbNote.id,
      topicId: frbNote.topicId,
      parentId: frbNote.parentId,
      title: frbNote.title,
      childIds: _parsePipedList(frbNote.childIds),
      pdfId: frbNote.pdfId,
      startPage: frbNote.startPage,
      endPage: frbNote.endPage,
      startPosJson: frbNote.startPos,
      endPosJson: frbNote.endPos,
      highlightText: frbNote.highlightText,
      highlightStyle: frbNote.highlightStyle,
      mediaIds: _parsePipedList(frbNote.mediaIds),
      positionX: frbNote.positionX,
      positionY: frbNote.positionY,
      zIndex: frbNote.zIndex,
      isCollapsed: frbNote.isCollapsed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        i64ToInt(frbNote.createdAt),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        i64ToInt(frbNote.updatedAt),
      ),
      syncVersion: i64ToInt(frbNote.syncVersion),
    );
  }

  /// 将 Domain Note 转换为 FFI Note
  frb.Note _convertToFrbNote(Note note) {
    return frb.Note(
      id: note.id,
      topicId: note.topicId,
      parentId: note.parentId,
      title: note.title,
      contentJson: note.content != null
          ? jsonEncode(note.content!.toJson())
          : null,
      childIds: note.childIds.isEmpty ? null : note.childIds.join('|'),
      pdfId: note.pdfId,
      startPage: note.startPage,
      endPage: note.endPage,
      startPos: note.startPosJson,
      endPos: note.endPosJson,
      highlightText: note.highlightText,
      highlightStyle: note.highlightStyle,
      mediaIds: note.mediaIds.isEmpty ? null : note.mediaIds.join('|'),
      positionX: note.positionX,
      positionY: note.positionY,
      zIndex: note.zIndex,
      isCollapsed: note.isCollapsed,
      createdAt: intToI64(note.createdAt.millisecondsSinceEpoch),
      updatedAt: intToI64(note.updatedAt.millisecondsSinceEpoch),
      syncVersion: intToI64(note.syncVersion),
    );
  }

  /// 解析管道分隔字符串
  List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  // ==================== Relation CRUD ====================

  @override
  Future<String> createRelation({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
    String text = defaultRelationText,
  }) async {
    return await _api.crateApiStorageMindmapCreateRelation(
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      text: text,
    );
  }

  @override
  Future<MindMapRelation?> getRelation(String id) async {
    final result = await _api.crateApiStorageMindmapGetRelation(id: id);
    return result != null ? _convertRelation(result) : null;
  }

  @override
  Future<void> updateRelation(MindMapRelation relation) async {
    await _api.crateApiStorageMindmapUpdateRelation(
      relation: _convertToFrbRelation(relation),
    );
  }

  @override
  Future<void> deleteRelation(String id) async {
    await _api.crateApiStorageMindmapDeleteRelation(id: id);
  }

  @override
  Future<List<MindMapRelation>> listRelations(String topicId) async {
    final results = await _api.crateApiStorageMindmapListRelations(topicId: topicId);
    return results.map(_convertRelation).toList();
  }

  @override
  Future<MindMapRelation?> findRelationByEndpoints({
    required String topicId,
    required String sourceNoteId,
    required String targetNoteId,
  }) async {
    final result = await _api.crateApiStorageMindmapFindRelationByEndpoints(
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
    );
    return result != null ? _convertRelation(result) : null;
  }

  @override
  Future<void> deleteRelationsForNote(String noteId) async {
    await _api.crateApiStorageMindmapDeleteRelationsForNote(noteId: noteId);
  }

  /// 将 FFI Relation 转换为 Domain Relation
  MindMapRelation _convertRelation(frb.MindMapRelation relation) {
    return MindMapRelation(
      id: relation.id,
      topicId: relation.topicId,
      sourceNoteId: relation.sourceNoteId,
      targetNoteId: relation.targetNoteId,
      text: relation.text,
      controlPoints: relation.controlPointsJson == null || relation.controlPointsJson!.isEmpty
          ? const []
          : (jsonDecode(relation.controlPointsJson!) as List)
              .map((item) => RelationControlPoint.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList(),
      style: relation.style,
      createdAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(relation.createdAt)),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(relation.updatedAt)),
    );
  }

  /// 将 Domain Relation 转换为 FFI Relation
  frb.MindMapRelation _convertToFrbRelation(MindMapRelation relation) {
    return frb.MindMapRelation(
      id: relation.id,
      topicId: relation.topicId,
      sourceNoteId: relation.sourceNoteId,
      targetNoteId: relation.targetNoteId,
      text: relation.text,
      controlPointsJson: relation.controlPoints.isEmpty
          ? null
          : jsonEncode(relation.controlPoints.map((p) => p.toJson()).toList()),
      style: relation.style,
      createdAt: intToI64(relation.createdAt.millisecondsSinceEpoch),
      updatedAt: intToI64(relation.updatedAt.millisecondsSinceEpoch),
    );
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
    return await _api.crateApiStorageMindmapCreateSummary(
      topicId: topicId,
      parentId: parentId,
      startIndex: startIndex,
      endIndex: endIndex,
      text: text,
    );
  }

  @override
  Future<MindMapSummary?> getSummary(String id) async {
    final result = await _api.crateApiStorageMindmapGetSummary(id: id);
    return result != null ? _convertSummary(result) : null;
  }

  @override
  Future<void> updateSummary(MindMapSummary summary) async {
    await _api.crateApiStorageMindmapUpdateSummary(
      summary: _convertToFrbSummary(summary),
    );
  }

  @override
  Future<void> deleteSummary(String id) async {
    await _api.crateApiStorageMindmapDeleteSummary(id: id);
  }

  @override
  Future<List<MindMapSummary>> listSummaries(String topicId) async {
    final results = await _api.crateApiStorageMindmapListSummaries(topicId: topicId);
    return results.map(_convertSummary).toList();
  }

  @override
  Future<void> deleteSummariesForNote(String noteId) async {
    await _api.crateApiStorageMindmapDeleteSummariesForNote(noteId: noteId);
  }

  /// 将 FFI Summary 转换为 Domain Summary
  MindMapSummary _convertSummary(frb.MindMapSummary summary) {
    return MindMapSummary(
      id: summary.id,
      topicId: summary.topicId,
      parentId: summary.parentId,
      startIndex: summary.startIndex,
      endIndex: summary.endIndex,
      text: summary.text,
      createdAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(summary.createdAt)),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(summary.updatedAt)),
    );
  }

  /// 将 Domain Summary 转换为 FFI Summary
  frb.MindMapSummary _convertToFrbSummary(MindMapSummary summary) {
    return frb.MindMapSummary(
      id: summary.id,
      topicId: summary.topicId,
      parentId: summary.parentId,
      startIndex: summary.startIndex,
      endIndex: summary.endIndex,
      text: summary.text,
      createdAt: intToI64(summary.createdAt.millisecondsSinceEpoch),
      updatedAt: intToI64(summary.updatedAt.millisecondsSinceEpoch),
    );
  }

  // ==================== Note-Tag Binding ====================

  @override
  Future<void> bindTagToNote({required String noteId, required String tagId}) async {
    await _api.crateApiStorageMindmapBindTagToNote(
      noteId: noteId,
      tagId: tagId,
    );
  }

  @override
  Future<void> unbindTagFromNote({required String noteId, required String tagId}) async {
    await _api.crateApiStorageMindmapUnbindTagFromNote(
      noteId: noteId,
      tagId: tagId,
    );
  }

  @override
  Future<List<String>> listTagIdsForNote(String noteId) async {
    return await _api.crateApiStorageMindmapListTagIdsForNote(noteId: noteId);
  }

  @override
  Future<Map<String, List<String>>> listTagIdsForTopic(String topicId) async {
    return await _api.crateApiStorageMindmapListTagIdsForTopic(topicId: topicId);
  }

  @override
  Future<void> deleteNoteTagBindingsForNote(String noteId) async {
    await _api.crateApiStorageMindmapDeleteNoteTagBindingsForNote(noteId: noteId);
  }

  // ==================== Tag Tree ====================

  @override
  Future<TagNode> getTagTree() async {
    return await RustLib.instance.api.crateApiStorageGetTagTree();
  }

  @override
  Future<String> createTag(String name, String? parentId, String? colorHex) async {
    return await RustLib.instance.api.crateApiStorageCreateTag(
      name: name,
      parentId: parentId,
      colorHex: colorHex,
    );
  }
}
