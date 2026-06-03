# Tasks

- [x] Modify `pdf_annotation_integration.dart` to position drawing/annotation layers at `top: 8.0, bottom: 8.0`
- [x] Define `pageVerticalMargin` shared constant in `PdfPageWidget`
- [x] Modify `main.dart` to update the gesture layers:
  - [x] Remove `isDrawGesture` override for `select` mode in `InteractiveCanvasViewer`
  - [x] Replace `Listener` with `GestureDetector` in `_buildTextSelectionLayer` with long-press and tap gestures
  - [x] Position `_buildTextSelectionLayer` at `top: pageVerticalMargin, bottom: pageVerticalMargin`
  - [x] Position `_buildSelectionHandlesOverlay` at `top: pageVerticalMargin, bottom: pageVerticalMargin`
  - [x] Offset toolbar calculation by `pageVerticalMargin` in `_buildTextSelectionLayer` and `_buildSelectionHandlesOverlay`
  - [x] Clean up unused state fields (`_longPressTimer`, `_longPressStartPos`, `_isCustomSelecting`)
- [x] Verify using analyzer and running existing tests
- [x] Update walkthrough
