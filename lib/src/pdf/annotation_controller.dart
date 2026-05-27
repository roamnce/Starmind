import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/domain/storage_repository.dart';
import 'package:starmind/src/pdf/undo_redo_stack.dart';

/// Manages annotations for a specific PDF document.
///
/// Provides:
/// - CRUD operations for all annotation types
/// - Page-indexed annotation lookup for efficient rendering
/// - Document-level Undo/Redo stack
///
/// Coordinates with [StorageRepository] for persistence.
class AnnotationController extends ChangeNotifier {
  final StorageRepository _repository;
  final String documentId;
  final Uuid _uuid = const Uuid();

  /// All annotations for this document.
  List<Annotation> _annotations = [];

  /// Annotations indexed by page number for efficient lookup.
  final Map<int, List<Annotation>> _pageAnnotations = {};

  /// Document-level undo/redo stack (shared with zoom/scroll operations).
  final UndoRedoStack undoRedoStack = UndoRedoStack();

  AnnotationController({
    required StorageRepository repository,
    required this.documentId,
  }) : _repository = repository;

  /// Get all annotations for this document.
  List<Annotation> get annotations => _annotations;

  /// Get annotations for a specific page.
  List<Annotation> annotationsForPage(int pageIndex) =>
      _pageAnnotations[pageIndex] ?? [];

  /// Whether undo is available.
  bool get canUndo => undoRedoStack.canUndo;

  /// Whether redo is available.
  bool get canRedo => undoRedoStack.canRedo;

  /// Load annotations from storage.
  Future<void> loadAnnotations() async {
    try {
      _annotations = await _repository.getAnnotations(documentId);
      _rebuildPageIndex();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load annotations: $e');
    }
  }

  void _rebuildPageIndex() {
    _pageAnnotations.clear();
    for (final annotation in _annotations) {
      _pageAnnotations.putIfAbsent(annotation.pageIndex, () => []);
      _pageAnnotations[annotation.pageIndex]!.add(annotation);
    }
  }

  // ── Create Annotations ──

  /// Create a text highlight annotation.
  Future<void> createHighlight({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) async {
    final annotation = Annotation.highlight(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  /// Create a text underline annotation.
  Future<void> createUnderline({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) async {
    final annotation = Annotation.underline(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  /// Create a text wave line annotation.
  Future<void> createWave({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) async {
    final annotation = Annotation.wave(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  /// Create a text strikethrough annotation.
  Future<void> createStrikeOut({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) async {
    final annotation = Annotation.strikeOut(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  /// Create an ink/handwriting annotation.
  Future<void> createInk({
    required int pageIndex,
    required List<InkStroke> strokes,
    String colorHex = '#000000',
  }) async {
    final annotation = Annotation.ink(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      strokes: strokes,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  /// Create a text note annotation.
  Future<void> createNote({
    required int pageIndex,
    required String content,
    required AnnotationRect rect,
    String colorHex = '#FFFF00',
  }) async {
    final annotation = Annotation.note(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      noteContent: content,
      noteRect: rect,
      colorHex: colorHex,
    );

    await _createAnnotationWithUndo(annotation);
  }

  Future<void> _createAnnotationWithUndo(Annotation annotation) async {
    // Create undo action before persisting
    undoRedoStack.push(CreateAnnotationAction(
      controller: this,
      annotation: annotation,
    ));

    await _repository.createAnnotation(annotation);
    _annotations.add(annotation);
    _pageAnnotations.putIfAbsent(annotation.pageIndex, () => []);
    _pageAnnotations[annotation.pageIndex]!.add(annotation);
    notifyListeners();
  }

  // ── Update Annotations ──

  /// Update the color of an annotation.
  Future<void> updateColor(String annotationId, String newColorHex) async {
    final index = _annotations.indexWhere((a) => a.id == annotationId);
    if (index == -1) return;

    final oldAnnotation = _annotations[index];
    final oldColor = oldAnnotation.colorHex;

    // Create undo action
    undoRedoStack.push(UpdateAnnotationAction(
      controller: this,
      annotationId: annotationId,
      field: 'colorHex',
      oldValue: oldColor,
      newValue: newColorHex,
    ));

    await _repository.updateAnnotationColor(annotationId, newColorHex);

    // Update local state
    final updated = Annotation(
      id: oldAnnotation.id,
      documentId: oldAnnotation.documentId,
      pageIndex: oldAnnotation.pageIndex,
      type: oldAnnotation.type,
      category: oldAnnotation.category,
      colorHex: newColorHex,
      createdAt: oldAnnotation.createdAt,
      modifiedAt: DateTime.now(),
      startCharIndex: oldAnnotation.startCharIndex,
      endCharIndex: oldAnnotation.endCharIndex,
      selectedText: oldAnnotation.selectedText,
      rects: oldAnnotation.rects?.map((r) => r.copy()).toList(),
      strokes: oldAnnotation.strokes?.map((s) => s.copy()).toList(),
      noteContent: oldAnnotation.noteContent,
      noteRect: oldAnnotation.noteRect?.copy(),
    );

    _annotations[index] = updated;
    _rebuildPageIndex();
    notifyListeners();
  }

  /// Update the content of a note annotation.
  Future<void> updateNoteContent(String annotationId, String newContent) async {
    final index = _annotations.indexWhere((a) => a.id == annotationId);
    if (index == -1) return;

    final oldAnnotation = _annotations[index];
    if (oldAnnotation.type != AnnotationType.note) return;

    final oldContent = oldAnnotation.noteContent ?? '';

    // Create undo action
    undoRedoStack.push(UpdateAnnotationAction(
      controller: this,
      annotationId: annotationId,
      field: 'noteContent',
      oldValue: oldContent,
      newValue: newContent,
    ));

    await _repository.updateAnnotationNoteContent(annotationId, newContent);

    // Update local state
    final updated = Annotation(
      id: oldAnnotation.id,
      documentId: oldAnnotation.documentId,
      pageIndex: oldAnnotation.pageIndex,
      type: oldAnnotation.type,
      category: oldAnnotation.category,
      colorHex: oldAnnotation.colorHex,
      createdAt: oldAnnotation.createdAt,
      modifiedAt: DateTime.now(),
      startCharIndex: oldAnnotation.startCharIndex,
      endCharIndex: oldAnnotation.endCharIndex,
      selectedText: oldAnnotation.selectedText,
      rects: oldAnnotation.rects?.map((r) => r.copy()).toList(),
      strokes: oldAnnotation.strokes?.map((s) => s.copy()).toList(),
      noteContent: newContent,
      noteRect: oldAnnotation.noteRect?.copy(),
    );

    _annotations[index] = updated;
    notifyListeners();
  }

  // ── Delete Annotation ──

  /// Delete an annotation.
  Future<void> deleteAnnotation(String annotationId) async {
    final index = _annotations.indexWhere((a) => a.id == annotationId);
    if (index == -1) return;

    final deletedAnnotation = _annotations[index];

    // Create undo action before deleting
    undoRedoStack.push(DeleteAnnotationAction(
      controller: this,
      annotation: deletedAnnotation.deepCopy(),
    ));

    await _repository.deleteAnnotation(annotationId);
    _annotations.removeAt(index);
    _rebuildPageIndex();
    notifyListeners();
  }

  // ── Undo/Redo ──

  /// Undo the last action.
  Future<void> undo() async {
    await undoRedoStack.undo();
    notifyListeners();
  }

  /// Redo the last undone action.
  Future<void> redo() async {
    await undoRedoStack.redo();
    notifyListeners();
  }

  /// Clear the undo/redo history.
  void clearUndoRedo() {
    undoRedoStack.clear();
    notifyListeners();
  }

  // ── Internal methods for Undo/Redo actions ──

  /// Internal: Add annotation without creating undo action (used by redo).
  Future<void> _addAnnotation(Annotation annotation) async {
    await _repository.createAnnotation(annotation);
    _annotations.add(annotation);
    _pageAnnotations.putIfAbsent(annotation.pageIndex, () => []);
    _pageAnnotations[annotation.pageIndex]!.add(annotation);
  }

  /// Internal: Remove annotation without creating undo action (used by undo).
  Future<void> _removeAnnotation(String annotationId) async {
    await _repository.deleteAnnotation(annotationId);
    _annotations.removeWhere((a) => a.id == annotationId);
    _rebuildPageIndex();
  }

  /// Internal: Update field without creating undo action (used by undo/redo).
  Future<void> _updateField(String annotationId, String field, dynamic value) async {
    final index = _annotations.indexWhere((a) => a.id == annotationId);
    if (index == -1) return;

    final oldAnnotation = _annotations[index];

    if (field == 'colorHex') {
      await _repository.updateAnnotationColor(annotationId, value as String);

      final updated = Annotation(
        id: oldAnnotation.id,
        documentId: oldAnnotation.documentId,
        pageIndex: oldAnnotation.pageIndex,
        type: oldAnnotation.type,
        category: oldAnnotation.category,
        colorHex: value,
        createdAt: oldAnnotation.createdAt,
        modifiedAt: DateTime.now(),
        startCharIndex: oldAnnotation.startCharIndex,
        endCharIndex: oldAnnotation.endCharIndex,
        selectedText: oldAnnotation.selectedText,
        rects: oldAnnotation.rects?.map((r) => r.copy()).toList(),
        strokes: oldAnnotation.strokes?.map((s) => s.copy()).toList(),
        noteContent: oldAnnotation.noteContent,
        noteRect: oldAnnotation.noteRect?.copy(),
      );

      _annotations[index] = updated;
    } else if (field == 'noteContent') {
      await _repository.updateAnnotationNoteContent(annotationId, value as String);

      final updated = Annotation(
        id: oldAnnotation.id,
        documentId: oldAnnotation.documentId,
        pageIndex: oldAnnotation.pageIndex,
        type: oldAnnotation.type,
        category: oldAnnotation.category,
        colorHex: oldAnnotation.colorHex,
        createdAt: oldAnnotation.createdAt,
        modifiedAt: DateTime.now(),
        startCharIndex: oldAnnotation.startCharIndex,
        endCharIndex: oldAnnotation.endCharIndex,
        selectedText: oldAnnotation.selectedText,
        rects: oldAnnotation.rects?.map((r) => r.copy()).toList(),
        strokes: oldAnnotation.strokes?.map((s) => s.copy()).toList(),
        noteContent: value,
        noteRect: oldAnnotation.noteRect?.copy(),
      );

      _annotations[index] = updated;
    }

    _rebuildPageIndex();
  }
}

// ── Undo/Redo Actions ──

/// Action for creating an annotation.
class CreateAnnotationAction extends AnnotationAction {
  final AnnotationController controller;
  final Annotation annotation;

  CreateAnnotationAction({
    required this.controller,
    required this.annotation,
  });

  @override
  Future<void> undo() async {
    await controller._removeAnnotation(annotation.id);
  }

  @override
  Future<void> redo() async {
    await controller._addAnnotation(annotation);
  }
}

/// Action for deleting an annotation.
class DeleteAnnotationAction extends AnnotationAction {
  final AnnotationController controller;
  final Annotation annotation;

  DeleteAnnotationAction({
    required this.controller,
    required this.annotation,
  });

  @override
  Future<void> undo() async {
    await controller._addAnnotation(annotation);
  }

  @override
  Future<void> redo() async {
    await controller._removeAnnotation(annotation.id);
  }
}

/// Action for updating an annotation field.
class UpdateAnnotationAction extends AnnotationAction {
  final AnnotationController controller;
  final String annotationId;
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  UpdateAnnotationAction({
    required this.controller,
    required this.annotationId,
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  @override
  Future<void> undo() async {
    await controller._updateField(annotationId, field, oldValue);
  }

  @override
  Future<void> redo() async {
    await controller._updateField(annotationId, field, newValue);
  }
}