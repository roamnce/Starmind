// lib/src/mindmap/storage/ffi_mindmap_repository.dart

import '../domain/topic.dart';
import '../domain/note.dart';
import 'mindmap_repository.dart';

/// FFI 仓库适配器（生产环境）。
///
/// 通过 flutter_rust_bridge 调用 Rust 存储层。
///
/// 注意：此实现假设 FFI 函数已通过 flutter_rust_bridge 生成。
/// 在 FFI 代码生成完成前，部分方法可能抛出 UnimplementedError。
class FfiMindMapRepository implements MindMapRepository {
  // FFI API 实例（通过 flutter_rust_bridge 生成）
  // final Starmind _api;

  /// 暂时使用默认构造函数，待 FFI 集成后添加 api 参数
  FfiMindMapRepository();

  @override
  Future<String> createTopic(String title, {String? author}) async {
    // TODO: 调用 FFI: _api.mindmapCreateTopic(title: title, author: author)
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<Topic?> getTopic(String id) async {
    // TODO: 调用 FFI 并转换结果
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> trashTopic(String id) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<List<Topic>> getAllTopics() async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<String> createNote(
    String topicId,
    String title, {
    String? parentId,
  }) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<Note?> getNote(String id) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> updateNote(Note note) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> deleteNote(String id) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> addChild(String parentId, String childId) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<void> removeChild(String parentId, String childId) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<List<Note>> getChildren(String parentId) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<List<Note>> getNotesByPdf(String pdfId) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }

  @override
  Future<List<Note>> getNotesByTopic(String topicId) async {
    // TODO: 调用 FFI
    throw UnimplementedError('FFI integration pending');
  }
}
