import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/tree_node.dart';
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';

void main() {
  group('TreeOperations', () {
    // Helper to build test tree
    Folder buildTestFolderTree() {
      return Folder(
        id: 'root',
        name: 'Root',
        documentCount: 5,
        children: [
          Folder(
            id: 'folder-1',
            name: 'Folder 1',
            documentCount: 3,
            children: [
              Folder(id: 'folder-1-1', name: 'Folder 1-1', documentCount: 2, children: []),
              Folder(id: 'folder-1-2', name: 'Folder 1-2', documentCount: 1, children: []),
            ],
          ),
          Folder(id: 'folder-2', name: 'Folder 2', documentCount: 4, children: []),
        ],
      );
    }

    Tag buildTestTagTree() {
      return Tag(
        id: 'root',
        name: 'Root',
        documentCount: 10,
        colorHex: '#FF5722',
        children: [
          Tag(
            id: 'tag-1',
            name: 'Tag 1',
            documentCount: 5,
            colorHex: '#2196F3',
            children: [
              Tag(id: 'tag-1-1', name: 'Tag 1-1', documentCount: 2, colorHex: null, children: []),
            ],
          ),
          Tag(id: 'tag-2', name: 'Tag 2', documentCount: 3, colorHex: '#4CAF50', children: []),
        ],
      );
    }

    group('findNode', () {
      test('should find root node', () {
        final tree = buildTestFolderTree();
        final found = tree.findNode('root');
        expect(found, isNotNull);
        expect(found!.id, equals('root'));
      });

      test('should find child node', () {
        final tree = buildTestFolderTree();
        final found = tree.findNode('folder-1');
        expect(found, isNotNull);
        expect(found!.id, equals('folder-1'));
      });

      test('should find nested child node', () {
        final tree = buildTestFolderTree();
        final found = tree.findNode('folder-1-1');
        expect(found, isNotNull);
        expect(found!.id, equals('folder-1-1'));
      });

      test('should return null for non-existent node', () {
        final tree = buildTestFolderTree();
        final found = tree.findNode('non-existent');
        expect(found, isNull);
      });

      test('should work with Tag tree', () {
        final tree = buildTestTagTree();
        final found = tree.findNode('tag-1-1');
        expect(found, isNotNull);
        expect(found!.id, equals('tag-1-1'));
        expect((found as Tag).colorHex, isNull);
      });
    });

    group('totalDocumentCount', () {
      test('should count all documents in folder tree', () {
        final tree = buildTestFolderTree();
        // root: 5 + folder-1: 3 + folder-1-1: 2 + folder-1-2: 1 + folder-2: 4 = 15
        expect(tree.totalDocumentCount, equals(15));
      });

      test('should count documents in subtree', () {
        final tree = buildTestFolderTree();
        final folder1 = tree.findNode('folder-1') as Folder;
        // folder-1: 3 + folder-1-1: 2 + folder-1-2: 1 = 6
        expect(folder1.totalDocumentCount, equals(6));
      });

      test('should count documents in tag tree', () {
        final tree = buildTestTagTree();
        // root: 10 + tag-1: 5 + tag-1-1: 2 + tag-2: 3 = 20
        expect(tree.totalDocumentCount, equals(20));
      });

      test('should return documentCount for leaf node', () {
        final tree = buildTestFolderTree();
        final leaf = tree.findNode('folder-1-1') as Folder;
        expect(leaf.totalDocumentCount, equals(2));
      });
    });

    group('flatten', () {
      test('should flatten folder tree to list', () {
        final tree = buildTestFolderTree();
        final flat = tree.flatten();
        expect(flat.length, equals(5)); // root + 4 children
        expect(flat.map((n) => n.id).toList(), containsAll(['root', 'folder-1', 'folder-1-1', 'folder-1-2', 'folder-2']));
      });

      test('should flatten tag tree to list', () {
        final tree = buildTestTagTree();
        final flat = tree.flatten();
        expect(flat.length, equals(4)); // root + 3 children
      });

      test('should flatten leaf node to single item', () {
        final tree = buildTestFolderTree();
        final leaf = tree.findNode('folder-1-1') as Folder;
        final flat = leaf.flatten();
        expect(flat.length, equals(1));
        expect(flat.first.id, equals('folder-1-1'));
      });
    });

    group('traverse', () {
      test('should traverse all nodes in depth-first order', () {
        final tree = buildTestFolderTree();
        final visited = <String>[];
        tree.traverse((node) => visited.add(node.id));
        expect(visited, equals(['root', 'folder-1', 'folder-1-1', 'folder-1-2', 'folder-2']));
      });

      test('should traverse tag tree', () {
        final tree = buildTestTagTree();
        final visited = <String>[];
        tree.traverse((node) => visited.add(node.id));
        expect(visited, equals(['root', 'tag-1', 'tag-1-1', 'tag-2']));
      });
    });

    group('pathTo', () {
      test('should find path to root', () {
        final tree = buildTestFolderTree();
        final path = tree.pathTo('root');
        expect(path, isNotNull);
        expect(path!.length, equals(1));
        expect(path.first.id, equals('root'));
      });

      test('should find path to nested node', () {
        final tree = buildTestFolderTree();
        final path = tree.pathTo('folder-1-1');
        expect(path, isNotNull);
        expect(path!.length, equals(3));
        expect(path[0].id, equals('root'));
        expect(path[1].id, equals('folder-1'));
        expect(path[2].id, equals('folder-1-1'));
      });

      test('should return null for non-existent path', () {
        final tree = buildTestFolderTree();
        final path = tree.pathTo('non-existent');
        expect(path, isNull);
      });
    });

    group('hasChild', () {
      test('should return true for direct child', () {
        final tree = buildTestFolderTree();
        expect(tree.hasChild('folder-1'), isTrue);
      });

      test('should return true for nested child', () {
        final tree = buildTestFolderTree();
        expect(tree.hasChild('folder-1-1'), isTrue);
      });

      test('should return false for non-child', () {
        final tree = buildTestFolderTree();
        final folder2 = tree.findNode('folder-2') as Folder;
        expect(folder2.hasChild('folder-1'), isFalse);
      });

      test('should return false for self', () {
        final tree = buildTestFolderTree();
        expect(tree.hasChild('root'), isFalse);
      });
    });

    group('leafNodes', () {
      test('should find all leaf nodes', () {
        final tree = buildTestFolderTree();
        final leaves = tree.leafNodes();
        expect(leaves.length, equals(3));
        expect(leaves.map((n) => n.id).toList(), containsAll(['folder-1-1', 'folder-1-2', 'folder-2']));
      });

      test('should return self for leaf node', () {
        final tree = buildTestFolderTree();
        final leaf = tree.findNode('folder-2') as Folder;
        final leaves = leaf.leafNodes();
        expect(leaves.length, equals(1));
        expect(leaves.first.id, equals('folder-2'));
      });
    });

    group('nodeCount', () {
      test('should count all nodes in folder tree', () {
        final tree = buildTestFolderTree();
        expect(tree.nodeCount, equals(5));
      });

      test('should count all nodes in tag tree', () {
        final tree = buildTestTagTree();
        expect(tree.nodeCount, equals(4));
      });

      test('should count subtree nodes', () {
        final tree = buildTestFolderTree();
        final folder1 = tree.findNode('folder-1') as Folder;
        expect(folder1.nodeCount, equals(3)); // folder-1 + 2 children
      });
    });

    group('TreeNode interface on Folder and Tag', () {
      test('Folder should implement TreeNode', () {
        final folder = Folder(id: 'test', name: 'Test', children: [], documentCount: 0);
        expect(folder, isA<TreeNode>());
      });

      test('Tag should implement TreeNode', () {
        final tag = Tag(id: 'test', name: 'Test', children: [], colorHex: '#FF5722', documentCount: 0);
        expect(tag, isA<TreeNode>());
      });

      test('Folder children should be covariant', () {
        final folder = Folder(
          id: 'parent',
          name: 'Parent',
          documentCount: 0,
          children: [Folder(id: 'child', name: 'Child', children: [], documentCount: 0)],
        );
        // TreeNode.children returns List<TreeNode>, but Folder.children is List<Folder>
        expect(folder.children.first, isA<TreeNode>());
      });
    });
  });
}