import 'dart:math';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/pdf/widgets/pdf_viewport_widget.dart';
import 'package:starmind/src/pdf/widgets/text_selection_overlay.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart';
import 'package:starmind/src/pdf/widgets/ink_canvas_layer.dart';
import 'package:starmind/src/pdf/widgets/annotation_renderer.dart';
import 'package:starmind/src/pdf/widgets/interactive_canvas_viewer.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/widgets/annotation_edit_toolbar.dart';
import 'package:starmind/src/pdf/widgets/annotation_sidebar_panel.dart';
import 'package:starmind/src/pdf/widgets/selection_handles_overlay.dart';
import 'package:starmind/src/pdf/pdf_highlight.dart';
import 'package:starmind/src/pdf/pdf_coordinates.dart';
import 'package:starmind/src/pdf/pdf_export_service.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/pen_config_service.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' show Quad, Matrix4;

/// A tab viewport widget that displays a PDF document with interactive features.
///
/// Supports ink drawing, text selection, annotations, and export functionality.
class PdfTabViewport extends StatefulWidget {
  /// The document ID of the PDF to display.
  final String docId;

  /// The file path of the PDF document.
  final String filePath;

  /// The controller managing the PDF viewport state.
  final PdfViewportController pdfController;

  /// Creates a [PdfTabViewport].
  const PdfTabViewport({
    super.key,
    required this.docId,
    required this.filePath,
    required this.pdfController,
  });

  @override
  State<PdfTabViewport> createState() => _PdfTabViewportState();
}

class _PdfTabViewportState extends State<PdfTabViewport>
    with TickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();

  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _pdfStackKey = GlobalKey();
  final Map<int, GlobalKey> _pageKeys = {};

  bool _isExcerptsOpen = true;
  int _currentPage = 1;
  bool _isInteracting = false;

  String _activeTool = 'select';
  Color _activeColor = const Color(0xFFFFC800);

  // Ink drawing state
  InkTool _inkTool = InkTool.pen;
  final double _strokeWidth = 2.0;

  bool _palmRejectionEnabled = false;
  PointerDeviceKind? _lastPointerDeviceKind;

  // Pen configuration state
  PenConfig _penConfig = PenConfig.ballpointPen();
  PenConfigService? _penConfigService;

  // Annotation controller for ink drawing and annotations
  AnnotationController? _annotationController;

  // Selected annotation state for edit toolbar
  String? _selectedAnnotationId;
  Offset? _selectedAnnotationCenter;
  double? _selectedAnnotationTop;
  double? _selectedAnnotationBottom;

  AnimationController? _snapBackController;
  Animation<Offset>? _snapBackAnimation;
  bool _isFirstLayout = true;
  bool? _lastFreePanEnabled;
  Timer? _inertiaTimer;
  bool _isUpdatingTransform = false;

  // Cache workspace controller to avoid accessing deactivated context
  WorkspaceController? _workspaceController;
  bool _freePanEnabled = false;

  double get _pdfLayoutWidth => MediaQuery.of(context).size.width * 0.55;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _workspaceController = context.maybeWorkspaceController;
    _freePanEnabled = _workspaceController?.freePanEnabled ?? false;
  }

  @override
  void initState() {
    super.initState();
    widget.pdfController.addListener(_onPdfChanged);
    _transformController.addListener(_onTransformChanged);
    _initAnnotationController();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadPenConfig();
  }

  Future<void> _loadPenConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _penConfigService = PenConfigService(prefs);
    final savedConfig = _penConfigService!.loadPenConfig();
    if (mounted) {
      setState(() {
        _penConfig = savedConfig;
      });
    }
  }

  Future<void> _initAnnotationController() async {
    final repository = _workspaceController?.repository;
    if (repository == null) return;
    _annotationController = AnnotationController(
      repository: repository,
      documentId: widget.docId,
      undoRedoStack: widget.pdfController.undoRedoStack,
    );
    await _annotationController!.loadAnnotations();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.pdfController.removeListener(_onPdfChanged);
    _transformController.removeListener(_onTransformChanged);
    _inertiaTimer?.cancel();
    _transformController.dispose();
    _annotationController?.dispose();
    _snapBackController?.dispose();
    super.dispose();
  }

  void _onPdfChanged() {
    if (!mounted) return;
    if (!_isInteracting) {
      _syncTransformFromController();
      _updateCurrentPage();
    }
    setState(() {});
  }

  double _getMatrixScale2D(Matrix4 matrix) {
    final double m00 = matrix.entry(0, 0);
    final double m10 = matrix.entry(1, 0);
    final double m20 = matrix.entry(2, 0);
    return sqrt(m00 * m00 + m10 * m10 + m20 * m20);
  }

  void _onTransformChanged() {
    if (!mounted || _isUpdatingTransform) return;
    _isUpdatingTransform = true;
    try {
      final matrix = _transformController.value;
      final zoom = _getMatrixScale2D(matrix).clamp(0.1, 16.0);
      final panX = matrix.entry(0, 3) / zoom;
      final panY = matrix.entry(1, 3) / zoom;

      final pdfCtrl = widget.pdfController;

      // Update controller state
      if (pdfCtrl.transform.zoom != zoom ||
          pdfCtrl.transform.panOffset.dx != panX ||
          pdfCtrl.transform.panOffset.dy != panY) {
        pdfCtrl.transform.setViewportState(
          zoom: zoom,
          panOffset: Offset(panX, panY),
        );
        _updateCurrentPage();
      }

      // Clamp translation to prevent flying off-screen (only in GoodNotes mode)
      // Use cached _freePanEnabled to avoid accessing deactivated context
      if (!_freePanEnabled && !_isInteracting) {
        _clampTransformValueIfNeeded();
      }

      // Detect end of inertia fling animation
      if (!_isInteracting &&
          (_snapBackController == null || !_snapBackController!.isAnimating)) {
        _inertiaTimer?.cancel();
        _inertiaTimer = Timer(const Duration(milliseconds: 50), () {
          if (mounted) {
            _applyCenteringIfNeeded();
          }
        });
      }
    } finally {
      _isUpdatingTransform = false;
    }
  }

  void _clampTransformValueIfNeeded() {
    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    final pdfSize = pdfCtrl.pageSizes.isNotEmpty
        ? pdfCtrl.pageSizes.values.first
        : null;

    if (viewportSize == null || pdfSize == null) return;

    final baseScale = _pdfLayoutWidth / pdfSize.width;
    final pdfDisplayWidth = pdfSize.width * baseScale * pdfCtrl.transform.zoom;

    // Calculate hard boundaries
    double minX;
    double maxX;
    if (pdfDisplayWidth < viewportSize.width) {
      final centerPanX =
          (viewportSize.width / pdfCtrl.transform.zoom -
              pdfSize.width * baseScale) /
          2;
      minX = centerPanX;
      maxX = centerPanX;
    } else {
      minX = (viewportSize.width - pdfDisplayWidth) / pdfCtrl.transform.zoom;
      maxX = 0.0;
    }

    double totalHeight = 0;
    for (int i = 0; i < pdfCtrl.pageCount; i++) {
      final size = pdfCtrl.pageSizes[i];
      final double pageHeight = size?.height ?? 842.0;
      final double pageWidth = size?.width ?? 595.0;
      final pageBaseScale = _pdfLayoutWidth / pageWidth;
      totalHeight += pageHeight * pageBaseScale + 16.0;
    }

    double minY;
    double maxY;
    final pdfDisplayHeight = totalHeight * pdfCtrl.transform.zoom;
    if (pdfDisplayHeight < viewportSize.height) {
      final centerPanY =
          (viewportSize.height / pdfCtrl.transform.zoom - totalHeight) / 2;
      minY = centerPanY;
      maxY = centerPanY;
    } else {
      minY = (viewportSize.height - pdfDisplayHeight) / pdfCtrl.transform.zoom;
      maxY = 0.0;
    }

    final isSnapBackActive = _snapBackController?.isAnimating ?? false;
    final double elasticMargin = (isSnapBackActive || !_isInteracting)
        ? 0.0
        : (120.0 / pdfCtrl.transform.zoom);

    final double allowedMinX = minX - elasticMargin;
    final double allowedMaxX = maxX + elasticMargin;
    final double allowedMinY = minY - elasticMargin;
    final double allowedMaxY = maxY + elasticMargin;

    double targetPanX = pdfCtrl.transform.panOffset.dx.clamp(
      allowedMinX,
      allowedMaxX,
    );
    double targetPanY = pdfCtrl.transform.panOffset.dy.clamp(
      allowedMinY,
      allowedMaxY,
    );

    if (targetPanX != pdfCtrl.transform.panOffset.dx ||
        targetPanY != pdfCtrl.transform.panOffset.dy) {
      pdfCtrl.transform.setViewportState(
        zoom: pdfCtrl.transform.zoom,
        panOffset: Offset(targetPanX, targetPanY),
      );
      final matrix = Matrix4.identity()
        ..scale(pdfCtrl.transform.zoom, pdfCtrl.transform.zoom, 1.0)
        ..translate(targetPanX, targetPanY, 0.0);
      _transformController.value = matrix;
    }
  }

  void _syncTransformFromController() {
    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    if (viewportSize == null) return;

    final pdfSize = pdfCtrl.pageSizes.isNotEmpty
        ? pdfCtrl.pageSizes.values.first
        : null;
    if (pdfSize == null) return;

    if (_isFirstLayout) {
      _isFirstLayout = false;
      final baseScale = _pdfLayoutWidth / pdfSize.width;
      final pdfDisplayWidth =
          pdfSize.width * baseScale * pdfCtrl.transform.zoom;

      double panX = pdfCtrl.transform.panOffset.dx;
      if (pdfDisplayWidth < viewportSize.width) {
        panX =
            (viewportSize.width / pdfCtrl.transform.zoom -
                pdfSize.width * baseScale) /
            2;
      }

      double totalHeight = 0;
      for (int i = 0; i < pdfCtrl.pageCount; i++) {
        final size = pdfCtrl.pageSizes[i];
        final double pageHeight = size?.height ?? 842.0;
        final double pageWidth = size?.width ?? 595.0;
        final pageBaseScale = _pdfLayoutWidth / pageWidth;
        totalHeight += pageHeight * pageBaseScale + 16.0;
      }

      double panY = pdfCtrl.transform.panOffset.dy;
      final pdfDisplayHeight = totalHeight * pdfCtrl.transform.zoom;
      if (pdfDisplayHeight < viewportSize.height) {
        panY = (viewportSize.height / pdfCtrl.transform.zoom - totalHeight) / 2;
      }

      pdfCtrl.transform.setViewportState(
        zoom: pdfCtrl.transform.zoom,
        panOffset: Offset(panX, panY),
      );
    }

    final matrix = Matrix4.identity()
      ..scale(pdfCtrl.transform.zoom, pdfCtrl.transform.zoom, 1.0)
      ..translate(
        pdfCtrl.transform.panOffset.dx,
        pdfCtrl.transform.panOffset.dy,
        0.0,
      );

    _transformController.value = matrix;
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _isInteracting = true;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    // Cancel text selection and close floating toolbar on zoom gesture (2+ fingers)
    if (details.pointerCount >= 2) {
      widget.pdfController.selection.clearSelection();
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _isInteracting = false;
    _inertiaTimer?.cancel();
    if (details.velocity.pixelsPerSecond.distance < 200.0) {
      _applyCenteringIfNeeded();
    }
  }

  void _animatePanOffset(Offset targetOffset) {
    final pdfCtrl = widget.pdfController;
    _snapBackController?.stop();
    _snapBackAnimation =
        Tween<Offset>(
          begin: pdfCtrl.transform.panOffset,
          end: targetOffset,
        ).animate(
          CurvedAnimation(
            parent: _snapBackController!,
            curve: Curves.easeOutBack,
          ),
        );

    _snapBackAnimation!.addListener(() {
      pdfCtrl.transform.setViewportState(
        zoom: pdfCtrl.transform.zoom,
        panOffset: _snapBackAnimation!.value,
      );
      _syncTransformFromController();
    });

    _snapBackController!.forward(from: 0.0);
  }

  /// Center the PDF horizontally if it's narrower than the viewport.
  void _applyCenteringIfNeeded({double? customViewportWidth}) {
    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    final pdfSize = pdfCtrl.pageSizes.isNotEmpty
        ? pdfCtrl.pageSizes.values.first
        : null;

    if (viewportSize == null || pdfSize == null) return;

    final actualViewportWidth = customViewportWidth ?? viewportSize.width;
    final baseScale = _pdfLayoutWidth / pdfSize.width;
    final pdfDisplayWidth = pdfSize.width * baseScale * pdfCtrl.transform.zoom;
    // Use cached _freePanEnabled to avoid accessing deactivated context
    final freePanEnabled = _freePanEnabled;

    double targetPanX = pdfCtrl.transform.panOffset.dx;
    final double margin = 100.0;

    if (freePanEnabled) {
      // 自由平移开启时，统一允许在可视边界内拖动（至少保留 margin 像素在屏幕内）
      final double minX = (margin - pdfDisplayWidth) / pdfCtrl.transform.zoom;
      final double maxX =
          (actualViewportWidth - margin) / pdfCtrl.transform.zoom;
      targetPanX = targetPanX.clamp(minX, maxX);
    } else {
      // 居中模式（Goodnotes 风格）
      if (pdfDisplayWidth < actualViewportWidth) {
        targetPanX =
            (actualViewportWidth / pdfCtrl.transform.zoom -
                pdfSize.width * baseScale) /
            2;
      } else {
        // 大于视口时，限制在边缘边界
        final double minX =
            (actualViewportWidth - pdfDisplayWidth) / pdfCtrl.transform.zoom;
        final double maxX = 0.0;
        targetPanX = targetPanX.clamp(minX, maxX);
      }
    }

    // Calculate total height of the document pages
    double totalHeight = 0;
    for (int i = 0; i < pdfCtrl.pageCount; i++) {
      final size = pdfCtrl.pageSizes[i];
      final double pageHeight = size?.height ?? 842.0;
      final double pageWidth = size?.width ?? 595.0;
      final pageBaseScale = _pdfLayoutWidth / pageWidth;
      totalHeight += pageHeight * pageBaseScale + 16.0;
    }

    double targetPanY = pdfCtrl.transform.panOffset.dy;
    final pdfDisplayHeight = totalHeight * pdfCtrl.transform.zoom;

    if (freePanEnabled) {
      // 自由平移开启时，垂直方向也统一允许在可视边界内拖动
      final double minY = (margin - pdfDisplayHeight) / pdfCtrl.transform.zoom;
      final double maxY =
          (viewportSize.height - margin) / pdfCtrl.transform.zoom;
      targetPanY = targetPanY.clamp(minY, maxY);
    } else {
      // 居中模式
      if (pdfDisplayHeight < viewportSize.height) {
        targetPanY =
            (viewportSize.height / pdfCtrl.transform.zoom - totalHeight) / 2;
      } else {
        // 大于视口时，限制在边缘边界
        final double minY =
            (viewportSize.height - pdfDisplayHeight) / pdfCtrl.transform.zoom;
        final double maxY = 0.0;
        targetPanY = targetPanY.clamp(minY, maxY);
      }
    }

    if (targetPanX != pdfCtrl.transform.panOffset.dx ||
        targetPanY != pdfCtrl.transform.panOffset.dy) {
      _animatePanOffset(Offset(targetPanX, targetPanY));
    }
  }

  void _updateCurrentPage() {
    if (!mounted) return;
    final controller = widget.pdfController;
    if (controller.pageCount <= 1) return;

    final scrollOffset = -controller.transform.panOffset.dy;
    final double viewportWidth = _pdfLayoutWidth;

    double currentHeightAccumulator = 0;
    int detectedPage = 0;

    for (int i = 0; i < controller.pageCount; i++) {
      final size = controller.pageSizes[i];
      double pageHeight = 842.0;
      if (size != null) {
        pageHeight = size.height;
      } else if (controller.pageSizes.isNotEmpty) {
        pageHeight = controller.pageSizes.values.first.height;
      }

      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;
      final logicalHeight =
          pageHeight * baseScale + 16.0; // Static layout height

      if (scrollOffset < currentHeightAccumulator + logicalHeight / 2) {
        detectedPage = i;
        break;
      }
      currentHeightAccumulator += logicalHeight;
      detectedPage = i;
    }

    final newPage = (detectedPage + 1).clamp(1, controller.pageCount);
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  /// Builds the text selection gesture layer for a page.
  Widget _buildTextSelectionLayer(
    int pageIndex,
    PdfViewportController pdfCtrl,
  ) {
    final pdfSize = pdfCtrl.pageSizes[pageIndex];
    if (pdfSize == null) return const SizedBox.shrink();

    final viewportWidth = _pdfLayoutWidth;
    final baseScale = viewportWidth / pdfSize.width;
    final pdfHeight = pdfSize.height;

    return Positioned(
      top: PdfPageWidget.pageVerticalMargin,
      bottom: PdfPageWidget.pageVerticalMargin,
      left: 0.0,
      right: 0.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (details) {
          if (_activeTool != 'select') return;
          final pdfPoint = _screenToPdf(
            details.localPosition,
            baseScale,
            pdfHeight,
          );
          pdfCtrl.selection.startSelection(
            pageIndex,
            pdfPoint,
            pdfCtrl.session.getPageChars,
          );
        },
        onLongPressMoveUpdate: (details) {
          if (_activeTool != 'select') return;
          if (pdfCtrl.selection.selectingPageIndex == pageIndex) {
            final pdfPoint = _screenToPdf(
              details.localPosition,
              baseScale,
              pdfHeight,
            );
            pdfCtrl.selection.updateSelection(
              pdfPoint,
              pdfCtrl.session.getPageChars,
            );
          }
        },
        onLongPressEnd: (details) {
          if (_activeTool != 'select') return;
          if (pdfCtrl.selection.selectingPageIndex == pageIndex) {
            final rects = pdfCtrl.selection.getSelectionRects(
              pageIndex,
              pdfCtrl.session.getCachedPageChars(pageIndex),
            );
            if (rects.isNotEmpty) {
              double minY = double.infinity;
              double left = 0;
              for (final r in rects) {
                final localTop = (pdfHeight - r.top) * baseScale;
                if (localTop < minY) {
                  minY = localTop;
                  left = (r.left + r.width / 2) * baseScale;
                }
              }
              final key = _pageKeys[pageIndex];
              final pageBox =
                  key?.currentContext?.findRenderObject() as RenderBox?;
              if (pageBox != null) {
                final globalToolbarPos = pageBox.localToGlobal(
                  Offset(left, minY + PdfPageWidget.pageVerticalMargin),
                );
                pdfCtrl.selection.endSelection(globalToolbarPos);
                return;
              }
            }
            pdfCtrl.selection.endSelection(details.globalPosition);
          }
        },
        onTap: () {
          if (_activeTool == 'select') {
            pdfCtrl.selection.clearSelection();
          }
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  /// Builds the interactive selection handles overlay for a page.
  Widget _buildSelectionHandlesOverlay(
    int pageIndex,
    PdfViewportController pdfCtrl,
  ) {
    final pdfSize = pdfCtrl.pageSizes[pageIndex];
    if (pdfSize == null) return const SizedBox.shrink();

    final viewportWidth = _pdfLayoutWidth;
    final baseScale = viewportWidth / pdfSize.width;
    final pdfHeight = pdfSize.height;

    final startIdx = pdfCtrl.selection.selectionStartCharIndex;
    final endIdx = pdfCtrl.selection.selectionEndCharIndex;
    if (startIdx == null || endIdx == null) return const SizedBox.shrink();

    final chars = pdfCtrl.session.pageCharsCache[pageIndex];
    if (chars == null || chars.isEmpty) return const SizedBox.shrink();

    final int start = min(startIdx, endIdx);
    final int end = max(startIdx, endIdx);

    // Safeguard indices
    final int safeStart = start.clamp(0, chars.length - 1);
    final int safeEnd = end.clamp(0, chars.length - 1);

    final startChar = chars[safeStart];
    final endChar = chars[safeEnd];

    // Calculate line heights and positions in page-local space
    final startLeft = startChar.left * baseScale;
    final startTop = (pdfHeight - startChar.top) * baseScale;
    final startLineHeight = (startChar.top - startChar.bottom) * baseScale;

    final endRight = endChar.right * baseScale;
    final endTop = (pdfHeight - endChar.top) * baseScale;
    final endLineHeight = (endChar.top - endChar.bottom) * baseScale;

    return SelectionHandlesOverlay(
      startHandlePosition: Offset(startLeft, startTop),
      startLineHeight: startLineHeight,
      endHandlePosition: Offset(endRight, endTop),
      endLineHeight: endLineHeight,
      zoom: pdfCtrl.transform.zoom,
      onHandleDrag: (type, newLocalPos) {
        final pdfPoint = _screenToPdf(newLocalPos, baseScale, pdfHeight);
        final closestIdx = pdfCtrl.selection.findClosestChar(chars, pdfPoint);
        if (closestIdx != -1) {
          if (type == SelectionHandleType.start) {
            pdfCtrl.selection.updateSelectionStart(closestIdx);
          } else {
            pdfCtrl.selection.updateSelectionEnd(closestIdx);
          }
        }
      },
      onDragEnd: () {
        // Calculate new toolbar position above selection
        final rects = pdfCtrl.selection.getSelectionRects(
          pageIndex,
          pdfCtrl.session.getCachedPageChars(pageIndex),
        );
        if (rects.isNotEmpty) {
          double minY = double.infinity;
          double left = 0;
          for (final r in rects) {
            final localTop = (pdfHeight - r.top) * baseScale;
            if (localTop < minY) {
              minY = localTop;
              left = (r.left + r.width / 2) * baseScale;
            }
          }

          final key = _pageKeys[pageIndex];
          final pageBox = key?.currentContext?.findRenderObject() as RenderBox?;
          if (pageBox != null) {
            final globalToolbarPos = pageBox.localToGlobal(
              Offset(left, minY + PdfPageWidget.pageVerticalMargin),
            );
            pdfCtrl.selection.endSelection(globalToolbarPos);
          }
        }
      },
    );
  }

  /// Converts screen coordinates to PDF coordinates.
  Offset _screenToPdf(Offset localPos, double baseScale, double pdfHeight) {
    final pdfX = localPos.dx / baseScale;
    final pdfY = pdfHeight - (localPos.dy / baseScale);
    return Offset(pdfX, pdfY);
  }

  /// Builds annotations list for a page (persistent + temporary highlights).
  List<Annotation> _buildPageAnnotations(
    int pageIndex,
    PdfViewportController pdfCtrl,
    AnnotationController? annotationController,
  ) {
    final annotations = <Annotation>[];

    // 1. Load persistent annotations from SQLite DB
    if (annotationController != null) {
      annotations.addAll(annotationController.annotationsForPage(pageIndex));
    }

    // 2. Load temporary highlights from controller, excluding duplicates
    final persistentIds = annotations.map((a) => a.id).toSet();
    final tempAnnotations = pdfCtrl.highlights
        .where((h) => h.pageIndex == pageIndex && !persistentIds.contains(h.id))
        .map(
          (h) => Annotation.highlight(
            id: h.id,
            documentId: 'current-doc',
            pageIndex: h.pageIndex,
            startCharIndex: h.startCharIndex,
            endCharIndex: h.endCharIndex,
            selectedText: h.text,
            rects: h.rects
                .map(
                  (r) => AnnotationRect(
                    left: r.left,
                    top: r.top,
                    right: r.right,
                    bottom: r.bottom,
                  ),
                )
                .toList(),
            colorHex:
                '#${(h.color.toARGB32() & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}',
          ),
        );
    annotations.addAll(tempAnnotations);

    return annotations;
  }

  Widget _buildTopToolbar(
    BuildContext context,
    bool isDark,
    PdfViewportController pdfCtrl,
  ) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1610).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildGlassToolbarButton(
                  icon: Icons.near_me_rounded,
                  tooltip: '选择',
                  isActive: _activeTool == 'select',
                  onTap: () => setState(() => _activeTool = 'select'),
                  isDark: isDark,
                ),
                _buildGlassToolbarButton(
                  icon: Icons.pan_tool_rounded,
                  tooltip: '手形拖动',
                  isActive: _activeTool == 'hand',
                  onTap: () => setState(() => _activeTool = 'hand'),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildToolbarDivider(isDark),
                const SizedBox(width: 4),
                _buildGlassToolbarButton(
                  icon: Icons.edit_rounded,
                  tooltip: '画笔',
                  isActive: _activeTool == 'pen',
                  onTap: () => setState(() {
                    _activeTool = 'pen';
                    _inkTool = InkTool.pen;
                  }),
                  onLongPress: () => _showPenConfigMenu(context, isDark),
                  isDark: isDark,
                ),
                _buildGlassToolbarButton(
                  icon: Icons.border_color_rounded,
                  tooltip: '高亮',
                  isActive: _activeTool == 'highlight',
                  onTap: () => setState(() {
                    _activeTool = 'highlight';
                    _inkTool = InkTool.highlighter;
                  }),
                  isDark: isDark,
                ),
                _buildGlassToolbarButton(
                  icon: Icons.text_fields_rounded,
                  tooltip: '文本批注',
                  isActive: _activeTool == 'text',
                  onTap: () => setState(() => _activeTool = 'text'),
                  isDark: isDark,
                ),
                _buildGlassToolbarButton(
                  icon: Icons.auto_fix_normal_rounded,
                  tooltip: '橡皮擦',
                  isActive: _activeTool == 'eraser',
                  onTap: () => setState(() {
                    _activeTool = 'eraser';
                    _inkTool = InkTool.eraser;
                  }),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildToolbarDivider(isDark),
                const SizedBox(width: 4),
                _buildGlassToolbarButton(
                  icon: _palmRejectionEnabled
                      ? Icons.do_not_touch
                      : Icons.touch_app,
                  tooltip: _palmRejectionEnabled ? '防误触: 开' : '防误触: 关',
                  isActive: _palmRejectionEnabled,
                  onTap: () => setState(() {
                    _palmRejectionEnabled = !_palmRejectionEnabled;
                    context.workspaceController.setPalmRejectionEnabled(
                      _palmRejectionEnabled,
                    );
                  }),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildToolbarDivider(isDark),
                const SizedBox(width: 6),
                ...[
                  const Color(0xFFFFC800),
                  const Color(0xFF4CAF50),
                  const Color(0xFF2196F3),
                  const Color(0xFFE05858),
                ].map((color) {
                  final isSelected = _activeColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _activeColor = color),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.white.withValues(alpha: 0.5),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
                const Spacer(),
                _buildGlassToolbarButton(
                  icon: Icons.undo_rounded,
                  tooltip: '撤销',
                  isActive: false,
                  onTap: pdfCtrl.canUndo ? () => pdfCtrl.undo() : null,
                  isDark: isDark,
                  enabled: pdfCtrl.canUndo,
                ),
                _buildGlassToolbarButton(
                  icon: Icons.redo_rounded,
                  tooltip: '重做',
                  isActive: false,
                  onTap: pdfCtrl.canRedo ? () => pdfCtrl.redo() : null,
                  isDark: isDark,
                  enabled: pdfCtrl.canRedo,
                ),
                const SizedBox(width: 4),
                _buildToolbarDivider(isDark),
                const SizedBox(width: 4),
                _buildGlassToolbarButton(
                  icon: _isExcerptsOpen
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                  tooltip: '批注列表',
                  isActive: _isExcerptsOpen,
                  onTap: () {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final viewportSize = _viewportKey.currentContext?.size;
                    double? targetWidth;
                    if (viewportSize != null) {
                      if (_isExcerptsOpen) {
                        targetWidth = viewportSize.width + (screenWidth * 0.28);
                      } else {
                        targetWidth = viewportSize.width - (screenWidth * 0.28);
                      }
                    }
                    setState(() {
                      _isExcerptsOpen = !_isExcerptsOpen;
                    });
                    if (targetWidth != null) {
                      _applyCenteringIfNeeded(customViewportWidth: targetWidth);
                    }
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildToolbarDivider(isDark),
                const SizedBox(width: 4),
                _buildGlassToolbarButton(
                  icon: Icons.share_rounded,
                  tooltip: '导出',
                  isActive: false,
                  onTap: () => _showExportMenu(context, isDark),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows the export menu with options for exporting PDF and annotations.
  void _showExportMenu(BuildContext context, bool isDark) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final RenderBox? buttonBox = context.findRenderObject() as RenderBox?;

    if (buttonBox == null) return;

    final Offset buttonPosition = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final Size buttonSize = buttonBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height + 4,
        buttonPosition.dx + buttonSize.width,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'full',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              const Text('导出带注释 PDF'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'standard',
          child: Row(
            children: [
              Icon(
                Icons.file_present_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              const Text('仅导出标准注释'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'json',
          child: Row(
            children: [
              Icon(
                Icons.data_object_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              const Text('导出注释 JSON'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleExport(context, value, isDark);
      }
    });
  }

  /// Handles the export action based on selected menu item.
  Future<void> _handleExport(
    BuildContext context,
    String exportType,
    bool isDark,
  ) async {
    // Get current document info
    final workspaceController = context.workspaceController;
    final leaf = workspaceController.rootLayoutNode as LeafNode;
    final activeTab = leaf.tabs[leaf.activeIndex];

    if (activeTab.type != TabType.pdf) {
      _showSnackBar(context, '仅 PDF 文档支持导出', isDark);
      return;
    }

    final docId = activeTab.id;

    // Find the document
    final documents = await workspaceController.repository.getDocuments();
    if (!mounted) return;
    final doc = documents.firstWhere(
      (d) => d.id == docId,
      orElse: () => throw Exception('Document not found'),
    );

    // Generate default output filename
    final originalName = doc.filePath.split('/').last.split('.').first;
    String defaultFileName;
    String fileExtension;

    switch (exportType) {
      case 'full':
        defaultFileName = '${originalName}_annotated';
        fileExtension = 'pdf';
      case 'standard':
        defaultFileName = '${originalName}_standard';
        fileExtension = 'pdf';
      case 'json':
        defaultFileName = '${originalName}_annotations';
        fileExtension = 'json';
      default:
        defaultFileName = originalName;
        fileExtension = 'pdf';
    }

    // Show file save dialog using file_picker package
    // Note: FilePicker doesn't have a saveFile method on all platforms
    // We'll use getDirectoryPath and construct the full path
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: '选择保存位置',
    );

    if (selectedDirectory == null) {
      return; // User cancelled
    }

    // Construct the full output path
    String outputPath = '$selectedDirectory/$defaultFileName.$fileExtension';

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1610) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              '正在导出...',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final exportService = PdfExportService(workspaceController.repository);

      switch (exportType) {
        case 'full':
          await exportService.exportPdfWithAnnotations(
            documentId: docId,
            outputPath: outputPath,
          );
        case 'standard':
          await exportService.exportPdfStandardOnly(
            documentId: docId,
            outputPath: outputPath,
          );
        case 'json':
          await exportService.exportAnnotationsJson(
            documentId: docId,
            outputPath: outputPath,
          );
      }

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        _showSnackBar(context, '导出成功: $outputPath', isDark, isSuccess: true);
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        _showSnackBar(context, '导出失败: ${e.toString()}', isDark, isError: true);
      }
    }
  }

  /// Shows a snackbar message.
  void _showSnackBar(
    BuildContext context,
    String message,
    bool isDark, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : (isError ? Icons.error_rounded : Icons.info_rounded),
              color: isSuccess
                  ? Colors.green
                  : (isError
                        ? Colors.red
                        : (isDark ? Colors.white : Colors.black87)),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF2A2518) : Colors.white,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildToolbarDivider(bool isDark) {
    return Container(
      width: 1,
      height: 20,
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.12),
    );
  }

  Widget _buildGlassToolbarButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback? onTap,
    required bool isDark,
    bool enabled = true,
    VoidCallback? onLongPress,
  }) {
    final color = enabled
        ? (isActive
              ? const Color(0xFFFFC800)
              : (isDark ? Colors.white70 : Colors.black87))
        : (isDark ? Colors.white24 : Colors.black26);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFC800).withValues(alpha: 0.15)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildBottomStatusBar(
    BuildContext context,
    bool isDark,
    PdfViewportController pdfCtrl,
  ) {
    return ListenableBuilder(
      listenable: pdfCtrl,
      builder: (context, _) {
        final ws = context.workspaceController;
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0A07) : const Color(0xFFFAF8F5),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 12,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentPage / ${pdfCtrl.pageCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onPressed: () =>
                        pdfCtrl.transform.setZoom(pdfCtrl.transform.zoom - 0.5),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(pdfCtrl.transform.zoom * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onPressed: () =>
                        pdfCtrl.transform.setZoom(pdfCtrl.transform.zoom + 0.5),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 12,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: ws.isImmersiveMode ? '退出沉浸模式' : '沉浸模式',
                    child: IconButton(
                      icon: Icon(
                        ws.isImmersiveMode
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        size: 16,
                        color: const Color(0xFFFFC800),
                      ),
                      onPressed: () {
                        ws.setImmersiveMode(!ws.isImmersiveMode);
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExcerptsSidebar(
    BuildContext context,
    bool isDark,
    PdfViewportController pdfCtrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0C08) : const Color(0xFFF5F2EC),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '摘录与思维导图',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFFFFC800),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0x26FFC800),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  label: Text(
                    '${pdfCtrl.highlights.length} 项',
                    style: const TextStyle(
                      color: Color(0xFFFFC800),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x12FFDC8C), height: 1),
          Expanded(
            child: pdfCtrl.highlights.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.format_indent_increase_rounded,
                            size: 36,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无摘录',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '长按文档文字进行高亮和摘录。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: pdfCtrl.highlights.length,
                    itemBuilder: (context, index) {
                      final item = pdfCtrl.highlights[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        color: isDark ? const Color(0x1F1A150F) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: item.color.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(width: 5, color: item.color),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '第 ${item.pageIndex + 1} 页',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white30
                                                    : Colors.black38,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => pdfCtrl
                                                  .removeHighlight(item.id),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFE05858),
                                                size: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.text,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )
                                                : Colors.black87,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _workspaceController?.isDarkMode ?? true;
    final pdfCtrl = widget.pdfController;

    // Use cached _freePanEnabled to avoid accessing deactivated context
    final freePanEnabled = _freePanEnabled;
    if (_lastFreePanEnabled != null && _lastFreePanEnabled != freePanEnabled) {
      _lastFreePanEnabled = freePanEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyCenteringIfNeeded();
      });
    } else {
      _lastFreePanEnabled = freePanEnabled;
    }

    // Diagnostic: show loading step overlay when PDF is loading or error
    if (pdfCtrl.isLoading || pdfCtrl.loadingError != null) {
      return Column(
        children: [
          _buildTopToolbar(context, isDark, pdfCtrl),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xEC100D08)
                      : const Color(0xECFFFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC800), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pdfCtrl.loadingError != null)
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Color(0xFFE05858),
                      )
                    else
                      const CircularProgressIndicator(color: Color(0xFFFFC800)),
                    const SizedBox(height: 16),
                    Text(
                      pdfCtrl.loadingError ?? pdfCtrl.loadingStep,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (pdfCtrl.loadingError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '诊断提示：PDFium初始化或文档加载可能失败，请检查Starmind-DIAG日志',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0x66FFFFFF)
                              : Colors.black45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _buildBottomStatusBar(context, isDark, pdfCtrl),
        ],
      );
    }

    final viewportWidth = _pdfLayoutWidth;

    return Column(
      children: [
        _buildTopToolbar(context, isDark, pdfCtrl),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  key: _pdfStackKey,
                  children: [
                    Container(
                      key: _viewportKey,
                      color: isDark
                          ? const Color(0xFF1A1610)
                          : const Color(0xFFFAF9F6),
                      child: Listener(
                        onPointerDown: (event) {
                          _lastPointerDeviceKind = event.kind;
                        },
                        child: InteractiveCanvasViewer.builder(
                          transformationController: _transformController,
                          minScale: 0.1,
                          maxScale: 16.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          isDrawGesture: (details) {
                            if (_palmRejectionEnabled &&
                                _lastPointerDeviceKind !=
                                    PointerDeviceKind.stylus) {
                              return false;
                            }
                            if (details.pointerCount >= 2) return false;
                            return _activeTool == 'pen' ||
                                _activeTool == 'highlight' ||
                                _activeTool == 'eraser';
                          },
                          onInteractionStart: _onInteractionStart,
                          onInteractionUpdate: _onInteractionUpdate,
                          onInteractionEnd: _onInteractionEnd,
                          builder: (BuildContext context, Quad viewport) {
                            return _PdfTabPagesContainer(
                              controller: pdfCtrl,
                              viewport: viewport,
                              viewportKey: _viewportKey,
                              viewportWidth: viewportWidth,
                              transformationController: _transformController,
                              activeTool: _activeTool,
                              activeColor: _activeColor,
                              inkTool: _inkTool,
                              strokeWidth: _strokeWidth,
                              annotationController: _annotationController,
                              textSelectionLayerBuilder: (index) =>
                                  _buildTextSelectionLayer(index, pdfCtrl),
                              selectionHandlesOverlayBuilder: (index) =>
                                  _buildSelectionHandlesOverlay(index, pdfCtrl),
                              pageAnnotationsBuilder: (index) =>
                                  _buildPageAnnotations(
                                    index,
                                    pdfCtrl,
                                    _annotationController,
                                  ),
                              pageKeys: _pageKeys,
                            );
                          },
                        ),
                      ),
                    ),
                    if (pdfCtrl.selection.selectionToolbarPosition != null)
                      () {
                        final pageIndex = pdfCtrl.selection.selectingPageIndex;
                        if (pageIndex == null) return const SizedBox.shrink();

                        final pdfSize = pdfCtrl.pageSizes[pageIndex];
                        if (pdfSize == null) return const SizedBox.shrink();

                        final selectionRects = pdfCtrl.selection
                            .getSelectionRects(
                              pageIndex,
                              pdfCtrl.session.getCachedPageChars(pageIndex),
                            );

                        if (selectionRects.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final viewportWidth = _pdfLayoutWidth;
                        final scale =
                            viewportWidth /
                            pdfSize.width *
                            pdfCtrl.transform.zoom;
                        final panOffset = pdfCtrl.transform.panOffset;
                        final coords = PdfCoordinates(
                          pdfWidth: pdfSize.width,
                          pdfHeight: pdfSize.height,
                        );

                        // Convert PDF rects to screen coordinates
                        final screenRects = selectionRects
                            .map((r) => coords.pdfToFlutter(r, scale))
                            .toList();

                        // Find bounds in screen coordinates
                        final topRect = screenRects.reduce(
                          (a, b) => a.top < b.top ? a : b,
                        );
                        final bottomRect = screenRects.reduce(
                          (a, b) => a.bottom > b.bottom ? a : b,
                        );
                        final centerX =
                            screenRects.fold<double>(
                              0,
                              (sum, r) => sum + (r.left + r.right) / 2,
                            ) /
                            screenRects.length;

                        // Calculate actual screen positions
                        // screenRects are relative to PDF page origin (0,0 at top-left of page)
                        // panOffset is the translation applied to the entire PDF canvas
                        final topY = topRect.top + panOffset.dy;
                        final bottomY = bottomRect.bottom + panOffset.dy;
                        final screenCenterX = centerX + panOffset.dx;

                        // Get the actual screen bounds for toolbar positioning
                        final screenHeight = MediaQuery.of(context).size.height;
                        final screenWidth = MediaQuery.of(context).size.width;

                        // Clamp toolbar position to screen bounds with safe margins
                        final safeTopMargin =
                            60.0; // Leave space for top toolbar
                        final safeBottomMargin =
                            40.0; // Leave space for bottom status bar

                        return PdfSelectionToolbar(
                          selectionCenter: Offset(
                            screenCenterX,
                            (topY + bottomY) / 2,
                          ),
                          selectionTop: topY.clamp(
                            safeTopMargin,
                            screenHeight - safeBottomMargin,
                          ),
                          selectionBottom: bottomY.clamp(
                            safeTopMargin,
                            screenHeight - safeBottomMargin,
                          ),
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          onDismiss: () => pdfCtrl.selection.clearSelection(),
                          onHighlight: (color) async {
                            final pageIndex =
                                pdfCtrl.selection.selectingPageIndex!;
                            final start = min(
                              pdfCtrl.selection.selectionStartCharIndex!,
                              pdfCtrl.selection.selectionEndCharIndex!,
                            ).toInt();
                            final end = max(
                              pdfCtrl.selection.selectionStartCharIndex!,
                              pdfCtrl.selection.selectionEndCharIndex!,
                            ).toInt();
                            final text = pdfCtrl.selection.getSelectedText(
                              pdfCtrl.session.getCachedPageChars(pageIndex),
                            );
                            final rects = pdfCtrl.selection.getSelectionRects(
                              pageIndex,
                              pdfCtrl.session.getCachedPageChars(pageIndex),
                            );

                            if (_annotationController != null) {
                              await _annotationController!.createHighlight(
                                pageIndex: pageIndex,
                                startCharIndex: start,
                                endCharIndex: end,
                                selectedText: text,
                                rects: rects
                                    .map(
                                      (r) => AnnotationRect(
                                        left: r.left,
                                        top: r.top,
                                        right: r.right,
                                        bottom: r.bottom,
                                      ),
                                    )
                                    .toList(),
                                colorHex:
                                    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                              );
                            } else {
                              final highlight = PdfHighlight(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                pageIndex: pageIndex,
                                startCharIndex: start,
                                endCharIndex: end,
                                color: color,
                                rects: rects,
                                text: text,
                              );
                              pdfCtrl.addHighlight(highlight);
                            }
                            pdfCtrl.selection.clearSelection();
                          },
                          onUnderline: (color) async {
                            final pageIndex =
                                pdfCtrl.selection.selectingPageIndex!;
                            final start = min(
                              pdfCtrl.selection.selectionStartCharIndex!,
                              pdfCtrl.selection.selectionEndCharIndex!,
                            ).toInt();
                            final end = max(
                              pdfCtrl.selection.selectionStartCharIndex!,
                              pdfCtrl.selection.selectionEndCharIndex!,
                            ).toInt();
                            final text = pdfCtrl.selection.getSelectedText(
                              pdfCtrl.session.getCachedPageChars(pageIndex),
                            );
                            final rects = pdfCtrl.selection.getSelectionRects(
                              pageIndex,
                              pdfCtrl.session.getCachedPageChars(pageIndex),
                            );

                            if (_annotationController != null) {
                              await _annotationController!.createUnderline(
                                pageIndex: pageIndex,
                                startCharIndex: start,
                                endCharIndex: end,
                                selectedText: text,
                                rects: rects
                                    .map(
                                      (r) => AnnotationRect(
                                        left: r.left,
                                        top: r.top,
                                        right: r.right,
                                        bottom: r.bottom,
                                      ),
                                    )
                                    .toList(),
                                colorHex:
                                    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                              );
                            }
                            pdfCtrl.selection.clearSelection();
                          },
                        );
                      }(),
                    // Annotation edit toolbar (when annotation is tapped)
                    if (_selectedAnnotationId != null &&
                        _selectedAnnotationCenter != null)
                      () {
                        final annotation = _annotationController?.annotations
                            .firstWhere(
                              (a) => a.id == _selectedAnnotationId,
                              orElse: () =>
                                  throw StateError('Annotation not found'),
                            );
                        if (annotation == null) return const SizedBox.shrink();

                        return AnnotationEditToolbar(
                          annotation: annotation,
                          annotationCenter: _selectedAnnotationCenter!,
                          annotationTop:
                              _selectedAnnotationTop ??
                              _selectedAnnotationCenter!.dy,
                          annotationBottom:
                              _selectedAnnotationBottom ??
                              _selectedAnnotationCenter!.dy,
                          screenWidth: MediaQuery.of(context).size.width,
                          screenHeight: MediaQuery.of(context).size.height,
                          onDelete: () async {
                            if (_annotationController != null) {
                              await _annotationController!.deleteAnnotation(
                                _selectedAnnotationId!,
                              );
                            }
                            setState(() {
                              _selectedAnnotationId = null;
                              _selectedAnnotationCenter = null;
                              _selectedAnnotationTop = null;
                              _selectedAnnotationBottom = null;
                            });
                          },
                          onColorChange: () {
                            // TODO: Show color picker for annotation
                          },
                          onClose: () {
                            setState(() {
                              _selectedAnnotationId = null;
                              _selectedAnnotationCenter = null;
                              _selectedAnnotationTop = null;
                              _selectedAnnotationBottom = null;
                            });
                          },
                        );
                      }(),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isExcerptsOpen
                    ? MediaQuery.of(context).size.width * 0.28
                    : 0,
                child: ClipRect(
                  child: _isExcerptsOpen
                      ? (_annotationController != null
                            ? AnnotationSidebarPanel(
                                annotationController: _annotationController!,
                                currentPageIndex: _currentPage - 1,
                                onNavigate: (pageIndex, annotation) {
                                  // Scroll to page
                                  // For now, just update current page indicator
                                  setState(() {
                                    _currentPage = pageIndex + 1;
                                  });
                                },
                              )
                            : _buildExcerptsSidebar(context, isDark, pdfCtrl))
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        _buildBottomStatusBar(context, isDark, pdfCtrl),
      ],
    );
  }

  /// Shows the pen configuration popup menu.
  void _showPenConfigMenu(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1610) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 12),
            Text(
              '画笔设置',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stabilizer level section
              Text(
                '平滑度',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _penConfig.stabilizerLevel.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _penConfig = _penConfig.copyWith(
                            stabilizerLevel: value.round(),
                          );
                        });
                        _penConfigService?.savePenConfig(_penConfig);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_penConfig.stabilizerLevel}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '值越高线条越平滑，但响应稍慢',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Pressure curve section (only for pressure-enabled pens)
              if (_penConfig.pressureEnabled) ...[
                Text(
                  '压感曲线',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPressureCurveChip(
                      label: '线性',
                      curve: PressureCurve.linear,
                      isDark: isDark,
                    ),
                    _buildPressureCurveChip(
                      label: '柔和',
                      curve: PressureCurve.soft,
                      isDark: isDark,
                    ),
                    _buildPressureCurveChip(
                      label: '硬朗',
                      curve: PressureCurve.firm,
                      isDark: isDark,
                    ),
                    _buildPressureCurveChip(
                      label: 'S型',
                      curve: PressureCurve.sCurve,
                      isDark: isDark,
                    ),
                    _buildPressureCurveChip(
                      label: '重压',
                      curve: PressureCurve.heavy,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '调节笔尖压力与线条粗细的关系',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '完成',
              style: TextStyle(color: const Color(0xFFFFC800), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a pressure curve selection chip.
  Widget _buildPressureCurveChip({
    required String label,
    required PressureCurve curve,
    required bool isDark,
  }) {
    final isSelected = _isPressureCurveEqual(curve);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _penConfig = _penConfig.copyWith(pressureCurve: curve);
          });
          _penConfigService?.savePenConfig(_penConfig);
        }
      },
      selectedColor: const Color(0xFFFFC800).withValues(alpha: 0.2),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFFFFC800)
            : (isDark ? Colors.white70 : Colors.black87),
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFFFC800)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12)),
      ),
    );
  }

  /// Check if two pressure curves are equal by comparing control points.
  bool _isPressureCurveEqual(PressureCurve other) {
    return _penConfig.pressureCurve.p1 == other.p1 &&
        _penConfig.pressureCurve.p2 == other.p2;
  }
}

class _PdfTabPagesContainer extends StatelessWidget {
  final PdfViewportController controller;
  final Quad viewport;
  final GlobalKey viewportKey;
  final double viewportWidth;
  final TransformationController transformationController;
  final String activeTool;
  final Color activeColor;
  final InkTool inkTool;
  final double strokeWidth;
  final AnnotationController? annotationController;
  final Widget Function(int pageIndex) textSelectionLayerBuilder;
  final Widget Function(int pageIndex) selectionHandlesOverlayBuilder;
  final List<Annotation> Function(int pageIndex) pageAnnotationsBuilder;
  final Map<int, GlobalKey> pageKeys;

  const _PdfTabPagesContainer({
    required this.controller,
    required this.viewport,
    required this.viewportKey,
    required this.viewportWidth,
    required this.transformationController,
    required this.activeTool,
    required this.activeColor,
    required this.inkTool,
    required this.strokeWidth,
    required this.annotationController,
    required this.textSelectionLayerBuilder,
    required this.selectionHandlesOverlayBuilder,
    required this.pageAnnotationsBuilder,
    required this.pageKeys,
  });

  double _getMatrixScale2D(Matrix4 matrix) {
    final double m00 = matrix.entry(0, 0);
    final double m10 = matrix.entry(1, 0);
    final double m20 = matrix.entry(2, 0);
    return sqrt(m00 * m00 + m10 * m10 + m20 * m20);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = controller.pageCount;
    if (pageCount == 0) return const SizedBox.shrink();

    final matrix = transformationController.value;
    final scale = _getMatrixScale2D(matrix);
    final translation = matrix.getTranslation();

    final viewportSize = MediaQuery.of(context).size;
    final viewportHeight = viewportSize.height;

    // Calculate visible Y range in Flutter coordinates (before transform)
    final visibleTop = -translation.y / scale;
    final visibleBottom = (viewportHeight - translation.y) / scale;

    int firstVisible = -1;
    int lastVisible = -1;
    double currentHeightAccumulator = 0.0;

    for (int i = 0; i < pageCount; i++) {
      final size = controller.pageSizes[i];
      double pageHeight = 842.0;
      if (size != null) {
        pageHeight = size.height;
      } else if (controller.pageSizes.isNotEmpty) {
        pageHeight = controller.pageSizes.values.first.height;
      }

      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;
      final logicalHeight = pageHeight * baseScale + 16.0;

      final pageTop = currentHeightAccumulator;
      final pageBottom = currentHeightAccumulator + logicalHeight;

      if (firstVisible == -1 && pageBottom >= visibleTop) {
        firstVisible = i;
      }
      if (pageTop <= visibleBottom) {
        lastVisible = i;
      }

      currentHeightAccumulator += logicalHeight;
    }

    if (firstVisible == -1) firstVisible = 0;
    if (lastVisible == -1) lastVisible = pageCount - 1;

    // Apply 1-page buffer
    const int pageBuffer = 1;
    firstVisible = (firstVisible - pageBuffer).clamp(0, pageCount - 1);
    lastVisible = (lastVisible + pageBuffer).clamp(0, pageCount - 1);

    final children = <Widget>[];

    // Top placeholder
    double topPlaceholderHeight = 0.0;
    for (int i = 0; i < firstVisible; i++) {
      final size = controller.pageSizes[i];
      double pageHeight = 842.0;
      if (size != null) {
        pageHeight = size.height;
      } else if (controller.pageSizes.isNotEmpty) {
        pageHeight = controller.pageSizes.values.first.height;
      }
      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;
      topPlaceholderHeight += pageHeight * baseScale + 16.0;
    }
    if (topPlaceholderHeight > 0) {
      children.add(
        SizedBox(height: topPlaceholderHeight, child: const SizedBox.shrink()),
      );
    }

    // Visible pages
    for (int i = firstVisible; i <= lastVisible; i++) {
      final isInkMode =
          activeTool == 'pen' ||
          activeTool == 'highlight' ||
          activeTool == 'eraser';
      final colorHex =
          '#${activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      final size = controller.pageSizes[i];
      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;

      final key = pageKeys.putIfAbsent(i, () => GlobalKey());

      children.add(
        Stack(
          key: key,
          children: [
            PdfPageWidget(
              pageIndex: i,
              controller: controller,
              viewportKey: viewportKey,
              viewportWidth: viewportWidth,
              transformationController: transformationController,
              isInkMode: isInkMode,
            ),
            if (activeTool == 'select') textSelectionLayerBuilder(i),
            if (activeTool == 'select' &&
                controller.selection.selectingPageIndex == i)
              Positioned(
                top: PdfPageWidget.pageVerticalMargin,
                bottom: PdfPageWidget.pageVerticalMargin,
                left: 0.0,
                right: 0.0,
                child: selectionHandlesOverlayBuilder(i),
              ),
            if (isInkMode)
              Positioned(
                top: PdfPageWidget.pageVerticalMargin,
                bottom: PdfPageWidget.pageVerticalMargin,
                left: 0.0,
                right: 0.0,
                child: InkCanvasLayer(
                  annotationController:
                      annotationController ??
                      AnnotationController.nullController,
                  pageIndex: i,
                  isInkMode: isInkMode,
                  palmRejectionEnabled:
                      controller.transform.palmRejectionEnabled,
                  currentTool: inkTool,
                  currentColor: colorHex,
                  strokeWidth: strokeWidth,
                  scale: baseScale,
                  pdfWidth: pdfWidth,
                  pdfHeight: size?.height ?? 842.0,
                ),
              ),
            Positioned(
              top: PdfPageWidget.pageVerticalMargin,
              bottom: PdfPageWidget.pageVerticalMargin,
              left: 0.0,
              right: 0.0,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AnnotationRenderer(
                    annotations: pageAnnotationsBuilder(i),
                    scale: baseScale,
                    pdfWidth: pdfWidth,
                    pdfHeight: size?.height ?? 842.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Bottom placeholder
    double bottomPlaceholderHeight = 0.0;
    for (int i = lastVisible + 1; i < pageCount; i++) {
      final size = controller.pageSizes[i];
      double pageHeight = 842.0;
      if (size != null) {
        pageHeight = size.height;
      } else if (controller.pageSizes.isNotEmpty) {
        pageHeight = controller.pageSizes.values.first.height;
      }
      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;
      bottomPlaceholderHeight += pageHeight * baseScale + 16.0;
    }
    if (bottomPlaceholderHeight > 0) {
      children.add(
        SizedBox(
          height: bottomPlaceholderHeight,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return Column(key: viewportKey, children: children);
  }
}
