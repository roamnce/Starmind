import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';
import 'package:starmind/src/domain/document.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceController', () {
    late WorkspaceController controller;
    late SharedPreferences mockPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();

      controller = WorkspaceController(InMemoryStorageRepository());
      controller.injectPrefs(mockPrefs);
      controller.injectPaths(dbPath: ':memory:', sandboxDir: './test_sandbox');
      await controller.init();
    });

    test('should start uninitialized', () {
      final freshController = WorkspaceController(InMemoryStorageRepository());
      expect(freshController.initialized, isFalse);
    });

    test('should be initialized after init()', () async {
      final ctrl = WorkspaceController(InMemoryStorageRepository());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ctrl.injectPrefs(prefs);
      ctrl.injectPaths(dbPath: ':memory:', sandboxDir: './test_sandbox');
      await ctrl.init();
      expect(ctrl.initialized, isTrue);
    });

    test('sub-controllers should be initialized', () {
      expect(controller.preferences, isNotNull);
      expect(controller.metadata, isNotNull);
      expect(controller.documentQuery, isNotNull);
      expect(controller.tabs, isNotNull);
    });

    // Convenience getter tests
    test('folder tree should have root initially', () {
      expect(controller.folderTree, isNotNull);
      expect(controller.folderTree!.id, equals('root'));
    });

    test('tag tree should have root initially', () {
      expect(controller.tagTree, isNotNull);
      expect(controller.tagTree!.id, equals('root'));
    });

    test('documents should be empty initially', () {
      expect(controller.documents, isEmpty);
    });

    test('root layout should have home tab', () {
      final root = controller.rootLayoutNode;
      expect(root, isA<LeafNode>());
      final leaf = root as LeafNode;
      expect(leaf.tabs, hasLength(1));
      expect(leaf.tabs.first.type, equals(TabType.home));
      expect(leaf.tabs.first.id, equals('home'));
    });

    test('default filter should be "all"', () {
      expect(controller.activeFolderFilter, equals('all'));
    });

    test('default sort should be "modified"', () {
      expect(controller.sortBy, equals('modified'));
    });

    test('should create folder via convenience method', () async {
      await controller.createFolder('Test Folder', null);
      expect(controller.folderTree!.children, hasLength(1));
      expect(controller.folderTree!.children.first.name, equals('Test Folder'));
    });

    test('should create tag via convenience method', () async {
      await controller.createTag('Test Tag', null, '#FF5722');
      expect(controller.tagTree!.children, hasLength(1));
      expect(controller.tagTree!.children.first.name, equals('Test Tag'));
    });

    test('should open document via convenience method', () async {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.tabs, hasLength(2));
      expect(leaf.tabs.last.id, equals('doc-1'));
    });

    test('should delete folder and clear filter', () async {
      await controller.createFolder('To Delete', null);
      final folderId = controller.folderTree!.children.first.id;
      await controller.setFilters(folderFilter: folderId);

      await controller.deleteFolder(folderId, false);

      expect(controller.folderTree!.children, isEmpty);
      expect(controller.activeFolderFilter, equals('all'));
    });

    test('should delete document and close tab', () async {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);

      // Import first
      await controller.importPdfFile('Test PDF', '/path/to/pdf', null);
      final docId = controller.documents.first.id;

      // Delete via controller (should close tab too)
      await controller.deleteDoc(docId);

      expect(controller.documents, isEmpty);
    });

    test('preferences getters should delegate to sub-controller', () {
      expect(controller.isDarkMode, equals(controller.preferences.isDarkMode));
      expect(controller.autoSave, equals(controller.preferences.autoSave));
      expect(controller.sidebarOpen, equals(controller.preferences.sidebarOpen));
    });
  });
}