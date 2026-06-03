import 'package:flutter/material.dart';
import 'text_selection_overlay.dart';
import 'selection_handles_overlay.dart';
import '../pdf_viewport_controller.dart';
import '../pdf_coordinates.dart';
import '../annotation_controller.dart';
import '../selection_overlay_geometry.dart';
import '../../domain/annotation.dart';
import '../text_selection_model.dart'; // re-exports CharInfo

/// A widget that listens to TextSelectionModel and rebuilds selection UI accordingly.
///
/// This widget independently listens to selection changes and triggers local rebuilds,
/// avoiding the need for parent widget rebuilds. This improves performance and
/// ensures selection handles/toolbar update immediately when selection changes.
class SelectionUiListener extends StatefulWidget {
  final PdfViewportController controller;
  final double baseScale;
  final AnnotationController? annotationController;
  final VoidCallback? onHighlightCreated;
  final VoidCallback? onUnderlineCreated;

  const SelectionUiListener({
    super.key,
    required this.controller,
    required this.baseScale,
    this.annotationController,
    this.onHighlightCreated,
    this.onUnderlineCreated,
  });

  @override
  State<SelectionUiListener> createState() => _SelectionUiListenerState();
}

class _SelectionUiListenerState extends State<SelectionUiListener> {
  @override
  void initState() {
    super.initState();
    widget.controller.selection.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(SelectionUiListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.selection != widget.controller.selection) {
      oldWidget.controller.selection.removeListener(_onSelectionChanged);
      widget.controller.selection.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    // Trigger local rebuild when selection changes
    debugPrint('SelectionUiListener: _onSelectionChanged triggered');
    debugPrint('  - selectingPageIndex: ${widget.controller.selection.selectingPageIndex}');
    debugPrint('  - selectionStartCharIndex: ${widget.controller.selection.selectionStartCharIndex}');
    debugPrint('  - selectionEndCharIndex: ${widget.controller.selection.selectionEndCharIndex}');
    debugPrint('  - selectionToolbarPosition: ${widget.controller.selection.selectionToolbarPosition}');
    debugPrint('  - isDraggingHandle: ${widget.controller.selection.isDraggingHandle}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    final pageIndex = selection.selectingPageIndex;

    // No selection active
    if (pageIndex == null) {
      return const SizedBox.shrink();
    }

    final pdfSize = widget.controller.pageSizes[pageIndex];
    if (pdfSize == null) {
      return const SizedBox.shrink();
    }

    final scale = widget.baseScale * widget.controller.transform.zoom;
    final panOffset = widget.controller.transform.panOffset;
    final coords = PdfCoordinates(pdfWidth: pdfSize.width, pdfHeight: pdfSize.height);
    final List<CharInfo> chars = widget.controller.session.getCachedPageChars(pageIndex);
    debugPrint('SelectionUiListener: build called, chars.length = ${chars.length}');

    // Get selection rects
    final selectionRects = selection.getSelectionRects(pageIndex, chars);
    debugPrint('SelectionUiListener: selectionRects.length = ${selectionRects.length}');
    if (selectionRects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Selection Handles (if not dragging)
        if (!selection.isDraggingHandle)
          _buildSelectionHandles(pageIndex, pdfSize, scale, panOffset, coords, chars),

        // Floating Toolbar (if not dragging and has position)
        if (!selection.isDraggingHandle && selection.selectionToolbarPosition != null)
          _buildToolbar(pageIndex, pdfSize, scale, panOffset, coords, selectionRects),
      ],
    );
  }

  Widget _buildSelectionHandles(
    int pageIndex,
    Size pdfSize,
    double scale,
    Offset panOffset,
    PdfCoordinates coords,
    List<CharInfo> chars,
  ) {
    final selection = widget.controller.selection;

    final startPdfPos = selection.getStartHandlePdfPosition(chars);
    final endPdfPos = selection.getEndHandlePdfPosition(chars);
    final startLineHeight = selection.getStartHandleLineHeight(chars);
    final endLineHeight = selection.getEndHandleLineHeight(chars);

    debugPrint('SelectionUiListener: startPdfPos = $startPdfPos, endPdfPos = $endPdfPos');

    if (startPdfPos == null || endPdfPos == null) {
      debugPrint('SelectionUiListener: skipping handles due to null positions');
      return const SizedBox.shrink();
    }

    // Use geometry helper for coordinate transformation
    final startScreenPos = SelectionOverlayGeometry.pdfPointToScreen(
      pdfPoint: startPdfPos,
      pageIndex: pageIndex,
      pdfPageHeight: pdfSize.height,
      baseScale: widget.baseScale,
      zoom: widget.controller.transform.zoom,
      panOffset: panOffset,
      pageVerticalMargin: 8.0,
    );

    final endScreenPos = SelectionOverlayGeometry.pdfPointToScreen(
      pdfPoint: endPdfPos,
      pageIndex: pageIndex,
      pdfPageHeight: pdfSize.height,
      baseScale: widget.baseScale,
      zoom: widget.controller.transform.zoom,
      panOffset: panOffset,
      pageVerticalMargin: 8.0,
    );

    return SelectionHandlesOverlay(
      startHandlePosition: startScreenPos,
      startLineHeight: startLineHeight * scale,
      endHandlePosition: endScreenPos,
      endLineHeight: endLineHeight * scale,
      zoom: widget.controller.transform.zoom,
      onHandleDrag: (handleType, newPosition) {
        widget.controller.selection.startHandleDrag();
        final pdfPos = coords.screenToPdf(newPosition, scale, panOffset);
        final chars = widget.controller.session.getCachedPageChars(pageIndex);
        if (chars.isNotEmpty) {
          final charIndex = widget.controller.selection.findClosestChar(chars, pdfPos);
          if (charIndex != -1) {
            if (handleType == SelectionHandleType.start) {
              widget.controller.selection.updateSelectionStart(charIndex);
            } else {
              widget.controller.selection.updateSelectionEnd(charIndex);
            }
          }
        }
      },
      onDragEnd: () {
        final selectionRects = widget.controller.selection.getSelectionRects(
          pageIndex,
          widget.controller.session.getCachedPageChars(pageIndex),
        );
        if (selectionRects.isNotEmpty) {
          final (centerX, topY, _) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
            pdfRects: selectionRects,
            pageIndex: pageIndex,
            pdfPageHeight: pdfSize.height,
            baseScale: widget.baseScale,
            zoom: widget.controller.transform.zoom,
            panOffset: panOffset,
            pageVerticalMargin: 8.0,
          );
          final toolbarPos = Offset(centerX, topY - 48);
          widget.controller.selection.endHandleDrag(toolbarPos);
        }
      },
    );
  }

  Widget _buildToolbar(
    int pageIndex,
    Size pdfSize,
    double scale,
    Offset panOffset,
    PdfCoordinates coords,
    List<Rect> selectionRects,
  ) {
    final mediaQuery = MediaQuery.of(context);

    // Use geometry helper for coordinate transformation
    final (centerX, topY, bottomY) = SelectionOverlayGeometry.pdfRectsToScreenBounds(
      pdfRects: selectionRects,
      pageIndex: pageIndex,
      pdfPageHeight: pdfSize.height,
      baseScale: widget.baseScale,
      zoom: widget.controller.transform.zoom,
      panOffset: panOffset,
      pageVerticalMargin: 8.0,
    );

    return PdfSelectionToolbar(
      selectionCenter: Offset(centerX, (topY + bottomY) / 2),
      selectionTop: topY,
      selectionBottom: bottomY,
      screenWidth: mediaQuery.size.width,
      screenHeight: mediaQuery.size.height,
      onDismiss: () => widget.controller.selection.clearSelection(),
      onHighlight: widget.annotationController != null ? (color) => _createHighlight(color) : (_) {},
      onUnderline: widget.annotationController != null ? (color) => _createUnderline(color) : (_) {},
    );
  }

  Future<void> _createHighlight(Color color) async {
    if (widget.annotationController == null) return;

    final selection = widget.controller.selection;
    final pageIndex = selection.selectingPageIndex;
    final startChar = selection.selectionStartCharIndex;
    final endChar = selection.selectionEndCharIndex;
    if (pageIndex == null || startChar == null || endChar == null) return;

    final chars = widget.controller.session.getCachedPageChars(pageIndex);
    final selectedText = selection.getSelectedText(chars);
    final rects = selection.getSelectionRects(pageIndex, chars);

    await widget.annotationController!.createHighlight(
      pageIndex: pageIndex,
      startCharIndex: startChar,
      endCharIndex: endChar,
      selectedText: selectedText,
      rects: rects.map((r) => AnnotationRect(
        left: r.left,
        top: r.top,
        right: r.right,
        bottom: r.bottom,
      )).toList(),
      colorHex: _colorToHex(color),
    );

    selection.clearSelection();
    widget.onHighlightCreated?.call();
  }

  Future<void> _createUnderline(Color color) async {
    if (widget.annotationController == null) return;

    final selection = widget.controller.selection;
    final pageIndex = selection.selectingPageIndex;
    final startChar = selection.selectionStartCharIndex;
    final endChar = selection.selectionEndCharIndex;
    if (pageIndex == null || startChar == null || endChar == null) return;

    final chars = widget.controller.session.getCachedPageChars(pageIndex);
    final selectedText = selection.getSelectedText(chars);
    final rects = selection.getSelectionRects(pageIndex, chars);

    await widget.annotationController!.createUnderline(
      pageIndex: pageIndex,
      startCharIndex: startChar,
      endCharIndex: endChar,
      selectedText: selectedText,
      rects: rects.map((r) => AnnotationRect(
        left: r.left,
        top: r.top,
        right: r.right,
        bottom: r.bottom,
      )).toList(),
      colorHex: _colorToHex(color),
    );

    selection.clearSelection();
    widget.onUnderlineCreated?.call();
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }
}
