// test/mindmap/ui/mixins/tree_traversal_test.dart
//
// TreeTraversal Mixin 单元测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/ui/mixins/tree_traversal.dart';

// Test class that uses the mixin
class TestTreeTraversal with TreeTraversal {}

// Helper function to create Note with required fields
Note _createNote({
  required String id,
  required String title,
  String topicId = 'test-topic',
}) {
  return Note(
    id: id,
    topicId: topicId,
    title: title,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late TestTreeTraversal traversal;

  setUp(() {
    traversal = TestTreeTraversal();
  });

  group('TreeTraversal', () {
    group('findNoteInTree', () {
      test('finds note in root level', () {
        final note = _createNote(id: 'note-1', title: 'Root');
        final tree = [NoteTreeNode(note: note, children: [])];

        final found = traversal.findNoteInTree(tree, 'note-1');

        expect(found, isNotNull);
        expect(found?.id, equals('note-1'));
        expect(found?.title, equals('Root'));
      });

      test('finds note in nested children', () {
        final rootNote = _createNote(id: 'root', title: 'Root');
        final childNote = _createNote(id: 'child-1', title: 'Child');
        final grandchildNote = _createNote(id: 'grandchild-1', title: 'Grandchild');

        final tree = [
          NoteTreeNode(
            note: rootNote,
            children: [
              NoteTreeNode(
                note: childNote,
                children: [
                  NoteTreeNode(note: grandchildNote, children: []),
                ],
              ),
            ],
          ),
        ];

        final found = traversal.findNoteInTree(tree, 'grandchild-1');

        expect(found, isNotNull);
        expect(found?.id, equals('grandchild-1'));
        expect(found?.title, equals('Grandchild'));
      });

      test('returns null when note not found', () {
        final note = _createNote(id: 'note-1', title: 'Root');
        final tree = [NoteTreeNode(note: note, children: [])];

        final found = traversal.findNoteInTree(tree, 'nonexistent');

        expect(found, isNull);
      });

      test('searches multiple root nodes', () {
        final root1 = _createNote(id: 'root-1', title: 'Root 1');
        final root2 = _createNote(id: 'root-2', title: 'Root 2');
        final child = _createNote(id: 'child-1', title: 'Child');

        final tree = [
          NoteTreeNode(note: root1, children: []),
          NoteTreeNode(
            note: root2,
            children: [NoteTreeNode(note: child, children: [])],
          ),
        ];

        final found = traversal.findNoteInTree(tree, 'child-1');

        expect(found, isNotNull);
        expect(found?.id, equals('child-1'));
      });
    });

    group('findNoteTreeNode', () {
      test('finds node in root level', () {
        final note = _createNote(id: 'note-1', title: 'Root');
        final tree = [NoteTreeNode(note: note, children: [])];

        final found = traversal.findNoteTreeNode(tree, 'note-1');

        expect(found, isNotNull);
        expect(found?.note.id, equals('note-1'));
        expect(found?.children, isEmpty);
      });

      test('finds node with children', () {
        final rootNote = _createNote(id: 'root', title: 'Root');
        final childNote = _createNote(id: 'child-1', title: 'Child');

        final childNode = NoteTreeNode(note: childNote, children: []);
        final tree = [
          NoteTreeNode(note: rootNote, children: [childNode]),
        ];

        final found = traversal.findNoteTreeNode(tree, 'root');

        expect(found, isNotNull);
        expect(found?.children.length, equals(1));
        expect(found?.children.first.note.id, equals('child-1'));
      });

      test('returns null when node not found', () {
        final note = _createNote(id: 'note-1', title: 'Root');
        final tree = [NoteTreeNode(note: note, children: [])];

        final found = traversal.findNoteTreeNode(tree, 'nonexistent');

        expect(found, isNull);
      });
    });
  });
}