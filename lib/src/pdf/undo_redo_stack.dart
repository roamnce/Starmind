/// Base class for undoable annotation actions.
///
/// Each action knows how to undo and redo itself.
abstract class AnnotationAction {
  /// Undo this action.
  Future<void> undo();

  /// Redo this action.
  Future<void> redo();
}

/// Manages a stack of undoable/redoable annotation actions.
///
/// This is a document-level stack, shared between:
/// - Annotation operations (create, update, delete)
/// - PDF view operations (zoom, scroll) - to be added later
///
/// Usage:
/// ```dart
/// final stack = UndoRedoStack();
/// stack.push(myAction);
/// if (stack.canUndo) stack.undo();
/// if (stack.canRedo) stack.redo();
/// ```
class UndoRedoStack {
  final List<AnnotationAction> _undoStack = [];
  final List<AnnotationAction> _redoStack = [];

  /// Maximum number of actions to keep in history.
  static const int maxHistorySize = 50;

  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of undoable actions.
  int get undoCount => _undoStack.length;

  /// Number of redoable actions.
  int get redoCount => _redoStack.length;

  /// Push a new action onto the undo stack.
  ///
  /// This clears the redo stack (new actions invalidate redo history).
  void push(AnnotationAction action) {
    _undoStack.add(action);

    // Limit history size
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }

    // Clear redo stack
    _redoStack.clear();
  }

  /// Undo the last action.
  ///
  /// Returns the undone action, or null if no action to undo.
  Future<AnnotationAction?> undo() async {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.removeLast();
    await action.undo();
    _redoStack.add(action);

    return action;
  }

  /// Redo the last undone action.
  ///
  /// Returns the redone action, or null if no action to redo.
  Future<AnnotationAction?> redo() async {
    if (_redoStack.isEmpty) return null;

    final action = _redoStack.removeLast();
    await action.redo();
    _undoStack.add(action);

    return action;
  }

  /// Clear all undo/redo history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}