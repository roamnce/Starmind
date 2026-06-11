// lib/src/mindmap/domain/mindmap_note_tag.dart

import '../../domain/tag.dart';

/// 节点标签绑定视图模型
///
/// 用于 UI 和服务层返回值，不直接持久化。
class MindMapNoteTag {
  final String noteId;
  final Tag tag;

  const MindMapNoteTag({
    required this.noteId,
    required this.tag,
  });
}
