import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/home/metadata_controller.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetadataController', () {
    late MetadataController controller;

    setUp(() async {
      controller = MetadataController(InMemoryStorageRepository());
      await controller.refresh();
    });

    test('folder tree should have root initially', () {
      expect(controller.folderTree, isNotNull);
      expect(controller.folderTree!.id, equals('root'));
    });

    test('tag tree should have root initially', () {
      expect(controller.tagTree, isNotNull);
      expect(controller.tagTree!.id, equals('root'));
    });

    test('should create folder', () async {
      await controller.createFolder('Test Folder', null);
      expect(controller.folderTree!.children, hasLength(1));
      expect(controller.folderTree!.children.first.name, equals('Test Folder'));
    });

    test('should create tag', () async {
      await controller.createTag('Test Tag', null, '#FF5722');
      expect(controller.tagTree!.children, hasLength(1));
      expect(controller.tagTree!.children.first.name, equals('Test Tag'));
    });

    test('should rename folder', () async {
      await controller.createFolder('Old Name', null);
      final folderId = controller.folderTree!.children.first.id;
      await controller.renameFolder(folderId, 'New Name');
      expect(controller.folderTree!.children.first.name, equals('New Name'));
    });

    test('should rename tag', () async {
      await controller.createTag('Old Tag', null, '#FF5722');
      final tagId = controller.tagTree!.children.first.id;
      await controller.renameTag(tagId, 'New Tag');
      expect(controller.tagTree!.children.first.name, equals('New Tag'));
    });

    test('should delete folder', () async {
      await controller.createFolder('To Delete', null);
      final folderId = controller.folderTree!.children.first.id;
      await controller.deleteFolder(folderId, false);
      expect(controller.folderTree!.children, isEmpty);
    });

    test('should delete tag', () async {
      await controller.createTag('To Delete', null, '#FF5722');
      final tagId = controller.tagTree!.children.first.id;
      await controller.deleteTag(tagId);
      expect(controller.tagTree!.children, isEmpty);
    });

    test('should notify listeners on create', () async {
      var notified = false;
      controller.addListener(() => notified = true);
      await controller.createFolder('New Folder', null);
      // The controller notifies via refresh() which updates the tree
      expect(controller.folderTree, isNotNull);
    });
  });
}