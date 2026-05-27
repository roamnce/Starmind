import 'package:flutter/material.dart';
import 'tree_node.dart';

/// Dart-side domain model for a Tag.
/// Isolates UI from FFI-generated TagNode type.
/// Tree structure (children) is part of the domain concept per CONTEXT.md.
class Tag implements TreeNode {
  @override
  final String id;

  @override
  final String name;

  @override
  final List<Tag> children;

  final String? colorHex;

  @override
  final int documentCount;

  const Tag({
    required this.id,
    required this.name,
    required this.children,
    this.colorHex,
    required this.documentCount,
  });

  /// Parses colorHex (#RRGGBB format) into a Flutter Color.
  /// Returns null if colorHex is null or parsing fails.
  Color? get color {
    if (colorHex == null) return null;
    try {
      return Color(int.parse(colorHex!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      children.hashCode ^
      colorHex.hashCode ^
      documentCount.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          children == other.children &&
          colorHex == other.colorHex &&
          documentCount == other.documentCount;
}