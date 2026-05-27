import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:starmind/src/rust/api/pdf.dart';
import 'package:starmind/src/domain/annotation.dart';

/// Handles text selection gestures on PDF pages.
///
/// Implements the "long press + drag" selection interaction:
/// 1. Long press enters selection mode
/// 2. Drag handles adjust selection range
/// 3. Release shows annotation toolbar
class TextSelectionHandler {
  final List<CharInfo> chars;
  final double pageHeight;
  final double zoom;
  final Offset scrollOffset;
  final void Function(TextSelectionResult)? onSelectionComplete;

  TextSelectionHandler({
    required this.chars,
    required this.pageHeight,
    required this.zoom,
    required this.scrollOffset,
    this.onSelectionComplete,
  });

  /// Current selection state.
  int? _startCharIndex;
  int? _endCharIndex;
  bool _isSelecting = false;
  bool _isStartHandleDragging = false;
  bool _isEndHandleDragging = false;

  /// Whether currently in selection mode.
  bool get isSelecting => _isSelecting;

  /// Current selection (null if not selecting).
  TextSelectionResult? get currentSelection {
    if (_startCharIndex == null || _endCharIndex == null) return null;

    final start = min(_startCharIndex!, _endCharIndex!);
    final end = max(_startCharIndex!, _endCharIndex!);

    final selectedChars = chars.where((c) => c.index >= start && c.index <= end).toList();
    if (selectedChars.isEmpty) return null;

    final selectedText = selectedChars.map((c) => c.text).join();
    final rects = _calculateSelectionRects(selectedChars);

    return TextSelectionResult(
      startCharIndex: start,
      endCharIndex: end,
      selectedText: selectedText,
      rects: rects,
    );
  }

  /// Convert PDF coordinates to screen coordinates.
  ///
  /// PDF coordinate system: origin at bottom-left, Y increases upward.
  /// Screen coordinate system: origin at top-left, Y increases downward.
  ///
  /// The Y-axis flip is handled by: screenY = (pageHeight - pdfY) * zoom
  /// - pdfY=0 (bottom of page) -> screenY = pageHeight * zoom (bottom of screen)
  /// - pdfY=pageHeight (top of page) -> screenY = 0 (top of screen)
  Offset pdfToScreen(double pdfX, double pdfY) {
    // PDF Y is from bottom, screen Y is from top
    final screenX = pdfX * zoom - scrollOffset.dx;
    final screenY = (pageHeight - pdfY) * zoom - scrollOffset.dy;
    return Offset(screenX, screenY);
  }

  /// Convert screen coordinates to PDF coordinates.
  ///
  /// Inverse of [pdfToScreen]. Reverses the Y-axis flip:
  /// pdfY = pageHeight - (screenY + scrollOffset.dy) / zoom
  Offset screenToPdf(double screenX, double screenY) {
    final pdfX = (screenX + scrollOffset.dx) / zoom;
    final pdfY = pageHeight - (screenY + scrollOffset.dy) / zoom;
    return Offset(pdfX, pdfY);
  }

  /// Find the character nearest to a screen position.
  int? findCharAtPosition(Offset screenPosition) {
    final pdfPos = screenToPdf(screenPosition.dx, screenPosition.dy);

    // Find closest character by distance to center
    double minDistance = double.infinity;
    int? closestIndex;

    for (final char in chars) {
      final centerX = (char.left + char.right) / 2;
      final centerY = (char.top + char.bottom) / 2;

      final distance = sqrt(
        pow(pdfPos.dx - centerX, 2) + pow(pdfPos.dy - centerY, 2),
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = char.index;
      }
    }

    return closestIndex;
  }

  /// Handle long press start - enter selection mode.
  void onLongPressStart(Offset touchPosition) {
    final charIndex = findCharAtPosition(touchPosition);
    if (charIndex == null) return;

    _startCharIndex = charIndex;
    _endCharIndex = charIndex;
    _isSelecting = true;
    _isStartHandleDragging = false;
    _isEndHandleDragging = false;
  }

  /// Handle long press move - extend selection.
  void onLongPressMove(Offset touchPosition) {
    if (!_isSelecting) return;

    final charIndex = findCharAtPosition(touchPosition);
    if (charIndex == null) return;

    _endCharIndex = charIndex;
  }

  /// Handle long press end - show toolbar.
  void onLongPressEnd() {
    if (!_isSelecting) return;

    final selection = currentSelection;
    if (selection != null && onSelectionComplete != null) {
      onSelectionComplete!(selection);
    }
  }

  /// Handle start handle drag.
  void onStartHandleDrag(Offset newPosition) {
    if (!_isSelecting) return;

    _isStartHandleDragging = true;
    final charIndex = findCharAtPosition(newPosition);
    if (charIndex != null) {
      _startCharIndex = charIndex;
    }
  }

  /// Handle end handle drag.
  void onEndHandleDrag(Offset newPosition) {
    if (!_isSelecting) return;

    _isEndHandleDragging = true;
    final charIndex = findCharAtPosition(newPosition);
    if (charIndex != null) {
      _endCharIndex = charIndex;
    }
  }

  /// Exit selection mode.
  void cancelSelection() {
    _startCharIndex = null;
    _endCharIndex = null;
    _isSelecting = false;
    _isStartHandleDragging = false;
    _isEndHandleDragging = false;
  }

  /// Calculate selection rectangles from character info.
  List<AnnotationRect> _calculateSelectionRects(List<CharInfo> selectedChars) {
    if (selectedChars.isEmpty) return [];

    // Group characters by line (based on similar top/bottom values)
    final lines = <List<CharInfo>>[];
    var currentLine = <CharInfo>[];
    double? lastTop;

    for (final char in selectedChars) {
      if (lastTop == null || (char.top - lastTop).abs() > 5) {
        // New line
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = [char];
        lastTop = char.top;
      } else {
        currentLine.add(char);
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    // Create rects for each line
    return lines.map((line) {
      final left = line.map((c) => c.left).reduce(min);
      final right = line.map((c) => c.right).reduce(max);
      final top = line.map((c) => c.top).reduce(min);
      final bottom = line.map((c) => c.bottom).reduce(max);

      return AnnotationRect(
        left: left,
        top: pageHeight - bottom,  // Convert to screen coordinate system
        right: right,
        bottom: pageHeight - top,
      );
    }).toList();
  }

  /// Get screen position for start handle.
  Offset? getStartHandlePosition() {
    if (_startCharIndex == null) return null;

    final startChar = chars.firstWhere(
      (c) => c.index == min(_startCharIndex!, _endCharIndex!),
      orElse: () => chars.first,
    );

    return pdfToScreen(startChar.left, startChar.bottom);
  }

  /// Get screen position for end handle.
  Offset? getEndHandlePosition() {
    if (_endCharIndex == null) return null;

    final endChar = chars.firstWhere(
      (c) => c.index == max(_startCharIndex!, _endCharIndex!),
      orElse: () => chars.last,
    );

    return pdfToScreen(endChar.right, endChar.bottom);
  }
}

/// Result of text selection.
class TextSelectionResult {
  final int startCharIndex;
  final int endCharIndex;
  final String selectedText;
  final List<AnnotationRect> rects;

  const TextSelectionResult({
    required this.startCharIndex,
    required this.endCharIndex,
    required this.selectedText,
    required this.rects,
  });
}