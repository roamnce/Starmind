import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/home/document_query_controller.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentQueryController', () {
    late DocumentQueryController controller;

    setUp(() async {
      controller = DocumentQueryController(InMemoryStorageRepository());
      await controller.refresh();
    });

    test('documents should be empty initially', () {
      expect(controller.documents, isEmpty);
    });

    test('default filter should be "all"', () {
      expect(controller.activeFolderFilter, equals('all'));
    });

    test('default sort should be "modified"', () {
      expect(controller.sortBy, equals('modified'));
    });

    test('should set folder filter', () async {
      await controller.setFilters(folderFilter: 'test-folder-id');
      expect(controller.activeFolderFilter, equals('test-folder-id'));
    });

    test('should set tag filter', () async {
      await controller.setFilters(tagFilter: 'test-tag-id');
      expect(controller.activeTagFilter, equals('test-tag-id'));
    });

    test('resetOther should clear tag filter when setting folder filter', () async {
      await controller.setFilters(tagFilter: 'tag-id');
      await controller.setFilters(folderFilter: 'folder-id', resetOther: true);
      expect(controller.activeFolderFilter, equals('folder-id'));
      expect(controller.activeTagFilter, isNull);
    });

    test('should set search query', () async {
      await controller.setSearchQuery('test query');
      expect(controller.searchQuery, equals('test query'));
    });

    test('should set sort by', () async {
      await controller.setSortBy('title');
      expect(controller.sortBy, equals('title'));
    });

    test('should clear folder filter if matches', () {
      controller.setFilters(folderFilter: 'folder-123');
      controller.clearFolderFilterIfMatches('folder-123');
      expect(controller.activeFolderFilter, equals('all'));
    });

    test('should not clear folder filter if not matching', () async {
      await controller.setFilters(folderFilter: 'folder-123');
      controller.clearFolderFilterIfMatches('folder-456');
      expect(controller.activeFolderFilter, equals('folder-123'));
    });

    test('should clear tag filter if matches', () {
      controller.setFilters(tagFilter: 'tag-123');
      controller.clearTagFilterIfMatches('tag-123');
      expect(controller.activeTagFilter, isNull);
    });

    test('should import pdf file', () async {
      await controller.importPdfFile('Test PDF', '/path/to/pdf', null);
      expect(controller.documents, hasLength(1));
      expect(controller.documents.first.title, equals('Test PDF'));
    });

    test('should delete document', () async {
      await controller.importPdfFile('Test PDF', '/path/to/pdf', null);
      final docId = controller.documents.first.id;
      await controller.deleteDoc(docId);
      expect(controller.documents, isEmpty);
    });
  });
}