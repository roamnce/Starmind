/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Quad;
import '../pdf_service.dart';
import '../pdf_viewport_controller.dart';
import '../pdf_coordinates.dart';
import '../viewport_repaint_notifier.dart';
import 'interactive_canvas_viewer.dart';
import 'text_selection_handler.dart';
import 'selection_toolbar.dart';

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

  const PdfViewportWidget({
    super.key,
    required this.controller,
    this.freePanEnabled = false,
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
      widget.controller.panOffset,
      widget.controller.zoom,
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

    return InteractiveCanvasViewer.builder(
      minScale: PdfViewportController.minZoom,
      maxScale: PdfViewportController.maxZoom,
      panEnabled: true,
      scaleEnabled: true,
      transformationController: _transformationController,
      // 无边界限制，允许用户将 PDF 拖动到任意位置
      boundaryMargin: EdgeInsets.all(double.infinity),
      isDrawGesture: _isDrawGesture,
      onInteractionEnd: (details) {
        // Sync controller state
        final scale = _transformationController.value.getMaxScaleOnAxis();
        final translation = _transformationController.value.getTranslation();
        widget.controller.setViewportState(
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
        );
      },
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
}

/// Container for all PDF pages with viewport-based rendering.
class _PdfPagesContainer extends StatelessWidget {
  final PdfViewportController controller;
  final Quad viewport;
  final GlobalKey viewportKey;
  final double baseScale;
  final TransformationController transformationController;

  const _PdfPagesContainer({
    required this.controller,
    required this.viewport,
    required this.viewportKey,
    required this.baseScale,
    required this.transformationController,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = controller.pageCount;
    final pdfSize = controller.pageSizes[0];
    if (pdfSize == null) return const SizedBox.shrink();

    final viewportWidth = pdfSize.width * baseScale;

    return Column(
      key: viewportKey,
      children: List.generate(pageCount, (index) {
        return PdfPageWidget(
          key: ValueKey('page-$index'),
          pageIndex: index,
          controller: controller,
          viewport: viewport,
          viewportWidth: viewportWidth,
          transformationController: transformationController,
        );
      }),
    );
  }
}

/// Individual PDF page widget with tile rendering.
class PdfPageWidget extends StatefulWidget {
  final int pageIndex;
  final PdfViewportController controller;
  final GlobalKey? viewportKey;
  final double viewportWidth;
  final Quad? viewport;
  final TransformationController? transformationController;

  const PdfPageWidget({
    super.key,
    required this.pageIndex,
    required this.controller,
    this.viewportKey,
    required this.viewportWidth,
    this.viewport,
    this.transformationController,
  });

  @override
  State<PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<PdfPageWidget> {
  Size? _pdfSize;
  ui.Image? _lowResImage;
  ui.Image? _highResTile;
  Rect? _highResRect;
  Timer? _debounceTimer;
  TextSelectionHandler? _selectionHandler;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _initPage();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounceTimer?.cancel();
    _lowResImage?.dispose();
    _highResTile?.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final size = await widget.controller.getPageSize(widget.pageIndex);
    if (!mounted) return;

    // Initialize TextSelectionHandler
    final chars = await widget.controller.getPageChars(widget.pageIndex);
    _selectionHandler = TextSelectionHandler(
      chars: chars,
      pageHeight: size.height,
      zoom: widget.transformationController?.value.getMaxScaleOnAxis() ?? 1.0,
      scrollOffset: Offset.zero,
      onSelectionComplete: _onSelectionComplete,
    );

    setState(() {
      _pdfSize = size;
    });
    _loadLowResImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHighResTile();
    });
  }

  void _onSelectionComplete(TextSelectionResult result) {
    setState(() {
      _isSelecting = false;
    });

    // Set selection state in controller
    // The controller's selection mechanism uses internal state that we need to set
    // For now, we use startSelection to trigger the state update
    // Note: A cleaner approach would be to add a setSelectionState method to the controller
    widget.controller.startSelection(
      widget.pageIndex,
      Offset.zero, // Placeholder - actual selection is driven by char indices
    );
  }

  void _onControllerChanged() {
    _startDebounceTimer();
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), () {
      _loadHighResTile();
    });
  }

  Future<void> _loadLowResImage() async {
    if (_pdfSize == null || _lowResImage != null) return;

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

      final img = await _bytesToImage(bytes, targetWidth, targetHeight);
      if (mounted) {
        setState(() {
          _lowResImage = img;
        });
      }
    } catch (e) {
      debugPrint('Error loading low-res page ${widget.pageIndex}: $e');
    }
  }

  Future<void> _loadHighResTile() async {
    if (_pdfSize == null || widget.controller.docId == null) return;

    final visibleRect = _getVisibleRect();
    if (visibleRect == null) {
      if (_highResTile != null) {
        setState(() {
          _highResTile?.dispose();
          _highResTile = null;
          _highResRect = null;
        });
      }
      return;
    }

    if (_highResRect != null && _highResTile != null && _highResRect!.containsRect(visibleRect)) {
      return;
    }

    try {
      final docId = widget.controller.docId!;
      final double pdfWidth = _pdfSize!.width;
      final double pdfHeight = _pdfSize!.height;

      final viewportBox = widget.viewportKey?.currentContext?.findRenderObject() as RenderBox? ?? context.findRenderObject() as RenderBox?;
      if (viewportBox == null) return;

      final baseScale = widget.viewportWidth / pdfWidth;
      final zoom = widget.transformationController?.value.getMaxScaleOnAxis() ?? 1.0;

      final double expandX = 100.0 / zoom;
      final double expandY = 150.0 / zoom;
      final expandedVisibleRect = Rect.fromLTRB(
        max(0.0, visibleRect.left - expandX),
        max(0.0, visibleRect.top - expandY),
        min(pdfWidth * baseScale, visibleRect.right + expandX),
        min(pdfHeight * baseScale, visibleRect.bottom + expandY),
      );

      final coords = PdfCoordinates(pdfWidth: pdfWidth, pdfHeight: pdfHeight);
      final pdfRect = coords.flutterToPdf(expandedVisibleRect, baseScale);

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final renderScale = zoom * dpr * 1.3;
      final targetWidth = (expandedVisibleRect.width * renderScale).round();
      final targetHeight = (expandedVisibleRect.height * renderScale).round();

      if (targetWidth <= 0 || targetHeight <= 0) return;

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

      final img = await _bytesToImage(bytes, targetWidth, targetHeight);
      if (mounted) {
        setState(() {
          _highResTile?.dispose();
          _highResTile = img;
          _highResRect = expandedVisibleRect;
        });
      }
    } catch (e) {
      debugPrint('Error loading high-res page ${widget.pageIndex}: $e');
    }
  }

  Rect? _getVisibleRect() {
    if (!mounted || _pdfSize == null) return null;
    final pageBox = context.findRenderObject() as RenderBox?;
    final viewportBox = context.findRenderObject() as RenderBox?;
    if (pageBox == null || viewportBox == null || !pageBox.attached || !viewportBox.attached) {
      return null;
    }

    final pageLocalToGlobal = pageBox.localToGlobal(Offset.zero);
    final pageRect = pageLocalToGlobal & pageBox.size;
    final viewportLocalToGlobal = viewportBox.localToGlobal(Offset.zero);
    final viewportRect = viewportLocalToGlobal & viewportBox.size;

    final visibleGlobalRect = pageRect.intersect(viewportRect);
    if (visibleGlobalRect.width <= 0 || visibleGlobalRect.height <= 0) {
      return null;
    }

    final left = max(0.0, visibleGlobalRect.left - pageLocalToGlobal.dx);
    final top = max(0.0, visibleGlobalRect.top - pageLocalToGlobal.dy);
    final right = min(pageBox.size.width, visibleGlobalRect.right - pageLocalToGlobal.dx);
    final bottom = min(pageBox.size.height, visibleGlobalRect.bottom - pageLocalToGlobal.dy);

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

    return GestureDetector(
      onLongPressStart: (details) {
        if (_selectionHandler != null) {
          _selectionHandler!.onLongPressStart(details.localPosition);
          setState(() {
            _isSelecting = true;
          });
        }
      },
      onLongPressMoveUpdate: (details) {
        if (_selectionHandler != null && _isSelecting) {
          _selectionHandler!.onLongPressMove(details.localPosition);
          setState(() {}); // Trigger repaint to show selection area
        }
      },
      onLongPressEnd: (details) {
        if (_selectionHandler != null) {
          _selectionHandler!.onLongPressEnd();
        }
      },
      child: Container(
        width: logicalWidth,
        height: logicalHeight,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
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
            selectionRects: widget.controller.getSelectionRects(widget.pageIndex),
            pdfHeight: pdfHeight,
            scale: scale,
            selectionHandler: _selectionHandler,
            isSelecting: _isSelecting,
          ),
        ),
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
  final double pdfHeight;
  final double scale;
  final TextSelectionHandler? selectionHandler;
  final bool isSelecting;

  PdfPagePainter({
    required this.lowResImage,
    required this.highResTile,
    required this.highResRect,
    required this.highlights,
    required this.selectionRects,
    required this.pdfHeight,
    required this.scale,
    this.selectionHandler,
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
      for (final r in highlight.rects) {
        final localRect = _pdfRectToLocal(r);
        canvas.drawRect(localRect, highlightPaint);
      }
    }

    if (selectionRects.isNotEmpty) {
      final selectPaint = Paint()
        ..color = const Color(0xFF007AFF).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      for (final r in selectionRects) {
        final localRect = _pdfRectToLocal(r);
        canvas.drawRect(localRect, selectPaint);
      }
    }

    // Render current text selection during drag operation
    if (isSelecting && selectionHandler != null) {
      final selection = selectionHandler!.currentSelection;
      if (selection != null) {
        final selectPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

        for (final rect in selection.rects) {
          final screenRect = selectionHandler!.pdfToScreen(rect.left, rect.top) &
              Size(rect.right - rect.left, rect.bottom - rect.top);
          canvas.drawRect(screenRect, selectPaint);
        }
      }
    }
  }

  Rect _pdfRectToLocal(Rect pdfRect) {
    return Rect.fromLTRB(
      pdfRect.left * scale,
      (pdfHeight - pdfRect.top) * scale,
      pdfRect.right * scale,
      (pdfHeight - pdfRect.bottom) * scale,
    );
  }

  @override
  bool shouldRepaint(covariant PdfPagePainter oldDelegate) {
    return oldDelegate.lowResImage != lowResImage ||
        oldDelegate.highResTile != highResTile ||
        oldDelegate.highResRect != highResRect ||
        oldDelegate.highlights != highlights ||
        oldDelegate.selectionRects != selectionRects ||
        oldDelegate.scale != scale ||
        oldDelegate.pdfHeight != pdfHeight ||
        oldDelegate.isSelecting != isSelecting;
  }
}
