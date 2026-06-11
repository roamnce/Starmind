# v15 Known Issues

## Phase 1-3

- Framework layout is now selected from topic-level layout state (`controller.layoutStyle`). Legacy `Note.layoutStyle` is retained only for imported/historical node data and must not be used as the active whole-map UI switch.
- InteractiveViewer wraps the entire canvas and intercepts tap gestures, preventing blank-canvas deselection and node-tap selection from working in widget tests. This requires gesture disambiguation (e.g., wrapping InteractiveViewer with a GestureDetector that defers to children) to resolve.
- FFI storage tests for Topic CRUD fail when the Rust DLL is stale. After modifying Rust struct fields, run `flutter_rust_bridge_codegen generate`, `cargo build --release`, and `flutter clean` before running FFI tests.

## Phase 4-6

- Tag picker creates tags by name; full tag tree management UI is a future enhancement.
- Relation label positioning is approximate; may need refinement for complex layouts.
- Framework-internal summaries are not supported. Normal tree summaries and framework outer-level summaries are supported.
- Relation control-point dragging is limited to selected relation handles in the current canvas coordinate system. Rich bezier handle editing can be expanded after Phase 7 regression hardening.

## Phase 7 Status

### Completed

- **Tag display**: `NodeWidget` and `NodeTagPicker` now display `tag.name` from complete `TagNode` objects.
- **Tag binding tests**: 5 new tests in `mindmap_repository_test.dart` covering bind/unbind/cascade operations.
- **Summary rendering**: `MindMapCanvasPainter` renders orthogonal bracket lines with text labels following layout direction.
- **Documentation**: `walkthrough.md` updated with Phase 5-7 features.

### Fixed

- **Import wiring**: `GuruMindImporter` now calls `relationsFromDocument`, `summariesFromDocument`, `noteTagNamesFromDocument` to persist v15 data on import.
- **Export service**: `MindMapService.exportGuruMindTopic` now includes relations, summaries, and node tags in the exported archive.
- **Summary bracket direction**: `bothSides` layout now checks node x-position to determine bracket direction (left-side children get left-facing brackets).

### Remaining Enhancements (Post-v15)

- Full tag picker with existing tag list autocomplete.
- Import/export round-trip tests for relations, summaries, and node tags.
- Keyboard shortcut consistency checks across v15 features.
- Summary bracket click-to-select and edit interaction.
- `Note.layoutStyle` is not persisted in the Rust DB (legacy field, framework mode uses Topic-level `layoutStyle`).
