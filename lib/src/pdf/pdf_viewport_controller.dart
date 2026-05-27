/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'pdf_service.dart';
import '../rust/api/pdf.dart' show CharInfo;

/// Model representing a text highlight or annotation on a PDF page.
class PdfHighlight {
  final String id;
  final int pageIndex;
  final int startCharIndex;
  final int endCharIndex;
  final Color color;
  final List<Rect> rects; // Bounding boxes in PDF point coordinates
  final String text;

  PdfHighlight({
    required this.id,
    required this.pageIndex,
    required this.startCharIndex,
    required this.endCharIndex,
    required this.color,
    required this.rects,
    required this.text,
  });
}

/// Abstract base class for all session undo/redo actions.
abstract class PdfUndoAction {
  void undo(PdfViewportController controller);
  void redo(PdfViewportController controller);
}

/// Undo/Redo action for adding a highlight.
class AddHighlightAction implements PdfUndoAction {
  final PdfHighlight highlight;
  AddHighlightAction(this.highlight);

  @override
  void undo(PdfViewportController controller) {
    controller.removeHighlightSilent(highlight.id);
  }

  @override
  void redo(PdfViewportController controller) {
    controller.addHighlightSilent(highlight);
  }
}

/// Undo/Redo action for removing a highlight.
class RemoveHighlightAction implements PdfUndoAction {
  final PdfHighlight highlight;
  RemoveHighlightAction(this.highlight);

  @override
  void undo(PdfViewportController controller) {
    controller.addHighlightSilent(highlight);
  }

  @override
  void redo(PdfViewportController controller) {
    controller.removeHighlightSilent(highlight.id);
  }
}

/// Manages PDF document states, zoom, pan, selection, and undo/redo stacks.
class PdfViewportController extends ChangeNotifier {
  final PdfService _pdfService = PdfService();

  // Diagnostic loading step tracking
  String _loadingStep = '';
  String get loadingStep => _loadingStep;
  String? _loadingError;
  String? get loadingError => _loadingError;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _docId;
  String? get docId => _docId;

  String? _filePath;
  String? get filePath => _filePath;

  int _pageCount = 0;
  int get pageCount => _pageCount;

  // ── Viewport State ──

  /// Current zoom factor (0.5 ~ 5.0).
  double _zoom = 1.0;
  double get zoom => _zoom;

  /// Minimum zoom factor (10% of original size).
  static const double minZoom = 0.1;

  /// Maximum zoom factor (3000% of original size).
  static const double maxZoom = 30.0;

  /// Pan offset in local viewport coordinates (baseScale units).
  /// Origin is the top-left corner of the child widget.
  Offset _panOffset = Offset.zero;
  Offset get panOffset => _panOffset;

  /// Whether free pan mode is enabled (no boundary constraints).
  bool _freePanEnabled = false;
  bool get freePanEnabled => _freePanEnabled;

  /// Whether palm rejection is enabled (stylus only for drawing).
  bool _palmRejectionEnabled = false;
  bool get palmRejectionEnabled => _palmRejectionEnabled;

  /// Viewport size in screen coordinates (set by widget).
  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;

  // Cache for page sizes: pageIndex -> Size(width, height)
  final Map<int, Size> _pageSizes = {};
  Map<int, Size> get pageSizes => _pageSizes;

  // Cache for characters: pageIndex -> list of CharInfo
  final Map<int, List<CharInfo>> _pageChars = {};

  // Active highlights: highlightId -> PdfHighlight
  final Map<String, PdfHighlight> _highlights = {};
  List<PdfHighlight> get highlights => _highlights.values.toList();

  // Selection states
  int? _selectingPageIndex;
  int? get selectingPageIndex => _selectingPageIndex;

  int? _selectionStartCharIndex;
  int? get selectionStartCharIndex => _selectionStartCharIndex;

  int? _selectionEndCharIndex;
  int? get selectionEndCharIndex => _selectionEndCharIndex;

  // Screen/Overlay layout position for showing the toolbar
  Offset? _selectionToolbarPosition;
  Offset? get selectionToolbarPosition => _selectionToolbarPosition;

  // Undo/Redo action stacks
  final List<PdfUndoAction> _undoStack = [];
  final List<PdfUndoAction> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Loads the PDF document and caches its initial properties.
  /// Each step updates UI so crash point can be identified.
  Future<void> loadDoc(String path) async {
    _filePath = path;
    _isLoading = true;
    _loadingError = null;

    // Step 1: Initialize PDFium engine
    _loadingStep = '步骤1: 初始化PDFium引擎...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _pdfService.initialize();
    } catch (e) {
      _loadingError = '步骤1失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 2: Load document file
    _loadingStep = '步骤2: 加载PDF文件...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      _docId = await _pdfService.loadDocument(path);
    } catch (e) {
      _loadingError = '步骤2失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 3: Get page count
    _loadingStep = '步骤3: 获取页数...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      _pageCount = await _pdfService.getPageCount(_docId!);
    } catch (e) {
      _loadingError = '步骤3失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 4a: Prepare to load first page size
    _loadingStep = '步骤4a: 准备获取页面尺寸...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4b: FFI call to get page size
    _loadingStep = '步骤4b: 调用FFI获取尺寸...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final sizeTuple = await _pdfService.getPageSize(_docId!, 0);
      _pageSizes[0] = Size(sizeTuple.$1, sizeTuple.$2);
    } catch (e) {
      _loadingError = '步骤4b失败(Dart异常): $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 4c: Page size returned successfully
    _loadingStep = '步骤4c: 尺寸获取成功 (${_pageSizes[0]?.width.toStringAsFixed(1)}x${_pageSizes[0]?.height.toStringAsFixed(1)})';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    _pageChars.clear();
    _highlights.clear();
    _undoStack.clear();
    _redoStack.clear();
    _clearSelectionSilent();

    // Step 5: About to switch to rendering mode
    _loadingStep = '步骤5: 准备切换到渲染模式...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));

    _loadingStep = '加载完成 ✓';
    _isLoading = false;
    notifyListeners();
  }

  /// Closes the document and releases PDFium memory cache.
  Future<void> closeDoc() async {
    if (_docId != null) {
      await _pdfService.closeDocument(_docId!);
      _docId = null;
      _filePath = null;
      _pageCount = 0;
      _loadingStep = '';
      _loadingError = null;
      _isLoading = false;
      _pageSizes.clear();
      _pageChars.clear();
      _highlights.clear();
      _undoStack.clear();
      _redoStack.clear();
      _clearSelectionSilent();
      notifyListeners();
    }
  }

  /// Sets the zoom factor (clamps between minZoom and maxZoom).
  void setZoom(double newZoom) {
    final clamped = newZoom.clamp(minZoom, maxZoom);
    if (_zoom != clamped) {
      _zoom = clamped;
      notifyListeners();
    }
  }

  /// Sets the pan offset (in PDF coordinates).
  void setPanOffset(Offset offset) {
    _panOffset = offset;
    notifyListeners();
  }

  /// Pan the viewport by a delta amount.
  void pan(Offset delta) {
    _panOffset += delta;
    notifyListeners();
  }

  /// Zoom with a specific focal point (the point that stays fixed on screen).
  /// The focal point remains at the same screen position after zooming.
  void zoomAt(Offset focalPoint, double newZoom) {
    final clampedZoom = newZoom.clamp(minZoom, maxZoom);
    if (clampedZoom == _zoom) return;

    // Calculate scale ratio
    final scaleRatio = clampedZoom / _zoom;

    // Adjust pan offset to keep the focal point fixed
    // New panOffset = focalPoint - (focalPoint - oldPanOffset) * scaleRatio
    _panOffset = Offset(
      focalPoint.dx - (focalPoint.dx - _panOffset.dx) * scaleRatio,
      focalPoint.dy - (focalPoint.dy - _panOffset.dy) * scaleRatio,
    );

    _zoom = clampedZoom;
    notifyListeners();
  }

  /// Constrain viewport boundaries to keep PDF visible.
  /// Centers PDF when smaller than viewport, clamps pan when larger.
  void constrainBounds(Size pdfSize, Size viewportSize) {
    final baseScale = viewportSize.width / pdfSize.width;
    final scaledWidth = pdfSize.width * baseScale * _zoom;
    final scaledHeight = pdfSize.height * baseScale * _zoom;

    // Horizontal constraint
    if (scaledWidth <= viewportSize.width) {
      // PDF width smaller than viewport, center it
      _panOffset = Offset((viewportSize.width - scaledWidth) / 2, _panOffset.dy);
    } else {
      // PDF width larger than viewport, clamp boundaries
      final minX = viewportSize.width - scaledWidth;
      final maxX = 0.0;
      _panOffset = Offset(_panOffset.dx.clamp(minX, maxX), _panOffset.dy);
    }

    // Vertical constraint
    if (scaledHeight <= viewportSize.height) {
      // PDF height smaller than viewport, center it
      _panOffset = Offset(_panOffset.dx, (viewportSize.height - scaledHeight) / 2);
    } else {
      // PDF height larger than viewport, clamp boundaries
      final minY = viewportSize.height - scaledHeight;
      final maxY = 0.0;
      _panOffset = Offset(_panOffset.dx, _panOffset.dy.clamp(minY, maxY));
    }

    notifyListeners();
  }

  /// Sets both zoom and pan offset in one update.
  void setViewportState({double? zoom, Offset? panOffset}) {
    if (zoom != null) {
      _zoom = zoom.clamp(minZoom, maxZoom);
    }
    if (panOffset != null) {
      _panOffset = panOffset;
    }
    notifyListeners();
  }

  /// Enables or disables free pan mode.
  void setFreePanEnabled(bool enabled) {
    if (_freePanEnabled != enabled) {
      _freePanEnabled = enabled;
      notifyListeners();
    }
  }

  /// Enables or disables palm rejection.
  void setPalmRejectionEnabled(bool enabled) {
    if (_palmRejectionEnabled != enabled) {
      _palmRejectionEnabled = enabled;
      notifyListeners();
    }
  }

  /// Sets the viewport size (called by widget).
  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  /// Resets viewport to default state (centered, zoom 1.0).
  void resetViewport() {
    _zoom = 1.0;
    _panOffset = Offset.zero;
    notifyListeners();
  }

  /// Gets the viewport state for persistence.
  ViewportState getViewportState() {
    return ViewportState(
      zoom: _zoom,
      panOffsetX: _panOffset.dx,
      panOffsetY: _panOffset.dy,
    );
  }

  /// Restores viewport state from persistence.
  void restoreViewportState(ViewportState state) {
    _zoom = state.zoom.clamp(minZoom, maxZoom);
    _panOffset = Offset(state.panOffsetX, state.panOffsetY);
    notifyListeners();
  }

  /// Retrieves the size of a page, reading from cache or FFI.
  Future<Size> getPageSize(int pageIndex) async {
    if (_pageSizes.containsKey(pageIndex)) {
      return _pageSizes[pageIndex]!;
    }
    if (_docId == null) return const Size(0, 0);

    final sizeTuple = await _pdfService.getPageSize(_docId!, pageIndex);
    final size = Size(sizeTuple.$1, sizeTuple.$2);
    _pageSizes[pageIndex] = size;
    return size;
  }

  /// Retrieves page characters, reading from cache or FFI.
  Future<List<CharInfo>> getPageChars(int pageIndex) async {
    if (_pageChars.containsKey(pageIndex)) {
      return _pageChars[pageIndex]!;
    }
    if (_docId == null) return [];

    final chars = await _pdfService.getPageChars(_docId!, pageIndex);
    _pageChars[pageIndex] = chars;
    return chars;
  }

  // --- Highlights Undo / Redo Operations ---

  void addHighlight(PdfHighlight highlight) {
    addHighlightSilent(highlight);
    _undoStack.add(AddHighlightAction(highlight));
    _redoStack.clear();
    notifyListeners();
  }

  void removeHighlight(String id) {
    final highlight = _highlights[id];
    if (highlight != null) {
      removeHighlightSilent(id);
      _undoStack.add(RemoveHighlightAction(highlight));
      _redoStack.clear();
      notifyListeners();
    }
  }

  void addHighlightSilent(PdfHighlight highlight) {
    _highlights[highlight.id] = highlight;
  }

  void removeHighlightSilent(String id) {
    _highlights.remove(id);
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      final action = _undoStack.removeLast();
      action.undo(this);
      _redoStack.add(action);
      notifyListeners();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final action = _redoStack.removeLast();
      action.redo(this);
      _undoStack.add(action);
      notifyListeners();
    }
  }

  // --- Character Selection & Coordinate Mapping ---

  /// Finds the character closest to the touch coordinate (in PDF point space).
  /// Penalizes vertical distance to ensure alignment with lines.
  int _findClosestChar(List<CharInfo> chars, Offset pdfPoint) {
    if (chars.isEmpty) return -1;

    int closestIndex = -1;
    double minDistance = double.maxFinite;

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final cLeft = char.left;
      final cRight = char.right;
      final cBottom = char.bottom;
      final cTop = char.top;

      // Distance from pdfPoint to character bounding box
      double dy = 0.0;
      if (pdfPoint.dy < cBottom) {
        dy = cBottom - pdfPoint.dy;
      } else if (pdfPoint.dy > cTop) {
        dy = pdfPoint.dy - cTop;
      }

      double dx = 0.0;
      if (pdfPoint.dx < cLeft) {
        dx = cLeft - pdfPoint.dx;
      } else if (pdfPoint.dx > cRight) {
        dx = pdfPoint.dx - cRight;
      }

      // Heuristic: heavily weight vertical distance (line mismatch) over horizontal
      final distance = dy * dy * 12.0 + dx * dx;
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Begins a new text selection on a long press or drag starting point.
  Future<void> startSelection(int pageIndex, Offset pdfPoint) async {
    final chars = await getPageChars(pageIndex);
    final idx = _findClosestChar(chars, pdfPoint);
    if (idx != -1) {
      _selectingPageIndex = pageIndex;
      _selectionStartCharIndex = idx;
      _selectionEndCharIndex = idx;
      _selectionToolbarPosition = null;
      notifyListeners();
    }
  }

  /// Updates the selection end point during drag selection.
  Future<void> updateSelection(Offset pdfPoint) async {
    if (_selectingPageIndex == null || _selectionStartCharIndex == null) return;
    final chars = await getPageChars(_selectingPageIndex!);
    final idx = _findClosestChar(chars, pdfPoint);
    if (idx != -1 && idx != _selectionEndCharIndex) {
      _selectionEndCharIndex = idx;
      notifyListeners();
    }
  }

  /// Concludes the selection drag and positions the floating toolbar.
  /// [globalToolbarOffset] specifies the screen coordinate directly above selection.
  void endSelection(Offset globalToolbarOffset) {
    if (_selectingPageIndex != null &&
        _selectionStartCharIndex != null &&
        _selectionEndCharIndex != null) {
      _selectionToolbarPosition = globalToolbarOffset;
      notifyListeners();
    }
  }

  /// Clears the selection active state.
  void clearSelection() {
    _clearSelectionSilent();
    notifyListeners();
  }

  void _clearSelectionSilent() {
    _selectingPageIndex = null;
    _selectionStartCharIndex = null;
    _selectionEndCharIndex = null;
    _selectionToolbarPosition = null;
  }

  /// Computes merged highlighted rectangles for active selection.
  List<Rect> getSelectionRects(int pageIndex) {
    if (_selectingPageIndex != pageIndex ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return [];
    }

    final chars = _pageChars[pageIndex];
    if (chars == null || chars.isEmpty) return [];

    final start = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    final end = max(_selectionStartCharIndex!, _selectionEndCharIndex!);

    final List<CharInfo> selectedChars = chars.sublist(start, end + 1);
    return mergeCharacterBoxes(selectedChars);
  }

  /// Groups and merges consecutive characters on the same line into a unified bounding box.
  List<Rect> mergeCharacterBoxes(List<CharInfo> selectedChars) {
    if (selectedChars.isEmpty) return [];

    final List<Rect> mergedRects = [];
    Rect? currentRect;

    for (final char in selectedChars) {
      final charRect = Rect.fromLTRB(
        char.left,
        char.top, // Note: In PDF coordinates, top > bottom
        char.right,
        char.bottom,
      );

      if (currentRect == null) {
        currentRect = charRect;
      } else {
        // Determine if char is on a similar vertical line as currentRect
        // Height check overlaps
        // Wait, standard Rect coordinates are: Rect.fromLTRB(left, top, right, bottom)
        // For PDF: Y increases upward. So top is larger than bottom.
        // Let's check standard overlap: if character's vertical bounds overlap with currentRect's
        final double currentMinY = min(currentRect.top, currentRect.bottom);
        final double currentMaxY = max(currentRect.top, currentRect.bottom);
        final double charMinY = min(charRect.top, charRect.bottom);
        final double charMaxY = max(charRect.top, charRect.bottom);

        final double overlap = min(currentMaxY, charMaxY) - max(currentMinY, charMinY);
        final double minHeight = min(currentMaxY - currentMinY, charMaxY - charMinY);

        // If vertical overlap is significant (e.g. > 50% of the character height),
        // and they are close horizontally, we merge them.
        final bool sameLine = overlap > (minHeight * 0.5);

        if (sameLine) {
          // Merge horizontal bounds and vertical bounds
          currentRect = Rect.fromLTRB(
            min(currentRect.left, charRect.left),
            max(currentRect.top, charRect.top),
            max(currentRect.right, charRect.right),
            min(currentRect.bottom, charRect.bottom),
          );
        } else {
          // Push old rect, start new one
          mergedRects.add(currentRect);
          currentRect = charRect;
        }
      }
    }

    if (currentRect != null) {
      mergedRects.add(currentRect);
    }

    return mergedRects;
  }

  /// Retrieves the selected text as a string.
  String getSelectedText() {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return '';
    }

    final chars = _pageChars[_selectingPageIndex!];
    if (chars == null || chars.isEmpty) return '';

    final start = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    final end = max(_selectionStartCharIndex!, _selectionEndCharIndex!);

    final buffer = StringBuffer();
    for (int i = start; i <= end; i++) {
      buffer.write(chars[i].text);
    }
    return buffer.toString();
  }
}

/// Viewport state for persistence.
class ViewportState {
  final double zoom;
  final double panOffsetX;
  final double panOffsetY;

  const ViewportState({
    required this.zoom,
    required this.panOffsetX,
    required this.panOffsetY,
  });

  factory ViewportState.fromJson(Map<String, dynamic> json) {
    return ViewportState(
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      panOffsetX: (json['panOffsetX'] as num?)?.toDouble() ?? 0.0,
      panOffsetY: (json['panOffsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'zoom': zoom,
        'panOffsetX': panOffsetX,
        'panOffsetY': panOffsetY,
      };
}
