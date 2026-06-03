/// Generic tree node interface for Folder and Tag hierarchies.
/// Provides common tree operations via extension methods.
abstract class TreeNode {
  /// Unique identifier for this node.
  String get id;

  /// Display name of this node.
  String get name;

  /// Child nodes in the tree hierarchy.
  List<TreeNode> get children;

  /// Count of documents directly in this node (not including children).
  int get documentCount;
}

/// Extension methods for tree traversal and queries.
extension TreeOperations on TreeNode {
  /// Finds a node with the given ID in this tree.
  /// Returns null if not found.
  TreeNode? findNode(String targetId) {
    if (id == targetId) return this;
    for (final child in children) {
      final found = child.findNode(targetId);
      if (found != null) return found;
    }
    return null;
  }

  /// Calculates total document count including all descendants.
  int get totalDocumentCount {
    int total = documentCount;
    for (final child in children) {
      total += child.totalDocumentCount;
    }
    return total;
  }

  /// Flattens the tree into a list of all nodes.
  List<TreeNode> flatten() {
    final result = [this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }

  /// Traverses the tree in depth-first order, calling visitor for each node.
  void traverse(void Function(TreeNode) visitor) {
    visitor(this);
    for (final child in children) {
      child.traverse(visitor);
    }
  }

  /// Finds the path from this node to a node with the given ID.
  /// Returns null if not found.
  List<TreeNode>? pathTo(String targetId) {
    if (id == targetId) return [this];
    for (final child in children) {
      final childPath = child.pathTo(targetId);
      if (childPath != null) {
        return [this, ...childPath];
      }
    }
    return null;
  }

  /// Returns the depth of this node (0 for root).
  int depth({TreeNode? root}) {
    if (root == null) {
      // Assume this is the root
      return 0;
    }
    final path = root.pathTo(id);
    return path == null ? 0 : path.length - 1;
  }

  /// Checks if this node contains a child with the given ID.
  bool hasChild(String targetId) {
    for (final child in children) {
      if (child.id == targetId || child.hasChild(targetId)) {
        return true;
      }
    }
    return false;
  }

  /// Returns all leaf nodes (nodes with no children).
  List<TreeNode> leafNodes() {
    if (children.isEmpty) return [this];
    final leaves = <TreeNode>[];
    for (final child in children) {
      leaves.addAll(child.leafNodes());
    }
    return leaves;
  }

  /// Counts total nodes in the tree (including this node).
  int get nodeCount {
    int count = 1;
    for (final child in children) {
      count += child.nodeCount;
    }
    return count;
  }
}

/// Utility functions for building trees from flat data.
class TreeBuilder {
  /// Builds a tree from flat items with parent references.
  ///
  /// [items] - Flat list of items with id, name, parentId, and extra data.
  /// [rootId] - ID for the root node.
  /// [rootName] - Name for the root node.
  /// [createNode] - Factory function to create a node from item data.
  static T buildTree<T extends TreeNode>(
    List<TreeItemData> items,
    String rootId,
    String rootName,
    T Function(String id, String name, List<T> children, int documentCount) createNode,
  ) {
    // Build parent -> children map
    final parentToChildren = <String?, List<TreeItemData>>{};
    for (final item in items) {
      final parentId = item.parentId;
      parentToChildren.putIfAbsent(parentId, () => []).add(item);
    }

    // Recursively build children
    List<T> buildChildren(String? parentId) {
      final childItems = parentToChildren[parentId] ?? [];
      return childItems.map((item) {
        final children = buildChildren(item.id);
        return createNode(item.id, item.name, children, item.documentCount);
      }).toList();
    }

    final rootChildren = buildChildren(null);
    return createNode(rootId, rootName, rootChildren, 0);
  }
}

/// Data for a single tree item before tree construction.
class TreeItemData {
  final String id;
  final String name;
  final String? parentId;
  final int documentCount;

  TreeItemData({
    required this.id,
    required this.name,
    this.parentId,
    this.documentCount = 0,
  });
}