// lib/src/mindmap/storage/ffi_mindmap_repository.dart

import 'dart:convert';

import '../domain/topic.dart';
import '../domain/note.dart';
import 'mindmap_repository.dart';
import '../../rust/frb_generated.dart';
import '../../rust/storage/mindmap.dart' as frb;

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
      createdAt: DateTime.fromMillisecondsSinceEpoch(frbTopic.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(frbTopic.updatedAt),
      lastVisitAt: frbTopic.lastVisitAt != null
          ? DateTime.fromMillisecondsSinceEpoch(frbTopic.lastVisitAt!)
          : null,
      isTrashed: frbTopic.isTrashed,
      syncVersion: frbTopic.syncVersion,
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
      createdAt: topic.createdAt.millisecondsSinceEpoch,
      updatedAt: topic.updatedAt.millisecondsSinceEpoch,
      lastVisitAt: topic.lastVisitAt?.millisecondsSinceEpoch,
      isTrashed: topic.isTrashed,
      syncVersion: topic.syncVersion,
    );
  }

  /// 将 FFI Note 转换为 Domain Note
  Note _convertNote(frb.Note frbNote) {
    return Note(
      id: frbNote.id,
      topicId: frbNote.topicId,
      parentId: frbNote.parentId,
      title: frbNote.title,
      // contentJson 在 Note 模型中通过 NoteContent 解析
      // 这里暂不处理，因为 FFI 生成的是 String 类型
      // 实际使用时需要在 Note.fromMap 中处理
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(frbNote.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(frbNote.updatedAt),
      syncVersion: frbNote.syncVersion,
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
      createdAt: note.createdAt.millisecondsSinceEpoch,
      updatedAt: note.updatedAt.millisecondsSinceEpoch,
      syncVersion: note.syncVersion,
    );
  }

  /// 解析管道分隔字符串
  List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }
}