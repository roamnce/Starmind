/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quad, Matrix4;
import '../pdf_service.dart';
import '../pdf_viewport_controller.dart';
import '../viewport_transform.dart';
import '../pdf_coordinates.dart';
import '../viewport_repaint_notifier.dart';
import '../pdf_highlight.dart';
import '../annotation_controller.dart';
import '../render_scheduler.dart';
import '../../domain/annotation.dart';
import 'interactive_canvas_viewer.dart';
import 'text_selection_overlay.dart';
import 'selection_handles_overlay.dart';

double _getMatrixScale2D(Matrix4 matrix) {
  final double m00 = matrix.entry(0, 0);
  final double m10 = matrix.entry(1, 0);
  final double m20 = matrix.entry(2, 0);
  return sqrt(m00 * m00 + m10 * m10 + m20 * m20);
}

/// PDF viewport widget with pinch-to-zoom and pan support.
///
/// Uses InteractiveCanvasViewer (adapted from Saber) for gesture handling:
/// - Double-finger pinch: zoom (0.5x ~ 5.0x)
/// - Double-finger drag: pan
/// - Single-finger: scroll/selection (depending on mode)
/// - Mouse wheel: scroll (Ctrl+wheel: zoom)
class PdfViewportWidget extends StatefulWidget {
  final PdfViewportController controller;
  final bool freePanEnabled;
  final AnnotationController? annotationController;
  final bool isInkMode;

  const PdfViewportWidget({
    super.key,
    required this.controller,
    this.freePanEnabled = false,
    this.annotationController,
    this.isInkMode = false,
  });

  @override
  State<PdfViewportWidget> createState() => _PdfViewportWidgetState();
}

class _PdfViewportWidgetState extends State<PdfViewportWidget> {
  final GlobalKey _viewportKey = GlobalKey();
  late final TransformationController _transformationController;
  late final ViewportRepaintNotifier _repaintNotifier;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _repaintNotifier = ViewportRepaintNotifier();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounceTimer?.cancel();
    _transformationController.dispose();
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Use ViewportRepaintNotifier to trigger repaint instead of setState
    _repaintNotifier.updateViewport(
      widget.controller.transform.panOffset,
      widget.controller.transform.zoom,
    );
    _startDebounceTimer();
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), () {
      // Notify pages to refresh high-res tiles
      if (mounted) setState(() {});
    });
  }

  /// Check if current gesture is a draw gesture (single finger/stylus in ink mode).
  bool _isDrawGesture(ScaleStartDetails details) {
    // This is a simplified check - in real use, check if in ink mode
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.controller.pageCount;
    final isLoading = widget.controller.isLoading;

    if (isLoading) {
      return _buildLoadingIndicator();
    }

    if (pageCount == 0) {
      return const Center(child: Text('No pages'));
    }

    // Get first page size for sizing
    final pdfSize = widget.controller.pageSizes[0];
    if (pdfSize == null) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Calculate initial scale to fit width
    final viewportSize = MediaQuery.of(context).size;
    final baseScale = viewportSize.width / pdfSize.width;

    return Stack(
      children: [
        InteractiveCanvasViewer.builder(
          minScale: ViewportTransform.minZoom,
          maxScale: ViewportTransform.maxZoom,
          panEnabled: true,
          scaleEnabled: true,
          transformationController: _transformationController,
          // 无边界限制，允许用户将 PDF 拖动到任意位置
          boundaryMargin: EdgeInsets.all(double.infinity),
          isDrawGesture: _isDrawGesture,
          onInteractionEnd: (details) {
            // Sync controller state
            final scale = _getMatrixScale2D(_transformationController.value);
            final translation = _transformationController.value.getTranslation();
            widget.controller.transform.setViewportState(
              zoom: scale,
              panOffset: Offset(translation.x, translation.y),
            );
          },
          builder: (BuildContext context, Quad viewport) {
            return _PdfPagesContainer(
              controller: widget.controller,
              viewport: viewport,
              viewportKey: _viewportKey,
              baseScale: baseScale,
              transformationController: _transformationController,
              isInkMode: widget.isInkMode,
            );
          },
        ),
        // Selection Handles Overlay
        if (widget.controller.selection.selectingPageIndex != null &&
            !widget.controller.selection.isDraggingHandle)
          ..._buildSelectionHandles(baseScale),
        // Floating Toolbar (hidden when dragging handles)
        if (widget.controller.selection.selectingPageIndex != null &&
            widget.controller.selection.selectionToolbarPosition != null &&
            !widget.controller.selection.isDraggingHandle)
          PdfSelectionToolbar(
            position: widget.controller.selection.selectionToolbarPosition!,
            onDismiss: () => widget.controller.selection.clearSelection(),
            onHighlight: (color) => _createHighlight(color),
            onUnderline: (color) => _createUnderline(color),
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    final loadingStep = widget.controller.loadingStep;
    final loadingError = widget.controller.loadingError;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFFC800)),
          const SizedBox(height: 16),
          if (loadingError != null)
            Text(
              loadingError,
              style: const TextStyle(color: Colors.red),
            )
          else if (loadingStep.isNotEmpty)
            Text(loadingStep),
        ],
      ),
    );
  }

  /// Build selection handles for the current selection.
  List<Widget> _buildSelectionHandles(double baseScale) {
    final pageIndex = widget.controller.selection.selectingPageIndex;
    if (pageIndex == null) return [];

    final pdfSize = widget.controller.pageSizes[pageIndex];
    if (pdfSize == null) return [];

    final scale = baseScale * widget.controller.transform.zoom;

    // Get handle positions in PDF coordinates
    final startPdfPos = widget.controller.selection.getStartHandlePdfPosition(
      widget.controller.session.getCachedPageChars(pageIndex),
    );
    final endPdfPos = widget.controller.selection.getEndHandlePdfPosition(
      widget.controller.session.getCachedPageChars(pageIndex),
    );
    final startLineHeight = widget.controller.selection.getStartHandleLineHeight(
      widget.controller.session.getCachedPageChars(pageIndex),
    );
    final endLineHeight = widget.controller.selection.getEndHandleLineHeight(
      widget.controller.session.getCachedPageChars(pageIndex),
    );

    if (startPdfPos == null || endPdfPos == null) return [];

    // Convert to screen coordinates (with pan offset)
    final panOffset = widget.controller.transform.panOffset;

    Offset pdfToScreen(Offset pdfPos) {
      // PDF Y is from bottom, screen Y is from top
      final screenX = pdfPos.dx * scale + panOffset.dx;
      final screenY = (pdfSize.height - pdfPos.dy) * scale + panOffset.dy;
      return Offset(screenX, screenY);
    }

    return [
      SelectionHandlesOverlay(
        startHandlePosition: pdfToScreen(startPdfPos),
        startLineHeight: startLineHeight * scale,
        endHandlePosition: pdfToScreen(endPdfPos),
        endLineHeight: endLineHeight * scale,
        zoom: widget.controller.transform.zoom,
        onHandleDrag: (handleType, newPosition) {
          widget.controller.selection.startHandleDrag();
          // Convert screen position back to PDF and find char
          final coords = PdfCoordinates(pdfWidth: pdfSize.width, pdfHeight: pdfSize.height);
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
          // Recalculate toolbar position
          final selectionRects = widget.controller.selection.getSelectionRects(pageIndex, widget.controller.session.getCachedPageChars(pageIndex));
          if (selectionRects.isNotEmpty) {
            final toolbarPos = widget.controller.selection.calculateToolbarPosition(
              selectionRects,
              scale,
              panOffset,
            );
            widget.controller.selection.endHandleDrag(toolbarPos);
          }
        },
      ),
    ];
  }

  /// Create a highlight annotation.
  Future<void> _createHighlight(Color color) async {
    final annotationController = widget.annotationController;
    if (annotationController == null) return;

    final pageIndex = widget.controller.selection.selectingPageIndex;
    final startChar = widget.controller.selection.selectionStartCharIndex;
    final endChar = widget.controller.selection.selectionEndCharIndex;
    if (pageIndex == null || startChar == null || endChar == null) return;

    final selectedText = widget.controller.selection.getSelectedText(widget.controller.session.getCachedPageChars(pageIndex));
    final rects = widget.controller.selection.getSelectionRects(pageIndex, widget.controller.session.getCachedPageChars(pageIndex));

    await annotationController.createHighlight(
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

    widget.controller.selection.clearSelection();
  }

  /// Create an underline annotation.
  Future<void> _createUnderline(Color color) async {
    final annotationController = widget.annotationController;
    if (annotationController == null) return;

    final pageIndex = widget.controller.selection.selectingPageIndex;
    final startChar = widget.controller.selection.selectionStartCharIndex;
    final endChar = widget.controller.selection.selectionEndCharIndex;
    if (pageIndex == null || startChar == null || endChar == null) return;

    final selectedText = widget.controller.selection.getSelectedText(widget.controller.session.getCachedPageChars(pageIndex));
    final rects = widget.controller.selection.getSelectionRects(pageIndex, widget.controller.session.getCachedPageChars(pageIndex));

    await annotationController.createUnderline(
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

    widget.controller.selection.clearSelection();
  }

  /// Convert Color to hex string.
  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }
}

/// Container for all PDF pages with manual virtualization.
///
/// Uses transformation matrix to calculate visible page range,
/// only rendering pages within the viewport + buffer.
class _PdfPagesContainer extends StatefulWidget {
  final PdfViewportController controller;
  final Quad viewport;
  final GlobalKey viewportKey;
  final double baseScale;
  final TransformationController transformationController;
  final bool isInkMode;

  const _PdfPagesContainer({
    required this.controller,
    required this.viewport,
    required this.viewportKey,
    required this.baseScale,
    required this.transformationController,
    required this.isInkMode,
  });

  @override
  State<_PdfPagesContainer> createState() => _PdfPagesContainerState();
}

class _PdfPagesContainerState extends State<_PdfPagesContainer> {
  // Track rendered page range to avoid unnecessary rebuilds
  int _firstRenderedPage = 0;
  int _lastRenderedPage = 0;

  // Buffer pages before/after visible area
  static const int _pageBuffer = 2;

  // Debounce transform changes
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.transformationController.removeListener(_onTransformChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(_PdfPagesContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController.removeListener(_onTransformChanged);
      widget.transformationController.addListener(_onTransformChanged);
    }
  }

  void _onTransformChanged() {
    // Debounce: only recalculate after 100ms of no changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      final pageCount = widget.controller.pageCount;
      final pdfSize = widget.controller.pageSizes[0];
      if (pdfSize == null) return;

      final pageHeight = pdfSize.height * widget.baseScale + PdfPageWidget.pageVerticalMargin * 2;
      final newRange = _calculateVisiblePageRange(pageHeight, pageCount);

      // Only rebuild if range actually changed
      if (newRange.$1 != _firstRenderedPage || newRange.$2 != _lastRenderedPage) {
        setState(() {
          _firstRenderedPage = newRange.$1;
          _lastRenderedPage = newRange.$2;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.controller.pageCount;
    final pdfSize = widget.controller.pageSizes[0];
    if (pdfSize == null) return const SizedBox.shrink();

    final viewportWidth = pdfSize.width * widget.baseScale;
    final pageHeight = pdfSize.height * widget.baseScale + PdfPageWidget.pageVerticalMargin * 2;

    // Calculate initial visible page range if not set
    if (_firstRenderedPage == 0 && _lastRenderedPage == 0) {
      final initialRange = _calculateVisiblePageRange(pageHeight, pageCount);
      _firstRenderedPage = initialRange.$1;
      _lastRenderedPage = initialRange.$2;
    }

    // Build only visible pages with spacing placeholders
    final children = <Widget>[];

    // Top placeholder for virtualized pages
    if (_firstRenderedPage > 0) {
      children.add(SizedBox(
        height: pageHeight * _firstRenderedPage,
        child: const SizedBox.shrink(),
      ));
    }

    // Visible pages - use stable keys to avoid rebuild
    for (int i = _firstRenderedPage; i <= _lastRenderedPage; i++) {
      children.add(PdfPageWidget(
        key: ValueKey('page-$i'),
        pageIndex: i,
        controller: widget.controller,
        viewport: widget.viewport,
        viewportWidth: viewportWidth,
        viewportKey: widget.viewportKey,
        transformationController: widget.transformationController,
        isInkMode: widget.isInkMode,
      ));
    }

    // Bottom placeholder for virtualized pages
    final remainingPages = pageCount - _lastRenderedPage - 1;
    if (remainingPages > 0) {
      children.add(SizedBox(
        height: pageHeight * remainingPages,
        child: const SizedBox.shrink(),
      ));
    }

    return Column(
      key: widget.viewportKey,
      children: children,
    );
  }

  /// Calculate which pages are currently visible in the viewport.
  (int, int) _calculateVisiblePageRange(double pageHeight, int pageCount) {
    final matrix = widget.transformationController.value;
    final scale = _getMatrixScale2D(matrix);
    final translation = matrix.getTranslation();

    // Viewport dimensions
    final viewportSize = MediaQuery.of(context).size;
    final viewportHeight = viewportSize.height;

    // Calculate visible Y range in Flutter coordinates (before transform)
    // The translation is negative when scrolling down
    final visibleTop = -translation.y / scale;
    final visibleBottom = (viewportHeight - translation.y) / scale;

    // Convert to page indices (each page has pageHeight + margin)
    final firstVisible = ((visibleTop / pageHeight).floor() - _pageBuffer).clamp(0, pageCount - 1);
    final lastVisible = ((visibleBottom / pageHeight).ceil() + _pageBuffer).clamp(0, pageCount - 1);

    return (firstVisible, lastVisible);
  }
}

/// Individual PDF page widget with tile rendering.
class PdfPageWidget extends StatefulWidget {
  static const double pageVerticalMargin = 8.0;

  final int pageIndex;
  final PdfViewportController controller;
  final GlobalKey? viewportKey;
  final double viewportWidth;
  final Quad? viewport;
  final TransformationController? transformationController;
  final bool isInkMode;

  const PdfPageWidget({
    super.key,
    required this.pageIndex,
    required this.controller,
    this.viewportKey,
    required this.viewportWidth,
    this.viewport,
    this.transformationController,
    this.isInkMode = false,
  });

  @override
  State<PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<PdfPageWidget> {
  Size? _pdfSize;
  ui.Image? _lowResImage;
  ui.Image? _highResTile;
  Rect? _highResRect;
  double? _highResZoom;
  Timer? _highResDebounceTimer;
  bool _isSelecting = false;
  bool _disposed = false;

  // Use singleton RenderScheduler
  static final RenderScheduler _renderScheduler = RenderScheduler();

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    _disposed = true;
    _highResDebounceTimer?.cancel();

    // Cancel any pending render tasks for this page
    _renderScheduler.cancelPage(widget.pageIndex);

    // Dispose images
    _lowResImage?.dispose();
    _lowResImage = null;
    _highResTile?.dispose();
    _highResTile = null;

    super.dispose();
  }

  @override
  void didUpdateWidget(PdfPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger high-res update when viewport changes
    if (oldWidget.viewport != widget.viewport) {
      _onViewportChanged();
    }
  }

  Future<void> _initPage() async {
    // Load page size immediately (fast, cached)
    final size = await widget.controller.session.getPageSize(widget.pageIndex);
    if (!mounted || _disposed) return;

    setState(() {
      _pdfSize = size;
    });

    // Start low-res render immediately
    _loadLowResImage();
  }

  // Called by parent when viewport changes (via didUpdateWidget)
  void _onViewportChanged() {
    _highResDebounceTimer?.cancel();
    _highResDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_disposed && mounted) {
        _loadHighResTile();
      }
    });
  }

  Future<void> _loadLowResImage() async {
    if (_pdfSize == null || _lowResImage != null || _disposed) return;

    try {
      final docId = widget.controller.docId;
      if (docId == null) return;

      final double pdfWidth = _pdfSize!.width;
      final double pdfHeight = _pdfSize!.height;

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetWidth = (600 * dpr).round();
      final targetHeight = (600 * dpr * (pdfHeight / pdfWidth)).round();

      final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);
      final fullPage = coords.fullPagePdfRect;

      // Use RenderScheduler with high priority (priority = 0 = highest)
      final img = await _renderScheduler.scheduleRender(
        pageIndex: widget.pageIndex,
        priority: widget.pageIndex.toDouble(), // Lower page index = higher priority
        render: () async {
          if (_disposed) return null;
          final bytes = await PdfService().renderViewport(
            docId: docId,
            pageIndex: widget.pageIndex,
            pdfLeft: fullPage.left,
            pdfTop: fullPage.top,
            pdfRight: fullPage.right,
            pdfBottom: fullPage.bottom,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
          );
          if (_disposed) return null;
          return await _bytesToImage(bytes, targetWidth, targetHeight);
        },
        onCancel: () {
          debugPrint('Low-res render cancelled for page ${widget.pageIndex}');
        },
      );

      if (_disposed || img == null) return;

      if (mounted && !_disposed) {
        setState(() {
          _lowResImage = img;
        });
      } else {
        img.dispose();
      }
    } catch (e) {
      debugPrint('Error loading low-res page ${widget.pageIndex}: $e');
    }
  }

  Future<void> _loadHighResTile() async {
    if (_pdfSize == null || widget.controller.docId == null || _disposed) return;

    final visibleRect = _getVisibleRect();
    if (visibleRect == null) {
      if (_highResTile != null && !_disposed) {
        setState(() {
          _highResTile?.dispose();
          _highResTile = null;
          _highResRect = null;
          _highResZoom = null;
        });
      }
      return;
    }

    final zoom = widget.transformationController != null
        ? _getMatrixScale2D(widget.transformationController!.value)
        : 1.0;

    final double pdfWidth = _pdfSize!.width;
    final double pdfHeight = _pdfSize!.height;
    final baseScale = widget.viewportWidth / pdfWidth;

    final double expandX = 100.0 / zoom;
    final double expandY = 150.0 / zoom;
    final expandedVisibleRect = Rect.fromLTRB(
      max(0.0, visibleRect.left - expandX),
      max(0.0, visibleRect.top - expandY),
      min(pdfWidth * baseScale, visibleRect.right + expandX),
      min(pdfHeight * baseScale, visibleRect.bottom + expandY),
    );

    if (_highResRect != null &&
        _highResTile != null &&
        _highResZoom != null &&
        (_highResZoom! - zoom).abs() < 0.01 &&
        _highResRect!.containsRect(visibleRect)) {
      return;
    }

    // Use RenderScheduler to limit concurrent renders
    final image = await _renderScheduler.scheduleRender(
      pageIndex: widget.pageIndex,
      priority: widget.pageIndex.toDouble() + 1000.0, // High-res has lower priority
      render: () async {
        final docId = widget.controller.docId!;

        final viewportBox = widget.viewportKey?.currentContext?.findRenderObject() as RenderBox?
            ?? (mounted ? context.findRenderObject() as RenderBox? : null);
        if (viewportBox == null || _disposed) return null;

        final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);
        final pdfRect = coords.flutterToPdf(expandedVisibleRect, baseScale);

        final dpr = mounted ? MediaQuery.of(context).devicePixelRatio : 2.0;

        // Scale down multiplier at high zoom factors to optimize performance
        double scaleMultiplier = 1.3;
        if (zoom > 10.0) {
          scaleMultiplier = 0.8;
        } else if (zoom > 5.0) {
          scaleMultiplier = 1.0;
        }

        final renderScale = zoom * dpr * scaleMultiplier;
        double targetWidthDouble = expandedVisibleRect.width * renderScale;
        double targetHeightDouble = expandedVisibleRect.height * renderScale;

        // Cap tile dimensions to a maximum of 2048px
        const double maxDimension = 2048.0;
        if (targetWidthDouble > maxDimension || targetHeightDouble > maxDimension) {
          final double ratio = maxDimension / max(targetWidthDouble, targetHeightDouble);
          targetWidthDouble *= ratio;
          targetHeightDouble *= ratio;
        }

        final targetWidth = targetWidthDouble.round();
        final targetHeight = targetHeightDouble.round();

        if (targetWidth <= 0 || targetHeight <= 0) return null;

        final bytes = await PdfService().renderViewport(
          docId: docId,
          pageIndex: widget.pageIndex,
          pdfLeft: pdfRect.left,
          pdfTop: pdfRect.top,
          pdfRight: pdfRect.right,
          pdfBottom: pdfRect.bottom,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );

        if (_disposed) return null;
        return await _bytesToImage(bytes, targetWidth, targetHeight);
      },
      onCancel: () {
        debugPrint('High-res render cancelled for page ${widget.pageIndex}');
      },
    );

    if (image == null || _disposed || !mounted) {
      if (image != null) image.dispose();
      return;
    }

    setState(() {
      _highResTile?.dispose();
      _highResTile = image;
      _highResRect = expandedVisibleRect;
      _highResZoom = zoom;
    });
  }

  Rect? _getVisibleRect() {
    if (!mounted || _pdfSize == null) return null;
    final pageBox = context.findRenderObject() as RenderBox?;
    final viewportBox = widget.viewportKey?.currentContext?.findRenderObject() as RenderBox?;
    if (pageBox == null || viewportBox == null || !pageBox.attached || !viewportBox.attached) {
      return null;
    }

    final viewportLocalToGlobal = viewportBox.localToGlobal(Offset.zero);
    final viewportRect = viewportLocalToGlobal & viewportBox.size;

    // Convert viewport global boundaries into page-local coordinate system (handles zoom/pan)
    final localTopLeft = pageBox.globalToLocal(viewportRect.topLeft);
    final localBottomRight = pageBox.globalToLocal(viewportRect.bottomRight);

    final left = localTopLeft.dx.clamp(0.0, pageBox.size.width);
    final top = localTopLeft.dy.clamp(0.0, pageBox.size.height);
    final right = localBottomRight.dx.clamp(0.0, pageBox.size.width);
    final bottom = localBottomRight.dy.clamp(0.0, pageBox.size.height);

    if (right <= left || bottom <= top) {
      return null;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<ui.Image> _bytesToImage(Uint8List bytes, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfSize == null) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final viewportWidth = widget.viewportWidth;
    final double pdfWidth = _pdfSize!.width;
    final double pdfHeight = _pdfSize!.height;
    final scale = viewportWidth / pdfWidth;

    final logicalWidth = pdfWidth * scale;
    final logicalHeight = pdfHeight * scale;

    final isSelectingThisPage = widget.controller.selection.selectingPageIndex == widget.pageIndex;
    final selectionRects = widget.controller.selection.getSelectionRects(widget.pageIndex, widget.controller.session.getCachedPageChars(widget.pageIndex));
    final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);

    return GestureDetector(
      onLongPressStart: (details) async {
        // Ink mode check - disable selection in ink mode
        if (widget.isInkMode) return;

        final pdfPoint = coords.flutterToPdfPoint(details.localPosition, scale);
        await widget.controller.selection.startSelection(widget.pageIndex, pdfPoint, widget.controller.session.getPageChars);
        setState(() {
          _isSelecting = true;
        });
      },
      onLongPressMoveUpdate: (details) async {
        if (_isSelecting && widget.controller.selection.selectingPageIndex == widget.pageIndex) {
          final pdfPoint = coords.flutterToPdfPoint(details.localPosition, scale);
          await widget.controller.selection.updateSelection(pdfPoint, widget.controller.session.getPageChars);
          setState(() {}); // Trigger repaint to show selection area
        }
      },
      onLongPressEnd: (details) {
        // Calculate toolbar position based on selection
        if (selectionRects.isNotEmpty) {
          final toolbarPos = widget.controller.selection.calculateToolbarPosition(
            selectionRects,
            scale,
            Offset.zero,
          );
          widget.controller.selection.endSelection(toolbarPos);
        }
        setState(() {
          _isSelecting = false;
        });
      },
      child: Stack(
        children: [
          // PDF Content Layer
          Container(
            width: logicalWidth,
            height: logicalHeight,
            margin: const EdgeInsets.symmetric(vertical: PdfPageWidget.pageVerticalMargin),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CustomPaint(
              painter: PdfPagePainter(
                lowResImage: _lowResImage,
                highResTile: _highResTile,
                highResRect: _highResRect,
                highlights: widget.controller.highlights.where((h) => h.pageIndex == widget.pageIndex).toList(),
                selectionRects: selectionRects,
                pdfWidth: pdfWidth,
                pdfHeight: pdfHeight,
                scale: scale,
                isSelecting: _isSelecting,
              ),
            ),
          ),
          // Selection Area Overlay (separate layer for performance)
          if (isSelectingThisPage && selectionRects.isNotEmpty)
            Positioned(
              top: PdfPageWidget.pageVerticalMargin,
              left: 0,
              right: 0,
              bottom: PdfPageWidget.pageVerticalMargin,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SelectionAreaPainter(
                    rects: selectionRects,
                    pdfWidth: pdfWidth,
                    pdfHeight: pdfHeight,
                    scale: scale,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension RectExtension on Rect {
  bool containsRect(Rect other) {
    return left <= other.left &&
        top <= other.top &&
        right >= other.right &&
        bottom >= other.bottom;
  }
}

class PdfPagePainter extends CustomPainter {
  final ui.Image? lowResImage;
  final ui.Image? highResTile;
  final Rect? highResRect;
  final List<PdfHighlight> highlights;
  final List<Rect> selectionRects;
  final double pdfWidth;
  final double pdfHeight;
  final double scale;
  final bool isSelecting;

  PdfPagePainter({
    required this.lowResImage,
    required this.highResTile,
    required this.highResRect,
    required this.highlights,
    required this.selectionRects,
    required this.pdfWidth,
    required this.pdfHeight,
    required this.scale,
    this.isSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = ui.FilterQuality.medium;

    if (lowResImage != null) {
      canvas.drawImageRect(
        lowResImage!,
        Rect.fromLTWH(0, 0, lowResImage!.width.toDouble(), lowResImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    if (highResTile != null && highResRect != null) {
      canvas.drawImageRect(
        highResTile!,
        Rect.fromLTWH(0, 0, highResTile!.width.toDouble(), highResTile!.height.toDouble()),
        highResRect!,
        paint,
      );
    }

    for (final highlight in highlights) {
      final highlightPaint = Paint()
        ..color = highlight.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);
      for (final r in highlight.rects) {
        final localRect = coords.pdfToFlutter(r, scale);
        canvas.drawRect(localRect, highlightPaint);
      }
    }

    // Note: Selection rects are now painted by SelectionAreaPainter in overlay layer
  }

  @override
  bool shouldRepaint(covariant PdfPagePainter oldDelegate) {
    return oldDelegate.lowResImage != lowResImage ||
        oldDelegate.highResTile != highResTile ||
        oldDelegate.highResRect != highResRect ||
        oldDelegate.highlights != highlights ||
        oldDelegate.selectionRects != selectionRects ||
        oldDelegate.scale != scale ||
        oldDelegate.pdfHeight != pdfHeight;
  }
}

/// Painter for selection area overlay (separate from PDF content).
class SelectionAreaPainter extends CustomPainter {
  final List<Rect> rects;
  final double pdfWidth;
  final double pdfHeight;
  final double scale;

  SelectionAreaPainter({
    required this.rects,
    required this.pdfWidth,
    required this.pdfHeight,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isEmpty) return;

    final selectPaint = Paint()
      ..color = const Color(0xFF007AFF).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);
    for (final r in rects) {
      final localRect = coords.pdfToFlutter(r, scale);
      canvas.drawRect(localRect, selectPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionAreaPainter oldDelegate) {
    return oldDelegate.rects != rects ||
        oldDelegate.pdfHeight != pdfHeight ||
        oldDelegate.scale != scale;
  }
}
