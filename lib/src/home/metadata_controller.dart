import 'package:flutter/material.dart';
import 'package:starmind/src/domain/storage_repository.dart';
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';

/// Manages folder and tag metadata trees.
///
/// Provides CRUD operations for hierarchical folder/tag structures.
/// Depends on [StorageRepository] for persistence.
class MetadataController extends ChangeNotifier {
  final StorageRepository _repository;

  Folder? _folderTree;
  Tag? _tagTree;

  MetadataController(this._repository);

  Folder? get folderTree => _folderTree;
  Tag? get tagTree => _tagTree;

  /// Refresh folder and tag trees from storage.
  Future<void> refresh() async {
    try {
      _folderTree = await _repository.getFolderTree();
      _tagTree = await _repository.getTagTree();
    } catch (e) {
      debugPrint('Failed to load folder/tag metadata tree: $e');
    }
  }

  // ── Folder CRUD ──

  Future<void> createFolder(String name, String? parentId) async {
    await _repository.createFolder(name, parentId);
    await refresh();
  }

  Future<void> renameFolder(String id, String newName) async {
    await _repository.renameFolder(id, newName);
    await refresh();
  }

  Future<void> deleteFolder(String id, bool deleteDocuments) async {
    await _repository.deleteFolder(id, cascadeDelete: deleteDocuments);
    await refresh();
  }

  // ── Tag CRUD ──

  Future<void> createTag(String name, String? parentId, String? colorHex) async {
    await _repository.createTag(name, parentId, colorHex);
    await refresh();
  }

  Future<void> renameTag(String id, String newName) async {
    await _repository.renameTag(id, newName);
    await refresh();
  }

  Future<void> deleteTag(String id) async {
    await _repository.deleteTag(id);
    await refresh();
  }
}
