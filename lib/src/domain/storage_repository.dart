import '../domain/annotation.dart';
import '../domain/document.dart';
import '../domain/folder.dart';
import '../domain/tag.dart';

/// Seam between domain logic (WorkspaceController) and data access.
/// Two adapters: FfiStorageRepository (production, Rust FFI) and InMemoryStorageRepository (testing).
abstract class StorageRepository {
  Future<void> initialize(String dbPath, String sandboxDir);

  // Folder
  Future<Folder> getFolderTree();
  Future<String> createFolder(String name, String? parentId);
  Future<void> renameFolder(String id, String newName);
  Future<void> deleteFolder(String id, {bool cascadeDelete = false});

  // Tag
  Future<Tag> getTagTree();
  Future<String> createTag(String name, String? parentId, String? colorHex);
  Future<void> renameTag(String id, String newName);
  Future<void> deleteTag(String id);

  // Document
  Future<String> importDocument(String title, String sourcePath, String? folderId);
  Future<void> deleteDocument(String id);
  Future<List<Document>> getDocuments({
    String? folderId,
    String? tagId,
    String? searchQuery,
    String sortBy = 'recent',
  });
  Future<void> bindTag(String docId, String tagId);
  Future<void> unbindTag(String docId, String tagId);

  // Annotation
  /// Create a new annotation and return its ID.
  Future<String> createAnnotation(Annotation annotation);

  /// Get all annotations for a document.
  Future<List<Annotation>> getAnnotations(String documentId);

  /// Get annotations for a specific page.
  Future<List<Annotation>> getAnnotationsForPage(String documentId, int pageIndex);

  /// Update an annotation's color.
  Future<void> updateAnnotationColor(String id, String colorHex);

  /// Update a note annotation's content.
  Future<void> updateAnnotationNoteContent(String id, String content);

  /// Delete an annotation.
  Future<void> deleteAnnotation(String id);
}