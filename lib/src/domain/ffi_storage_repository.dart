import 'dart:convert';
import 'package:starmind/src/rust/api/storage.dart' as ffi;
import 'package:starmind/src/rust/storage/annotations.dart' as ffi_annotation;
import 'package:starmind/src/rust/storage/documents.dart' as ffi_doc;
import 'package:starmind/src/rust/storage/folders.dart' as ffi_folder;
import 'package:starmind/src/rust/storage/tags.dart' as ffi_tag;
import '../domain/annotation.dart';
import '../domain/document.dart';
import '../domain/folder.dart';
import '../domain/ink_stroke.dart';
import '../domain/tag.dart';
import '../domain/storage_repository.dart';

/// Production adapter: calls Rust FFI and converts FFI types to Dart domain models.
class FfiStorageRepository implements StorageRepository {
  bool _initialized = false;

  @override
  Future<void> initialize(String dbPath, String sandboxDir) async {
    if (_initialized) return;
    await ffi.initStorage(dbPath: dbPath, sandboxDir: sandboxDir);
    _initialized = true;
  }

  // --- Folder operations ---

  @override
  Future<Folder> getFolderTree() async {
    final ffiTree = await ffi.getFolderTree();
    return _convertFolderNode(ffiTree);
  }

  @override
  Future<String> createFolder(String name, String? parentId) async {
    return ffi.createFolder(name: name, parentId: parentId);
  }

  @override
  Future<void> renameFolder(String id, String newName) async {
    await ffi.renameFolder(id: id, newName: newName);
  }

  @override
  Future<void> deleteFolder(String id, {bool cascadeDelete = false}) async {
    await ffi.deleteFolder(id: id, deleteDocuments: cascadeDelete);
  }

  // --- Tag operations ---

  @override
  Future<Tag> getTagTree() async {
    final ffiTree = await ffi.getTagTree();
    return _convertTagNode(ffiTree);
  }

  @override
  Future<String> createTag(String name, String? parentId, String? colorHex) async {
    return ffi.createTag(name: name, parentId: parentId, colorHex: colorHex);
  }

  @override
  Future<void> renameTag(String id, String newName) async {
    await ffi.renameTag(id: id, newName: newName);
  }

  @override
  Future<void> deleteTag(String id) async {
    await ffi.deleteTag(id: id);
  }

  // --- Document operations ---

  @override
  Future<String> importDocument(String title, String sourcePath, String? folderId) async {
    return ffi.importPdf(title: title, sourcePath: sourcePath, folderId: folderId);
  }

  @override
  Future<void> deleteDocument(String id) async {
    await ffi.deleteDocument(id: id);
  }

  @override
  Future<List<Document>> getDocuments({
    String? folderId,
    String? tagId,
    String? searchQuery,
    String sortBy = 'recent',
  }) async {
    final ffiDocs = await ffi.getDocuments(
      folderId: folderId,
      tagId: tagId,
      searchQuery: searchQuery,
      sortBy: sortBy,
    );
    return ffiDocs.map(_convertDocumentInfo).toList();
  }

  @override
  Future<void> bindTag(String docId, String tagId) async {
    await ffi.addTagToDocument(docId: docId, tagId: tagId);
  }

  @override
  Future<void> unbindTag(String docId, String tagId) async {
    await ffi.removeTagFromDocument(docId: docId, tagId: tagId);
  }

  // --- Annotation operations ---

  @override
  Future<String> createAnnotation(Annotation annotation) async {
    return ffi.createAnnotationAutoId(
      documentId: annotation.documentId,
      pageIndex: annotation.pageIndex,
      annotationType: annotation.type.name,
      isStandard: annotation.isStandard,
      colorHex: annotation.colorHex,
      startCharIndex: annotation.startCharIndex,
      endCharIndex: annotation.endCharIndex,
      selectedText: annotation.selectedText,
      rectsJson: annotation.rects != null
          ? jsonEncode(annotation.rects!.map((r) => r.toJson()).toList())
          : null,
      strokesJson: annotation.strokes != null
          ? jsonEncode(annotation.strokes!.map((s) => s.toJson()).toList())
          : null,
      noteContent: annotation.noteContent,
      noteRectJson: annotation.noteRect != null
          ? jsonEncode(annotation.noteRect!.toJson())
          : null,
    );
  }

  @override
  Future<List<Annotation>> getAnnotations(String documentId) async {
    final ffiAnnotations = await ffi.getAnnotations(documentId: documentId);
    return ffiAnnotations.map(_convertAnnotation).toList();
  }

  @override
  Future<List<Annotation>> getAnnotationsForPage(
      String documentId, int pageIndex) async {
    final ffiAnnotations = await ffi.getAnnotationsForPage(
      documentId: documentId,
      pageIndex: pageIndex,
    );
    return ffiAnnotations.map(_convertAnnotation).toList();
  }

  @override
  Future<void> updateAnnotationColor(String id, String colorHex) async {
    final updates = <String, String>{'color_hex': colorHex};
    await ffi.updateAnnotation(id: id, updates: updates);
  }

  @override
  Future<void> updateAnnotationNoteContent(String id, String content) async {
    final updates = <String, String>{'note_content': content};
    await ffi.updateAnnotation(id: id, updates: updates);
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    await ffi.deleteAnnotation(id: id);
  }

  // --- FFI → Dart type conversion ---

  Folder _convertFolderNode(ffi_folder.FolderNode node) {
    return Folder(
      id: node.id,
      name: node.name,
      children: node.children.map(_convertFolderNode).toList(),
      documentCount: node.documentCount,
    );
  }

  Tag _convertTagNode(ffi_tag.TagNode node) {
    return Tag(
      id: node.id,
      name: node.name,
      children: node.children.map(_convertTagNode).toList(),
      colorHex: node.colorHex,
      documentCount: node.documentCount,
    );
  }

  Document _convertDocumentInfo(ffi_doc.DocumentInfo doc) {
    return Document(
      id: doc.id,
      title: doc.title,
      filePath: doc.filePath,
      folderId: doc.folderId,
      tagIds: doc.tagIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(doc.createdAt.toInt()),
    );
  }

  Annotation _convertAnnotation(ffi_annotation.AnnotationRecord record) {
    List<AnnotationRect>? rects;
    if (record.rectsJson != null) {
      final rectsList = jsonDecode(record.rectsJson!) as List;
      rects = rectsList
          .map((r) => AnnotationRect.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }

    List<InkStroke>? strokes;
    if (record.strokesJson != null) {
      final strokesList = jsonDecode(record.strokesJson!) as List;
      strokes = strokesList
          .map((s) => InkStroke.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    AnnotationRect? noteRect;
    if (record.noteRectJson != null) {
      noteRect = AnnotationRect.fromJson(
          Map<String, dynamic>.from(jsonDecode(record.noteRectJson!)));
    }

    final type = AnnotationType.values.firstWhere(
      (t) => t.name == record.annotationType,
      orElse: () => AnnotationType.highlight,
    );

    final category = record.isStandard
        ? AnnotationCategory.standard
        : AnnotationCategory.private;

    return Annotation(
      id: record.id,
      documentId: record.documentId,
      pageIndex: record.pageIndex,
      type: type,
      category: category,
      colorHex: record.colorHex,
      createdAt: DateTime.fromMillisecondsSinceEpoch(record.createdAt.toInt()),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(record.modifiedAt.toInt()),
      startCharIndex: record.startCharIndex,
      endCharIndex: record.endCharIndex,
      selectedText: record.selectedText,
      rects: rects,
      strokes: strokes,
      noteContent: record.noteContent,
      noteRect: noteRect,
    );
  }
}