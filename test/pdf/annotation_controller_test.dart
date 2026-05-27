import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/undo_redo_stack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnnotationController', () {
    late InMemoryStorageRepository repository;
    late AnnotationController controller;

    setUp(() async {
      repository = InMemoryStorageRepository();
      await repository.initialize('', '');
      controller = AnnotationController(
        repository: repository,
        documentId: 'test-doc',
      );
    });

    test('should create highlight annotation', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Hello World',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.highlight));
      expect(controller.annotations.first.selectedText, equals('Hello World'));
    });

    test('should create underline annotation', () async {
      await controller.createUnderline(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Underlined',
        rects: [],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.underline));
    });

    test('should create wave annotation', () async {
      await controller.createWave(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Wavy',
        rects: [],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.wave));
    });

    test('should create strikeOut annotation', () async {
      await controller.createStrikeOut(
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'deleted',
        rects: [
          const AnnotationRect(left: 0, top: 10, right: 100, bottom: 20),
        ],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.strikeOut));
      expect(controller.annotations.first.selectedText, equals('deleted'));
      expect(controller.annotations.first.colorHex, equals('#FF0000'));
    });

    test('should create strikeOut annotation with custom color', () async {
      await controller.createStrikeOut(
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'deleted',
        rects: [],
        colorHex: '#00FF00',
      );

      expect(controller.annotations.first.colorHex, equals('#00FF00'));
    });

    test('should create ink annotation', () async {
      await controller.createInk(
        pageIndex: 0,
        strokes: [],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.ink));
    });

    test('should create note annotation', () async {
      await controller.createNote(
        pageIndex: 0,
        content: 'My note',
        rect: const AnnotationRect(left: 0, top: 0, right: 10, bottom: 10),
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.type, equals(AnnotationType.note));
      expect(controller.annotations.first.noteContent, equals('My note'));
    });

    test('should index annotations by page', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Page 0',
        rects: [],
      );

      await controller.createHighlight(
        pageIndex: 1,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Page 1',
        rects: [],
      );

      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 30,
        endCharIndex: 40,
        selectedText: 'Page 0 again',
        rects: [],
      );

      expect(controller.annotationsForPage(0), hasLength(2));
      expect(controller.annotationsForPage(1), hasLength(1));
      expect(controller.annotationsForPage(2), isEmpty);
    });

    test('should update annotation color', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
        colorHex: '#FFFF00',
      );

      final annotationId = controller.annotations.first.id;
      await controller.updateColor(annotationId, '#FF0000');

      expect(controller.annotations.first.colorHex, equals('#FF0000'));
    });

    test('should update note content', () async {
      await controller.createNote(
        pageIndex: 0,
        content: 'Original',
        rect: const AnnotationRect(left: 0, top: 0, right: 10, bottom: 10),
      );

      final annotationId = controller.annotations.first.id;
      await controller.updateNoteContent(annotationId, 'Updated');

      expect(controller.annotations.first.noteContent, equals('Updated'));
    });

    test('should delete annotation', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      final annotationId = controller.annotations.first.id;
      await controller.deleteAnnotation(annotationId);

      expect(controller.annotations, isEmpty);
    });
  });

  group('AnnotationController Undo/Redo', () {
    late InMemoryStorageRepository repository;
    late AnnotationController controller;

    setUp(() async {
      repository = InMemoryStorageRepository();
      await repository.initialize('', '');
      controller = AnnotationController(
        repository: repository,
        documentId: 'test-doc',
      );
    });

    test('should undo create annotation', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      expect(controller.annotations, hasLength(1));
      expect(controller.canUndo, isTrue);

      await controller.undo();

      expect(controller.annotations, isEmpty);
      expect(controller.canRedo, isTrue);
    });

    test('should redo create annotation', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      await controller.undo();
      expect(controller.annotations, isEmpty);

      await controller.redo();
      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.selectedText, equals('Test'));
    });

    test('should undo delete annotation', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      final annotationId = controller.annotations.first.id;
      await controller.deleteAnnotation(annotationId);
      expect(controller.annotations, isEmpty);

      await controller.undo();
      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.first.selectedText, equals('Test'));
    });

    test('should undo update color', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
        colorHex: '#FFFF00',
      );

      final annotationId = controller.annotations.first.id;
      await controller.updateColor(annotationId, '#FF0000');
      expect(controller.annotations.first.colorHex, equals('#FF0000'));

      await controller.undo();
      expect(controller.annotations.first.colorHex, equals('#FFFF00'));

      await controller.redo();
      expect(controller.annotations.first.colorHex, equals('#FF0000'));
    });

    test('should undo update note content', () async {
      await controller.createNote(
        pageIndex: 0,
        content: 'Original',
        rect: const AnnotationRect(left: 0, top: 0, right: 10, bottom: 10),
      );

      final annotationId = controller.annotations.first.id;
      await controller.updateNoteContent(annotationId, 'Updated');
      expect(controller.annotations.first.noteContent, equals('Updated'));

      await controller.undo();
      expect(controller.annotations.first.noteContent, equals('Original'));
    });

    test('should clear undo/redo history', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      expect(controller.canUndo, isTrue);

      controller.clearUndoRedo();

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('should track canUndo and canRedo', () async {
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      );

      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      await controller.undo();

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      await controller.redo();

      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
    });

    test('should clear redo stack on new action', () async {
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'First',
        rects: [],
      );

      await controller.undo();
      expect(controller.canRedo, isTrue);

      // New action should clear redo stack
      await controller.createHighlight(
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Second',
        rects: [],
      );

      expect(controller.canRedo, isFalse);
    });
  });

  group('UndoRedoStack', () {
    late UndoRedoStack stack;

    setUp(() {
      stack = UndoRedoStack();
    });

    test('should push and track actions', () {
      final action = _TestAction();
      stack.push(action);

      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);
      expect(stack.undoCount, equals(1));
    });

    test('should undo and redo', () async {
      final action = _TestAction();
      stack.push(action);

      await stack.undo();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);
      expect(action.undoCalled, isTrue);

      await stack.redo();
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);
      expect(action.redoCalled, isTrue);
    });

    test('should clear redo stack on new push', () async {
      stack.push(_TestAction());
      await stack.undo();
      expect(stack.canRedo, isTrue);

      stack.push(_TestAction());
      expect(stack.canRedo, isFalse);
    });

    test('should limit history size', () {
      for (int i = 0; i < 60; i++) {
        stack.push(_TestAction());
      }

      expect(stack.undoCount, equals(50));
    });

    test('should clear all history', () async {
      stack.push(_TestAction());
      stack.push(_TestAction());
      await stack.undo();

      stack.clear();

      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
      expect(stack.undoCount, equals(0));
      expect(stack.redoCount, equals(0));
    });
  });
}

/// Test action that tracks undo/redo calls.
class _TestAction extends AnnotationAction {
  bool undoCalled = false;
  bool redoCalled = false;

  @override
  Future<void> undo() async {
    undoCalled = true;
  }

  @override
  Future<void> redo() async {
    redoCalled = true;
  }
}
