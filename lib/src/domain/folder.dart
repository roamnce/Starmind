import 'package:flutter/material.dart';
import 'tree_node.dart';

/// Dart-side domain model for a Folder.
/// Isolates UI from FFI-generated FolderNode type.
/// Tree structure (children) is part of the domain concept per CONTEXT.md.
class Folder implements TreeNode {
  @override
  final String id;

  @override
  final String name;

  @override
  final List<Folder> children;

  @override
  final int documentCount;

  const Folder({
    required this.id,
    required this.name,
    required this.children,
    required this.documentCount,
  });

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ children.hashCode ^ documentCount.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          children == other.children &&
          documentCount == other.documentCount;
}