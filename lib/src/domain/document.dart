/// Dart-side domain model for a Document.
/// Isolates UI from FFI-generated DocumentInfo type.
/// Deep model: createdAt is DateTime (not raw PlatformInt64).
class Document {
  final String id;
  final String title;
  final String filePath;
  final String? folderId;
  final List<String> tagIds;
  final DateTime createdAt;

  const Document({
    required this.id,
    required this.title,
    required this.filePath,
    this.folderId,
    required this.tagIds,
    required this.createdAt,
  });

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      filePath.hashCode ^
      folderId.hashCode ^
      tagIds.hashCode ^
      createdAt.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Document &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          filePath == other.filePath &&
          folderId == other.folderId &&
          tagIds == other.tagIds &&
          createdAt == other.createdAt;
}