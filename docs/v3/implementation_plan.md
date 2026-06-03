# PDF Text Selection Gesture and Layout Alignment Fixes (v3.1)

This plan details the changes required to resolve the issue where single-finger scrolling is disabled in selection mode, and precise text selection via long-press fails due to a vertical margin misalignment.

## User Review Required

> [!IMPORTANT]
> **Key Gesture & Layout Decisions:**
> 1. **Restore Viewport Scrolling**: We will remove the custom `isDrawGesture` override for `select` mode in `InteractiveCanvasViewer`. This returns single-finger dragging to the default viewport scrolling behavior.
> 2. **Standard GestureDetector for Selection**: We will replace the raw `Listener` in `_buildTextSelectionLayer` with a standard `GestureDetector` (using `onLongPressStart`, `onLongPressMoveUpdate`, `onLongPressEnd`, and `onTap`). This lets the Flutter gesture arena cleanly resolve conflicts: immediate dragging scrolls the page, while holding still triggers text selection.
> 3. **Page-Local Layout Margin Offset (8.0px)**: All overlay layers (gestures, handles, ink drawings, and annotation rendering) will be positioned using `Positioned(top: 8.0, bottom: 8.0, left: 0.0, right: 0.0)` rather than `Positioned.fill`. This matches the `margin: const EdgeInsets.symmetric(vertical: 8.0)` of the PDF page widget, ensuring perfect 1:1 alignment between coordinates, visual annotations, handles, and text selection highlights.

## Proposed Changes

### 1. Viewport Gestures & Page Selection Layer

#### [MODIFY] [main.dart](file:///d:/starmind/lib/main.dart)
- Update `InteractiveCanvasViewer`'s `isDrawGesture` to return `false` for `_activeTool == 'select'` (remove the pointerCount == 1 override).
- Modify `_buildTextSelectionLayer` to return a `Positioned(top: 8.0, bottom: 8.0, left: 0, right: 0, ...)` containing a `GestureDetector`:
  - `onLongPressStart`: Calls `pdfCtrl.startSelection(pageIndex, pdfPoint)`.
  - `onLongPressMoveUpdate`: Calls `pdfCtrl.updateSelection(pdfPoint)`.
  - `onLongPressEnd`: Computes the top-most boundary of selection rectangles, maps `Offset(left, minY + 8.0)` to global space, and calls `pdfCtrl.endSelection(globalToolbarPos)`.
  - `onTap`: Calls `pdfCtrl.clearSelection()` to dismiss active selection on tap.
- Position `_buildSelectionHandlesOverlay(index, pdfCtrl)` at `top: 8.0, bottom: 8.0` inside the main page stack.
- In `_buildSelectionHandlesOverlay`'s `onDragEnd` callback, offset `minY` by `8.0` pixels when converting to global coordinate space: `Offset(left, minY + 8.0)`.
- Remove unused fields: `_longPressTimer`, `_longPressStartPos`, and `_isCustomSelecting`.

### 2. Ink Drawing and Annotation Overlay Alignment

#### [MODIFY] [pdf_annotation_integration.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_annotation_integration.dart)
- Update `buildInkDrawingLayer` to return a `Positioned` widget with `top: 8.0, bottom: 8.0, left: 0.0, right: 0.0` instead of `Positioned.fill`.
- Update `buildAnnotationRenderer` to return a `Positioned` widget with `top: 8.0, bottom: 8.0, left: 0.0, right: 0.0` instead of `Positioned.fill`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no compiler warnings.
- Run `flutter test` to verify no regressions in viewport transform or annotation controller logic.

### Manual Verification
- **Smooth Panning**: Drag immediately with a single finger in select mode, and confirm the document pans/scrolls smoothly.
- **Precise Selection**: Press and hold on selectable text in a PDF, and verify it selects the exact characters under the finger.
- **Overlay Alignment**: Drag selection handles and apply highlights, confirming that selection rectangles, preset color highlighters, and handles align 1:1 vertically with the PDF text.
- **Dismiss Selection**: Tap anywhere on the page outside the active selection and verify the toolbar and highlights are dismissed.
