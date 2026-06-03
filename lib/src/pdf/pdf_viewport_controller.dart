import 'package:flutter/material.dart';
import 'pdf_doc_session.dart';
import 'viewport_transform.dart';
import 'text_selection_model.dart';
import 'undo_redo_stack.dart';
import 'pdf_service.dart';
import 'pdf_highlight.dart';

/// Coordinator for PDF viewport operations.
///
/// This module coordinates three sub-modules:
/// - [session]: Document lifecycle and page data (PdfDocSession)
/// - [transform]: Zoom and pan transformations (ViewportTransform)
/// - [selection]: Text selection state (TextSelectionModel)
///
/// The undo/redo stack is shared with [AnnotationController]
/// to provide a unified document history.
///
/// ## Interface Design
///
/// This module exposes sub-modules directly via properties:
/// - `session` → document loading, page sizes, character data
/// - `transform` → zoom, pan, viewport state
/// - `selection` → text selection state and geometry
///
/// Callers use these properties directly instead of through pass-through methods.
/// This design follows the "deep module" principle: the interface is small,
/// but provides access to rich functionality through the sub-modules.
///
/// ## Coordination Logic
///
/// The controller adds value through coordination:
/// - `loadDoc()` clears selection when loading new document
/// - `undoRedoStack` is shared with AnnotationController
/// - Temporary highlights bridge selection and persistence
class PdfViewportController extends ChangeNotifier {
  // ── Sub-modules (public for direct access) ──

  /// Document lifecycle and page data.
  final PdfDocSession session;

  /// Zoom and pan transformations.
  final ViewportTransform transform;

  /// Text selection state and geometry.
  final TextSelectionModel selection;

  final UndoRedoStack _undoStack;

  // ── Constructor ──

  PdfViewportController({
    PdfService? pdfService,
    UndoRedoStack? undoStack,
  })  : session = PdfDocSession(pdfService: pdfService),
        transform = ViewportTransform(),
        selection = TextSelectionModel(),
        _undoStack = undoStack ?? UndoRedoStack() {
    // Forward notifications from sub-modules
    session.addListener(notifyListeners);
    transform.addListener(notifyListeners);
    selection.addListener(notifyListeners);
  }

  // ── Convenience Getters (commonly used) ──

  String? get docId => session.docId;
  String? get filePath => session.filePath;
  int get pageCount => session.pageCount;
  bool get isLoading => session.isLoading;
  String get loadingStep => session.loadingStep;
  String? get loadingError => session.loadingError;
  Map<int, Size> get pageSizes => session.pageSizes;

  // ── Coordination Logic ──

  /// Loads a PDF document and resets selection state.
  Future<void> loadDoc(String path) async {
    await session.loadDoc(path);
    selection.clearSelection();
    notifyListeners();
  }

  /// Closes the document and resets all state.
  Future<void> closeDoc() async {
    await session.closeDoc();
    selection.clearSelection();
    _highlights.clear();
    notifyListeners();
  }

  // ── Undo/Redo (delegates to shared stack) ──

  bool get canUndo => _undoStack.canUndo;
  bool get canRedo => _undoStack.canRedo;

  Future<void> undo() async {
    await _undoStack.undo();
    notifyListeners();
  }

  Future<void> redo() async {
    await _undoStack.redo();
    notifyListeners();
  }

  /// Returns the shared undo stack for injection into AnnotationController.
  UndoRedoStack get undoRedoStack => _undoStack;

  // ── Highlights (temporary, for rendering) ──
  // Note: Persistent highlights are stored in AnnotationController.
  // This is kept for backward compatibility with existing widgets.

  final Map<String, PdfHighlight> _highlights = {};
  List<PdfHighlight> get highlights => _highlights.values.toList();

  /// Add a temporary highlight (for rendering before AnnotationController persistence).
  void addHighlight(PdfHighlight highlight) {
    _highlights[highlight.id] = highlight;
    notifyListeners();
  }

  /// Remove a temporary highlight.
  void removeHighlight(String id) {
    _highlights.remove(id);
    notifyListeners();
  }

  // ── Annotation Selection (for edit toolbar) ──

  String? _selectedAnnotationId;
  String? get selectedAnnotationId => _selectedAnnotationId;
  Offset? _annotationToolbarPosition;
  Offset? get annotationToolbarPosition => _annotationToolbarPosition;

  /// Select an annotation for editing.
  void selectAnnotation(String annotationId, Offset toolbarPosition) {
    _selectedAnnotationId = annotationId;
    _annotationToolbarPosition = toolbarPosition;
    notifyListeners();
  }

  /// Deselect the current annotation.
  void deselectAnnotation() {
    _selectedAnnotationId = null;
    _annotationToolbarPosition = null;
    notifyListeners();
  }

  // ── Deprecated Pass-through (will be removed) ──
  // Callers should use selection.xxx directly. These are kept temporarily
  // to avoid breaking changes during migration.

  // Note: These deprecated getters have been removed.
  // All callers should use:
  //   - pdfCtrl.selection.selectingPageIndex
  //   - pdfCtrl.selection.selectionStartCharIndex
  //   - pdfCtrl.selection.selectionEndCharIndex
  //   - pdfCtrl.selection.selectionToolbarPosition

  @override
  void dispose() {
    session.removeListener(notifyListeners);
    transform.removeListener(notifyListeners);
    selection.removeListener(notifyListeners);
    session.dispose();
    transform.dispose();
    selection.dispose();
    super.dispose();
  }
}
