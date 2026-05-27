import 'package:flutter/material.dart';
import 'package:starmind/src/domain/storage_repository.dart';
import 'package:starmind/src/domain/document.dart';

/// Manages document queries, filtering, and sorting.
///
/// Provides document list access with filter/search capabilities.
/// Depends on [StorageRepository] for persistence.
class DocumentQueryController extends ChangeNotifier {
  final StorageRepository _repository;

  List<Document> _documents = [];
  String? _activeFolderFilter = 'all';
  String? _activeTagFilter;
  String _searchQuery = '';
  String _sortBy = 'modified';

  DocumentQueryController(this._repository);

  List<Document> get documents => _documents;
  String? get activeFolderFilter => _activeFolderFilter;
  String? get activeTagFilter => _activeTagFilter;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;

  /// Refresh document list from storage with current filters.
  Future<void> refresh() async {
    try {
      _documents = await _repository.getDocuments(
        folderId: _activeFolderFilter,
        tagId: _activeTagFilter,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
      );
    } catch (e) {
      debugPrint('Failed to load documents: $e');
    }
  }

  Future<void> setFilters({
    String? folderFilter,
    String? tagFilter,
    bool resetOther = false,
  }) async {
    if (resetOther) {
      if (folderFilter != null) {
        _activeFolderFilter = folderFilter;
        _activeTagFilter = null;
      } else if (tagFilter != null) {
        _activeTagFilter = tagFilter;
        _activeFolderFilter = null;
      }
    } else {
      if (folderFilter != null) _activeFolderFilter = folderFilter;
      if (tagFilter != null) _activeTagFilter = tagFilter;
    }
    await refresh();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    await refresh();
  }

  Future<void> setSortBy(String sort) async {
    _sortBy = sort;
    await refresh();
  }

  Future<void> importPdfFile(String title, String sourcePath, String? folderId) async {
    await _repository.importDocument(title, sourcePath, folderId);
    await refresh();
  }

  Future<void> deleteDoc(String id) async {
    await _repository.deleteDocument(id);
    await refresh();
  }

  Future<void> bindTag(String docId, String tagId) async {
    await _repository.bindTag(docId, tagId);
    await refresh();
  }

  Future<void> unbindTag(String docId, String tagId) async {
    await _repository.unbindTag(docId, tagId);
    await refresh();
  }

  /// Clear folder filter if it matches the given id (used when deleting a folder).
  void clearFolderFilterIfMatches(String id) {
    if (_activeFolderFilter == id) {
      _activeFolderFilter = 'all';
    }
  }

  /// Clear tag filter if it matches the given id (used when deleting a tag).
  void clearTagFilterIfMatches(String id) {
    if (_activeTagFilter == id) {
      _activeTagFilter = null;
    }
  }
}
