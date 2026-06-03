import 'dart:math';
import 'package:flutter/material.dart';
import '../rust/api/pdf.dart' show CharInfo;

// Re-export CharInfo for convenience
export '../rust/api/pdf.dart' show CharInfo;

// Note: PdfHighlight is now in pdf_highlight.dart

/// Manages text selection state for a PDF page.
///
/// Responsibilities:
/// - Track selection start/end positions
/// - Find closest character to touch point
/// - Compute selection bounding boxes
/// - Manage toolbar position
///
/// This is a deep module: callers use startSelection/updateSelection/endSelection
/// without needing to understand character indexing or box merging.
class TextSelectionModel extends ChangeNotifier {
  // ── Selection State ──

  int? _selectingPageIndex;
  int? get selectingPageIndex => _selectingPageIndex;

  int? _selectionStartCharIndex;
  int? get selectionStartCharIndex => _selectionStartCharIndex;

  int? _selectionEndCharIndex;
  int? get selectionEndCharIndex => _selectionEndCharIndex;

  Offset? _selectionToolbarPosition;
  Offset? get selectionToolbarPosition => _selectionToolbarPosition;

  // ── Handle Dragging State ──
  // When dragging handles, toolbar should be hidden

  bool _isDraggingHandle = false;
  bool get isDraggingHandle => _isDraggingHandle;

  /// Start dragging a selection handle (toolbar will hide).
  void startHandleDrag() {
    _isDraggingHandle = true;
    _selectionToolbarPosition = null;
    notifyListeners();
  }

  /// End dragging a selection handle (toolbar will reappear).
  void endHandleDrag(Offset toolbarPosition) {
    _isDraggingHandle = false;
    _selectionToolbarPosition = toolbarPosition;
    notifyListeners();
  }

  // ── Character Cache Reference ──
  // Set by parent before selection operations

  /// Expose page chars cache for getSelectionRects (unused, kept for future use).
  // ignore: unused_field
  Map<int, List<CharInfo>>? _pageCharsCache;

  /// Set the page characters cache (called by PdfViewportController).
  void setPageCharsCache(Map<int, List<CharInfo>> cache) {
    _pageCharsCache = cache;
  }

  // ── Public Interface ──

  /// Begins a new text selection on a long press or drag starting point.
  Future<void> startSelection(
    int pageIndex,
    Offset pdfPoint,
    Future<List<CharInfo>> Function(int) getPageChars,
  ) async {
    final chars = await getPageChars(pageIndex);
    final idx = findClosestChar(chars, pdfPoint);
    if (idx != -1) {
      _selectingPageIndex = pageIndex;
      _selectionStartCharIndex = idx;
      _selectionEndCharIndex = idx;
      _selectionToolbarPosition = null;
      notifyListeners();
    }
  }

  /// Updates the selection end point during drag selection.
  Future<void> updateSelection(
    Offset pdfPoint,
    Future<List<CharInfo>> Function(int) getPageChars,
  ) async {
    if (_selectingPageIndex == null || _selectionStartCharIndex == null) return;
    final chars = await getPageChars(_selectingPageIndex!);
    final idx = findClosestChar(chars, pdfPoint);
    if (idx != -1 && idx != _selectionEndCharIndex) {
      _selectionEndCharIndex = idx;
      notifyListeners();
    }
  }

  /// Updates the selection start index directly (used by interactive handles).
  void updateSelectionStart(int index) {
    if (_selectingPageIndex != null && _selectionStartCharIndex != index) {
      _selectionStartCharIndex = index;
      notifyListeners();
    }
  }

  /// Updates the selection end index directly (used by interactive handles).
  void updateSelectionEnd(int index) {
    if (_selectingPageIndex != null && _selectionEndCharIndex != index) {
      _selectionEndCharIndex = index;
      notifyListeners();
    }
  }

  /// Concludes the selection drag and positions the floating toolbar.
  void endSelection(Offset globalToolbarOffset) {
    if (_selectingPageIndex != null &&
        _selectionStartCharIndex != null &&
        _selectionEndCharIndex != null) {
      _selectionToolbarPosition = globalToolbarOffset;
      _isDraggingHandle = false;
      notifyListeners();
    }
  }

  /// Clears the selection active state.
  void clearSelection() {
    _selectingPageIndex = null;
    _selectionStartCharIndex = null;
    _selectionEndCharIndex = null;
    _selectionToolbarPosition = null;
    _isDraggingHandle = false;
    notifyListeners();
  }

  /// Computes merged highlighted rectangles for active selection.
  List<Rect> getSelectionRects(int pageIndex, List<CharInfo> chars) {
    if (_selectingPageIndex != pageIndex ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return [];
    }

    if (chars.isEmpty) return [];

    final start = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    final end = max(_selectionStartCharIndex!, _selectionEndCharIndex!);

    final List<CharInfo> selectedChars = chars.sublist(start, end + 1);
    return mergeCharacterBoxes(selectedChars);
  }

  /// Retrieves the selected text as a string.
  String getSelectedText(List<CharInfo> chars) {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return '';
    }

    if (chars.isEmpty) return '';

    final start = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    final end = max(_selectionStartCharIndex!, _selectionEndCharIndex!);

    final buffer = StringBuffer();
    for (int i = start; i <= end && i < chars.length; i++) {
      buffer.write(chars[i].text);
    }
    return buffer.toString();
  }

  // ── Handle Position Helpers ──

  /// Get the position of the start handle (left/top of selection) in PDF coordinates.
  /// Returns null if no active selection.
  Offset? getStartHandlePdfPosition(List<CharInfo> chars) {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return null;
    }

    if (chars.isEmpty) return null;

    final startIdx = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    if (startIdx >= chars.length) return null;
    final startChar = chars[startIdx];

    // Start handle at left-bottom of first character
    return Offset(startChar.left, startChar.bottom);
  }

  /// Get the position of the end handle (right/bottom of selection) in PDF coordinates.
  /// Returns null if no active selection.
  Offset? getEndHandlePdfPosition(List<CharInfo> chars) {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return null;
    }

    if (chars.isEmpty) return null;

    final endIdx = max(_selectionStartCharIndex!, _selectionEndCharIndex!);
    if (endIdx >= chars.length) return null;
    final endChar = chars[endIdx];

    // End handle at right-bottom of last character
    return Offset(endChar.right, endChar.bottom);
  }

  /// Get the line height for the start handle (height of first selected character).
  double getStartHandleLineHeight(List<CharInfo> chars) {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return 20.0; // Default
    }

    if (chars.isEmpty) return 20.0;

    final startIdx = min(_selectionStartCharIndex!, _selectionEndCharIndex!);
    if (startIdx >= chars.length) return 20.0;
    final startChar = chars[startIdx];
    return startChar.top - startChar.bottom;
  }

  /// Get the line height for the end handle (height of last selected character).
  double getEndHandleLineHeight(List<CharInfo> chars) {
    if (_selectingPageIndex == null ||
        _selectionStartCharIndex == null ||
        _selectionEndCharIndex == null) {
      return 20.0; // Default
    }

    if (chars.isEmpty) return 20.0;

    final endIdx = max(_selectionStartCharIndex!, _selectionEndCharIndex!);
    if (endIdx >= chars.length) return 20.0;
    final endChar = chars[endIdx];
    return endChar.top - endChar.bottom;
  }

  /// Calculate selection bounds for toolbar positioning.
  /// Returns (centerX, topY, bottomY) in screen coordinates.
  (double, double, double) calculateSelectionBounds(
    List<Rect> selectionRects,
    double zoom,
    Offset panOffset,
  ) {
    if (selectionRects.isEmpty) return (0, 0, 0);

    // Find the top-most and bottom-most rects
    final topRect = selectionRects.reduce((a, b) => a.top < b.top ? a : b);
    final bottomRect = selectionRects.reduce((a, b) => a.bottom > b.bottom ? a : b);

    // Center horizontally
    final centerX = (topRect.left + topRect.right) / 2;

    // Convert to screen coordinates
    final screenCenterX = centerX * zoom + panOffset.dx;
    final screenTopY = topRect.top * zoom + panOffset.dy;
    final screenBottomY = bottomRect.bottom * zoom + panOffset.dy;

    return (screenCenterX, screenTopY, screenBottomY);
  }

  // ── Internal Helpers ──

  /// Finds the character closest to the touch coordinate (in PDF point space).
  /// Penalizes vertical distance to ensure alignment with lines.
  int findClosestChar(List<CharInfo> chars, Offset pdfPoint) {
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
}