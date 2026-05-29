# PDF Rendering Performance and High-Resolution Quality Fixes (v4.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the scroll/pan lag and flickering issues in the PDF viewer, and restore high-resolution page rendering to achieve a premium user experience comparable to GoodNotes and MarginNote.

**Architecture:** 
1. Page Virtualization: Refactor the PDF viewport in `lib/main.dart` to use `InteractiveCanvasViewer.builder` with a virtualized container, only instantiating visible pages and rendering empty placeholders for non-visible pages to reduce widget tree complexity.
2. High-Resolution Tile Rendering: Pass the visible viewport Quad down to page widgets and fix the coordinate mapping bug in `pdf_viewport_widget.dart` where `_highResRect` was incorrectly set to `visibleRect` instead of the actual `expandedVisibleRect` it was rendered for.

**Tech Stack:** Flutter, PDFium via Dart FFI

---

## User Review Required

> [!IMPORTANT]
> **Key Architecture Decisions:**
> 1. **Strict Page Virtualization**: We will replace the flat `Column` in [main.dart](file:///d:/starmind/lib/main.dart) with a virtualized pages container widget `_PdfTabPagesContainer` inside `lib/main.dart`. Pages that are scrolled out of the viewport (plus a 1-page buffer) will be replaced with placeholder `SizedBox`es of the identical heights, keeping the total document layout size and scrollbars stable while freeing memory and GPU resources.
> 2. **Correct Tile Coordinate Mapping**: The high-res tile image is rendered for `expandedVisibleRect` but was drawn inside the smaller `visibleRect` causing squashed distortion, offset shifts, and infinite rendering loops. Storing `expandedVisibleRect` as `_highResRect` and drawing the image there will align the high-res tile perfectly and allow the `_highResRect!.containsRect(visibleRect)` check to return early for small scrolls, preventing rendering queue flooding.

---

## Task 1: Fix High-Resolution Tile Coordinate Mapping

**Files:**
- Modify: [pdf_viewport_widget.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_viewport_widget.dart)

- [ ] **Step 1: Update high-resolution tile loading logic**
  
  In [pdf_viewport_widget.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_viewport_widget.dart), modify `_loadHighResTile` to:
  - Define `expandedVisibleRect` in the outer method scope.
  - Store `expandedVisibleRect` instead of `visibleRect` in `_highResRect` inside the `setState` callback when the image loads.
  
  ```dart
  // Location: lib/src/pdf/widgets/pdf_viewport_widget.dart in _loadHighResTile()
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
  
  // inside the scheduler build/setState:
  setState(() {
    _highResTile?.dispose();
    _highResTile = image;
    _highResRect = expandedVisibleRect; // Draw it at the actual expanded rect it represents!
    _highResZoom = zoom;
  });
  ```

- [ ] **Step 2: Verify compile correctness**
  
  Run: `flutter analyze`
  Expected: Success without warnings in `pdf_viewport_widget.dart`.

---

## Task 2: Implement Page Virtualization in main.dart

**Files:**
- Modify: [main.dart](file:///d:/starmind/lib/main.dart)

- [ ] **Step 1: Define `_PdfTabPagesContainer` inside `lib/main.dart`**
  
  Create a private stateful widget `_PdfTabPagesContainer` at the bottom of [main.dart](file:///d:/starmind/lib/main.dart) (or near `PdfTabViewport`) to calculate the visible page range and render only the visible pages plus a 1-page buffer, using placeholders for other pages.
  
  ```dart
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
        children.add(SizedBox(
          height: topPlaceholderHeight,
          child: const SizedBox.shrink(),
        ));
      }

      // Visible pages
      for (int i = firstVisible; i <= lastVisible; i++) {
        final isInkMode = activeTool == 'pen' || activeTool == 'highlight' || activeTool == 'eraser';
        final colorHex = '#${activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
        final size = controller.pageSizes[i];
        final double pdfWidth = size?.width ?? 595.0;
        final baseScale = viewportWidth / pdfWidth;

        final key = pageKeys.putIfAbsent(i, () => GlobalKey());

        children.add(Stack(
          key: key,
          children: [
            PdfPageWidget(
              pageIndex: i,
              controller: controller,
              viewport: viewport,
              viewportKey: viewportKey,
              viewportWidth: viewportWidth,
              transformationController: transformationController,
              isInkMode: isInkMode,
            ),
            if (activeTool == 'select')
              textSelectionLayerBuilder(i),
            if (activeTool == 'select' && controller.selection.selectingPageIndex == i)
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
                  annotationController: annotationController ?? AnnotationController.nullController,
                  pageIndex: i,
                  isInkMode: isInkMode,
                  palmRejectionEnabled: controller.transform.palmRejectionEnabled,
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
        ));
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
        children.add(SizedBox(
          height: bottomPlaceholderHeight,
          child: const SizedBox.shrink(),
        ));
      }

      return Column(
        key: viewportKey,
        children: children,
      );
    }
  }
  ```

- [ ] **Step 2: Update `PdfTabViewport` builder layout in `lib/main.dart`**
  
  In [main.dart](file:///d:/starmind/lib/main.dart), modify `InteractiveCanvasViewer` instantiation (around lines 3716-3808) to use `InteractiveCanvasViewer.builder` instead:
  
  ```dart
  // Before:
  /*
  child: InteractiveCanvasViewer(
    ...
    child: Column(
      children: List.generate(pdfCtrl.pageCount, (index) { ... })
    )
  )
  */

  // After:
  child: InteractiveCanvasViewer.builder(
    transformationController: _transformController,
    minScale: 0.1,
    maxScale: 16.0,
    panEnabled: true,
    scaleEnabled: true,
    boundaryMargin: const EdgeInsets.all(double.infinity),
    isDrawGesture: (details) {
      if (_palmRejectionEnabled && _lastPointerDeviceKind != PointerDeviceKind.stylus) {
        return false;
      }
      if (details.pointerCount >= 2) return false;
      return _activeTool == 'pen' || _activeTool == 'highlight' || _activeTool == 'eraser';
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
        textSelectionLayerBuilder: (index) => _buildTextSelectionLayer(index, pdfCtrl),
        selectionHandlesOverlayBuilder: (index) => _buildSelectionHandlesOverlay(index, pdfCtrl),
        pageAnnotationsBuilder: (index) => _buildPageAnnotations(index, pdfCtrl, _annotationController),
        pageKeys: _pageKeys,
      );
    },
  ),
  ```

- [ ] **Step 3: Verify static analysis and compilation**
  
  Run: `flutter analyze`
  Expected: Clean build without warnings.

---

## Verification Plan

### Automated Tests
- Run `flutter test` to ensure all existing unit tests pass:
  ```bash
  flutter test
  ```

### Manual Verification
- **Scroll/Pan Lag Check**: Load a medium/large PDF document. Drag and swipe to scroll the pages rapidly. Confirm scroll/pan transitions are completely buttery-smooth (60+ FPS) without any lag.
- **Flickering & Shaking Check**: Scroll/drag fast and release. Ensure pages move stably and there is absolutely no shifting or flashing of document content (neither during movement nor when stationary).
- **High-Resolution Zoom Check**: Zoom in on text and images (up to 1600%). Confirm that once zooming stops, the high-res tile renders and the document becomes extremely sharp, readable, and clear, with no pixelation/blurriness.
- **Handwriting and Selection Checks**: Try selecting text and drawing with the pen tool. Confirm that active selection handles, highlight boxes, and ink strokes align exactly with the document and draw smoothly.
