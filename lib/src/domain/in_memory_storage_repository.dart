import '../domain/annotation.dart';
import '../domain/document.dart';
import '../domain/folder.dart';
import '../domain/tag.dart';
import '../domain/storage_repository.dart';

/// In-memory adapter for testing and rapid prototyping.
/// No Rust runtime, no SQLite, no filesystem required.
class InMemoryStorageRepository implements StorageRepository {
  final Map<String, Folder> _folders = {};
  final Map<String, Tag> _tags = {};
  final Map<String, Document> _documents = {};
  final Map<String, Annotation> _annotations = {};
  final Map<String, Folder> _folderIndex = {}; // id -> Folder
  final Map<String, Tag> _tagIndex = {}; // id -> Tag
  bool _initialized = false;

  @override
  Future<void> initialize(String dbPath, String sandboxDir) async {
    _initialized = true;
  }

  // --- Folder operations ---

  @override
  Future<Folder> getFolderTree() async {
    return _folders['root'] ?? Folder(id: 'root', name: 'Root', children: [], documentCount: 0);
  }

  @override
  Future<String> createFolder(String name, String? parentId) async {
    final id = 'folder-${DateTime.now().millisecondsSinceEpoch}';
    final folder = Folder(id: id, name: name, children: [], documentCount: 0);
    _folderIndex[id] = folder;

    // Add to tree structure
    if (!_folders.containsKey('root')) {
      _folders['root'] = Folder(id: 'root', name: 'Root', children: [], documentCount: 0);
    }
    final root = _folders['root']!;
    _folders['root'] = Folder(
      id: root.id,
      name: root.name,
      children: [...root.children, folder],
      documentCount: root.documentCount,
    );
    return id;
  }

  @override
  Future<void> renameFolder(String id, String newName) async {
    if (_folderIndex.containsKey(id)) {
      final old = _folderIndex[id]!;
      _folderIndex[id] = Folder(
        id: old.id,
        name: newName,
        children: old.children,
        documentCount: old.documentCount,
      );
      // Update in tree
      _rebuildFolderTree();
    }
  }

  @override
  Future<void> deleteFolder(String id, {bool cascadeDelete = false}) async {
    _folderIndex.remove(id);
    _rebuildFolderTree();
  }

  void _rebuildFolderTree() {
    final children = _folderIndex.values.toList();
    _folders['root'] = Folder(
      id: 'root',
      name: 'Root',
      children: children,
      documentCount: children.length,
    );
  }

  // --- Tag operations ---

  @override
  Future<Tag> getTagTree() async {
    return _tags['root'] ?? Tag(id: 'root', name: 'Root', children: [], documentCount: 0);
  }

  @override
  Future<String> createTag(String name, String? parentId, String? colorHex) async {
    final id = 'tag-${DateTime.now().millisecondsSinceEpoch}';
    final tag = Tag(id: id, name: name, children: [], documentCount: 0);
    _tagIndex[id] = tag;

    // Add to tree structure
    if (!_tags.containsKey('root')) {
      _tags['root'] = Tag(id: 'root', name: 'Root', children: [], documentCount: 0);
    }
    final root = _tags['root']!;
    _tags['root'] = Tag(
      id: root.id,
      name: root.name,
      children: [...root.children, tag],
      documentCount: root.documentCount,
    );
    return id;
  }

  @override
  Future<void> renameTag(String id, String newName) async {
    if (_tagIndex.containsKey(id)) {
      final old = _tagIndex[id]!;
      _tagIndex[id] = Tag(
        id: old.id,
        name: newName,
        children: old.children,
        documentCount: old.documentCount,
      );
      _rebuildTagTree();
    }
  }

  @override
  Future<void> deleteTag(String id) async {
    _tagIndex.remove(id);
    _rebuildTagTree();
  }

  void _rebuildTagTree() {
    final children = _tagIndex.values.toList();
    _tags['root'] = Tag(
      id: 'root',
      name: 'Root',
      children: children,
      documentCount: children.length,
    );
  }

  // --- Document operations ---

  @override
  Future<String> importDocument(String title, String sourcePath, String? folderId) async {
    final id = 'doc-${DateTime.now().millisecondsSinceEpoch}';
    _documents[id] = Document(
      id: id,
      title: title,
      filePath: sourcePath,
      folderId: folderId,
      tagIds: [],
      createdAt: DateTime.now(),
    );
    return id;
  }

  @override
  Future<void> deleteDocument(String id) async {
    _documents.remove(id);
  }

  @override
  Future<List<Document>> getDocuments({
    String? folderId,
    String? tagId,
    String? searchQuery,
    String sortBy = 'recent',
  }) async {
    var result = _documents.values.toList();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result.where((d) => d.title.contains(searchQuery)).toList();
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<void> bindTag(String docId, String tagId) async {}

  @override
  Future<void> unbindTag(String docId, String tagId) async {}

  // --- Annotation operations ---

  @override
  Future<String> createAnnotation(Annotation annotation) async {
    _annotations[annotation.id] = annotation;
    return annotation.id;
  }

  @override
  Future<List<Annotation>> getAnnotations(String documentId) async {
    return _annotations.values
        .where((a) => a.documentId == documentId)
        .toList();
  }

  @override
  Future<List<Annotation>> getAnnotationsForPage(
      String documentId, int pageIndex) async {
    return _annotations.values
        .where((a) => a.documentId == documentId && a.pageIndex == pageIndex)
        .toList();
  }

  @override
  Future<void> updateAnnotationColor(String id, String colorHex) async {
    if (_annotations.containsKey(id)) {
      final old = _annotations[id]!;
      _annotations[id] = Annotation(
        id: old.id,
        documentId: old.documentId,
        pageIndex: old.pageIndex,
        type: old.type,
        category: old.category,
        colorHex: colorHex,
        createdAt: old.createdAt,
        modifiedAt: DateTime.now(),
        startCharIndex: old.startCharIndex,
        endCharIndex: old.endCharIndex,
        selectedText: old.selectedText,
        rects: old.rects,
        strokes: old.strokes,
        noteContent: old.noteContent,
        noteRect: old.noteRect,
      );
    }
  }

  @override
  Future<void> updateAnnotationNoteContent(String id, String content) async {
    if (_annotations.containsKey(id)) {
      final old = _annotations[id]!;
      _annotations[id] = Annotation(
        id: old.id,
        documentId: old.documentId,
        pageIndex: old.pageIndex,
        type: old.type,
        category: old.category,
        colorHex: old.colorHex,
        createdAt: old.createdAt,
        modifiedAt: DateTime.now(),
        startCharIndex: old.startCharIndex,
        endCharIndex: old.endCharIndex,
        selectedText: old.selectedText,
        rects: old.rects,
        strokes: old.strokes,
        noteContent: content,
        noteRect: old.noteRect,
      );
    }
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    _annotations.remove(id);
  }

  // --- Test helpers ---

  /// Pre-seed a folder tree for testing.
  void seedFolderTree(Folder tree) {
    _folders['root'] = tree;
  }

  /// Pre-seed a tag tree for testing.
  void seedTagTree(Tag tree) {
    _tags['root'] = tree;
  }

  /// Pre-seed a document list for testing.
  void seedDocuments(List<Document> docs) {
    for (final doc in docs) {
      _documents[doc.id] = doc;
    }
  }

  /// Pre-seed annotations for testing.
  void seedAnnotations(List<Annotation> annotations) {
    for (final annotation in annotations) {
      _annotations[annotation.id] = annotation;
    }
  }
}