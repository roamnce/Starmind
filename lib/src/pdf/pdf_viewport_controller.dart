import 'package:flutter/material.dart';
import '../rust/api/pdf.dart' show CharInfo;
import 'pdf_doc_session.dart';
import 'viewport_transform.dart';
import 'text_selection_model.dart';
import 'undo_redo_stack.dart';
import 'pdf_service.dart';
import 'pdf_highlight.dart';

/// Facade controller for PDF viewport operations.
///
/// This controller coordinates three sub-modules:
/// - [PdfDocSession]: Document lifecycle and page data
/// - [ViewportTransform]: Zoom and pan transformations
/// - [TextSelectionModel]: Text selection state
///
/// The undo/redo stack is shared with [AnnotationController]
/// to provide a unified document history.
///
/// This is a shallow facade: the interface is kept stable for backward
/// compatibility, but all logic delegates to deep sub-modules.
class PdfViewportController extends ChangeNotifier {
  // ── Sub-modules ──

  final PdfDocSession _session;
  final ViewportTransform _transform;
  final TextSelectionModel _selection;
  final UndoRedoStack _undoStack;

  // ── Constructor ──

  PdfViewportController({
    PdfService? pdfService,
    UndoRedoStack? undoStack,
  })  : _session = PdfDocSession(pdfService: pdfService),
        _transform = ViewportTransform(),
        _selection = TextSelectionModel(),
        _undoStack = undoStack ?? UndoRedoStack() {
    // Forward notifications from sub-modules
    _session.addListener(notifyListeners);
    _transform.addListener(notifyListeners);
    _selection.addListener(notifyListeners);
  }

  // ── PdfDocSession Delegation ──

  String? get docId => _session.docId;
  String? get filePath => _session.filePath;
  int get pageCount => _session.pageCount;
  bool get isLoading => _session.isLoading;
  String get loadingStep => _session.loadingStep;
  String? get loadingError => _session.loadingError;
  Map<int, Size> get pageSizes => _session.pageSizes;

  Future<void> loadDoc(String path) async {
    await _session.loadDoc(path);
    _selection.clearSelection();
    notifyListeners();
  }

  Future<void> closeDoc() async {
    await _session.closeDoc();
    _selection.clearSelection();
    notifyListeners();
  }

  Future<Size> getPageSize(int pageIndex) => _session.getPageSize(pageIndex);
  Future<List<CharInfo>> getPageChars(int pageIndex) => _session.getPageChars(pageIndex);

  // ── ViewportTransform Delegation ──

  static double get minZoom => ViewportTransform.minZoom;
  static double get maxZoom => ViewportTransform.maxZoom;

  double get zoom => _transform.zoom;
  Offset get panOffset => _transform.panOffset;
  Size get viewportSize => _transform.viewportSize;
  bool get freePanEnabled => _transform.freePanEnabled;
  bool get palmRejectionEnabled => _transform.palmRejectionEnabled;

  void setZoom(double newZoom) => _transform.setZoom(newZoom);
  void setPanOffset(Offset offset) => _transform.setPanOffset(offset);
  void pan(Offset delta) => _transform.pan(delta);
  void zoomAt(Offset focalPoint, double newZoom) => _transform.zoomAt(focalPoint, newZoom);
  void setViewportState({double? zoom, Offset? panOffset}) =>
      _transform.setViewportState(zoom: zoom, panOffset: panOffset);
  void setViewportSize(Size size) => _transform.setViewportSize(size);
  void resetViewport() => _transform.resetViewport();
  void setFreePanEnabled(bool enabled) => _transform.setFreePanEnabled(enabled);
  void setPalmRejectionEnabled(bool enabled) => _transform.setPalmRejectionEnabled(enabled);
  ViewportState getViewportState() => _transform.getViewportState();
  void restoreViewportState(ViewportState state) => _transform.restoreViewportState(state);

  /// Constrain viewport boundaries (no-op with free pan mode).
  void constrainBounds(Size pdfSize, Size viewportSize) {
    if (freePanEnabled || pdfSize.isEmpty || viewportSize.isEmpty) return;

    final baseScale = viewportSize.width / pdfSize.width;
    final pdfDisplayWidth = pdfSize.width * baseScale * zoom;
    final pdfDisplayHeight = pdfSize.height * baseScale * zoom;

    double minX;
    double maxX;
    if (pdfDisplayWidth < viewportSize.width) {
      minX = (viewportSize.width - pdfDisplayWidth) / 2;
      maxX = minX;
    } else {
      minX = viewportSize.width - pdfDisplayWidth;
      maxX = 0.0;
    }

    double minY;
    double maxY;
    if (pdfDisplayHeight < viewportSize.height) {
      minY = (viewportSize.height - pdfDisplayHeight) / 2;
      maxY = minY;
    } else {
      minY = viewportSize.height - pdfDisplayHeight;
      maxY = 0.0;
    }

    final targetX = panOffset.dx.clamp(minX, maxX);
    final targetY = panOffset.dy.clamp(minY, maxY);
    setPanOffset(Offset(targetX, targetY));
  }

  // ── TextSelectionModel Delegation ──

  int? get selectingPageIndex => _selection.selectingPageIndex;
  int? get selectionStartCharIndex => _selection.selectionStartCharIndex;
  int? get selectionEndCharIndex => _selection.selectionEndCharIndex;
  Offset? get selectionToolbarPosition => _selection.selectionToolbarPosition;

  Future<void> startSelection(int pageIndex, Offset pdfPoint) =>
      _selection.startSelection(pageIndex, pdfPoint, _session.getPageChars);

  Future<void> updateSelection(Offset pdfPoint) =>
      _selection.updateSelection(pdfPoint, _session.getPageChars);

  void updateSelectionStart(int charIndex) =>
      _selection.updateSelectionStart(charIndex);

  void updateSelectionEnd(int charIndex) =>
      _selection.updateSelectionEnd(charIndex);

  void endSelection(Offset globalToolbarOffset) =>
      _selection.endSelection(globalToolbarOffset);

  void clearSelection() => _selection.clearSelection();

  List<Rect> getSelectionRects(int pageIndex) =>
      _selection.getSelectionRects(pageIndex, _session.pageCharsCache);

  List<Rect> mergeCharacterBoxes(List<CharInfo> selectedChars) =>
      _selection.mergeCharacterBoxes(selectedChars);

  String getSelectedText() => _selection.getSelectedText(_session.pageCharsCache);

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

  // ── Internal Access (for testing) ──

  /// Expose session for testing (internal seam).
  PdfDocSession get session => _session;

  /// Expose transform for testing (internal seam).
  ViewportTransform get transform => _transform;

  /// Expose selection for testing (internal seam).
  TextSelectionModel get selection => _selection;

  @override
  void dispose() {
    _session.removeListener(notifyListeners);
    _transform.removeListener(notifyListeners);
    _selection.removeListener(notifyListeners);
    _session.dispose();
    _transform.dispose();
    _selection.dispose();
    super.dispose();
  }
}
