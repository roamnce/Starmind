import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/home/tab_navigation_controller.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/domain/document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TabNavigationController', () {
    late TabNavigationController controller;

    setUp(() {
      controller = TabNavigationController();
      controller.init();
    });

    test('should have home tab initially', () {
      final root = controller.rootLayoutNode;
      expect(root, isA<LeafNode>());
      final leaf = root as LeafNode;
      expect(leaf.tabs, hasLength(1));
      expect(leaf.tabs.first.type, equals(TabType.home));
      expect(leaf.tabs.first.id, equals('home'));
    });

    test('should open document tab', () {
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
      expect(leaf.tabs.last.type, equals(TabType.pdf));
    });

    test('should switch to existing tab if already open', () {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);
      controller.selectTab(0); // Switch to home
      controller.openDocument(doc); // Open same doc again

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.tabs, hasLength(2)); // Not duplicated
      expect(leaf.activeIndex, equals(1)); // Switched to doc tab
    });

    test('should close tab', () {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);
      controller.closeTab(1);

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.tabs, hasLength(1));
      expect(leaf.tabs.first.type, equals(TabType.home));
    });

    test('should not close home tab', () {
      controller.closeTab(0);

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.tabs, hasLength(1));
      expect(leaf.tabs.first.type, equals(TabType.home));
    });

    test('should select tab', () {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);
      controller.selectTab(0);

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.activeIndex, equals(0));
    });

    test('should close tab by id', () {
      final doc = Document(
        id: 'doc-1',
        title: 'Test PDF',
        filePath: '/path/to/pdf',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc);
      controller.closeTabById('doc-1');

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.tabs, hasLength(1));
    });

    test('should adjust active index when closing active tab', () {
      final doc1 = Document(
        id: 'doc-1',
        title: 'Test PDF 1',
        filePath: '/path/to/pdf1',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      final doc2 = Document(
        id: 'doc-2',
        title: 'Test PDF 2',
        filePath: '/path/to/pdf2',
        tagIds: [],
        createdAt: DateTime.now(),
      );
      controller.openDocument(doc1);
      controller.openDocument(doc2);
      // Now: home(0), doc-1(1), doc-2(2), active=2

      controller.closeTab(2); // Close active tab (doc-2)

      final leaf = controller.rootLayoutNode as LeafNode;
      expect(leaf.activeIndex, equals(1)); // Should switch to doc-1
    });
  });
}