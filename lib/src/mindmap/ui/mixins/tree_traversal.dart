// lib/src/mindmap/ui/mixins/tree_traversal.dart
//
// 树遍历辅助 Mixin。
//
// 提供 NoteTreeNode 树结构的查找功能，可在 Controller 和 Page 中复用。

import '../../service/mindmap_service.dart' show NoteTreeNode;
import '../../domain/note.dart';

/// 树遍历辅助 Mixin。
///
/// 提供在 NoteTreeNode 树中查找节点的方法。
/// 使用方式：
/// ```dart
/// class MyController extends ChangeNotifier with TreeTraversal {
///   // 可直接调用 findNoteInTree 和 findNoteTreeNode
/// }
/// ```
mixin TreeTraversal {
  /// 在树中查找 Note 对象。
  ///
  /// 遍历 NoteTreeNode 列表，找到匹配 ID 的节点并返回其 Note。
  Note? findNoteInTree(List<NoteTreeNode> roots, String id) {
    for (final root in roots) {
      final found = _findNoteInNode(root, id);
      if (found != null) return found;
    }
    return null;
  }

  /// 在单个节点及其子节点中查找 Note。
  Note? _findNoteInNode(NoteTreeNode node, String id) {
    if (node.note.id == id) return node.note;
    for (final child in node.children) {
      final found = _findNoteInNode(child, id);
      if (found != null) return found;
    }
    return null;
  }

  /// 在树中查找 NoteTreeNode 对象。
  ///
  /// 遍历 NoteTreeNode 列表，找到匹配 ID 的节点并返回整个节点对象。
  NoteTreeNode? findNoteTreeNode(List<NoteTreeNode> nodes, String id) {
    for (final node in nodes) {
      if (node.note.id == id) return node;
      final found = findNoteTreeNode(node.children, id);
      if (found != null) return found;
    }
    return null;
  }
}