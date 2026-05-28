# PDF Text Selection, Highlights and Interactive Handles (v3)

This plan details the implementation of text selection, interactive drag handles (indicators), and a premium floating toolbar with customizable preset colors and a color picker popover, matching commercial apps like GoodNotes and MarginNote.

## User Review Required

> [!IMPORTANT]
> **Key Architecture Decisions:**
> 1. **Page-Local Coordinate Alignment**: Draggable selection handles will be rendered inside each page's stack in page-local coordinates. This ensures they automatically scale and pan with the PDF view without manual repositioning math.
> 2. **Real-time Selection Updates**: Dragging the handles will trigger real-time character-index updates in the controller, causing the selected text overlay to redraw instantly.
> 3. **Popup Color Picker Popover**: The palette button will trigger a lightweight Overlay-based popup next to the toolbar rather than a modal dialog, keeping the reading flow uninterrupted.
> 4. **DB Persistence Integration**: When a highlight or underline is created, it will be saved to the SQLite database via `AnnotationController` and rendered using `buildAnnotationRenderer`.

---

## Proposed Changes

### 1. Domain & Controller Extensions

#### [MODIFY] [text_selection_model.dart](file:///d:/starmind/lib/src/pdf/text_selection_model.dart)
- Make `_findClosestChar` public (rename to `findClosestChar`).
- Add public methods:
  - `updateStartCharIndex(int index)`: Updates selection start index and notifies listeners.
  - `updateEndCharIndex(int index)`: Updates selection end index and notifies listeners.

#### [MODIFY] [pdf_viewport_controller.dart](file:///d:/starmind/lib/src/pdf/pdf_viewport_controller.dart)
- Expose methods:
  - `void updateSelectionStart(int charIndex)`
  - `void updateSelectionEnd(int charIndex)`

---

### 2. Selection Handles UI

#### [MODIFY] [selection_handles_overlay.dart](file:///d:/starmind/lib/src/pdf/widgets/selection_handles_overlay.dart)
- Update `SelectionHandlesOverlay` to take `startLineHeight`, `endLineHeight` and a callback `onDragEnd`.
- Update start handle: vertical line of height `startLineHeight` with a round touch ball at the **top**.
- Update end handle: vertical line of height `endLineHeight` with a round touch ball at the **bottom**.
- Wrap the handles in touch-friendly hit areas to ensure smooth, responsive dragging.

---

### 3. Floating Toolbar & Color Picker Popover

#### [MODIFY] [text_selection_overlay.dart](file:///d:/starmind/lib/src/pdf/widgets/text_selection_overlay.dart)
- Redesign `PdfSelectionToolbar` with a premium glassmorphic UI matching the Starmind dark aesthetic.
- Include action buttons: **Highlight** and **Underline**.
- Include **4 preset color circles** (persisted using `SharedPreferences`).
- Include a **Palette button** (opens inline color picker popover).
- Support interactions:
  - Clicking a preset color immediately highlights the text with that color and closes selection.
  - Clicking "Highlight" or "Underline" creates the corresponding annotation with the current active color.
  - Long-pressing a preset color opens the color picker, and choosing a color updates that preset color persistently.
- Implement the inline **Color Picker Popover** using `Overlay` to show a clean grid of pastel/highlight colors and custom color sliders next to the toolbar.

---

### 4. Rendering & Persistence Integration

#### [MODIFY] [pdf_annotation_integration.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_annotation_integration.dart)
- Modify `buildAnnotationRenderer` to accept an optional `AnnotationController`.
- Query and render persistent annotations from `_annotationController.annotationsForPage(pageIndex)` along with the legacy transient controller highlights.

#### [MODIFY] [main.dart](file:///d:/starmind/lib/main.dart)
- Declare `_pageKeys` map to track keys for each page stack.
- Render `SelectionHandlesOverlay` for the active selection page.
- When dragging handles, update start/end selection indices and calculate the topmost selection boundary to place the toolbar perfectly above it.
- Wire up toolbar actions to write highlights and underlines directly to `_annotationController` for DB persistence.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no lint warnings or type errors.
- Add unit tests in `test/pdf/text_selection_test.dart` to verify selection handle drag updates.

### Manual Verification
- **Text Selection**: Long press to select text, drag start and end handles, verify the selected text highlights in real-time.
- **Floating Toolbar**: Verify the toolbar pops up above the selection.
- **Preset Colors**: Click a preset to highlight, verify it saves to DB and persists after hot restart.
- **Color Customization**: Long press a preset color, pick a new color from the popover picker, verify the preset changes and persists.
