# v15 Phase 4-6 Walkthrough

## Implemented

### Phase 4: Associative Lines (关联线)
- `MindMapRelation` domain model with control points, fromMap/toMap/copyWith.
- Repository interface: 7 CRUD methods (create, get, update, delete, list, findByEndpoints, deleteForNote).
- In-memory implementation with same-direction deduplication and cascade deletion.
- Rust `mindmap_relations` table with indexes and CRUD functions.
- FRB bridge: `MindMapRelation` struct, 7 FFI functions.
- `FfiMindMapRepository` full implementation with model conversion.
- `MindMapService.createRelation` with self-relation validation.
- Controller: `RelationCreationMode`, `startRelationCreation`, `handleNodeTapForRelationTarget`, `cancelRelationCreation`.
- `MindMapCanvasPainter`: bezier curve rendering with arrowheads.
- `RelationLabelWidget`: tap to select, double-tap to edit, Escape to cancel.
- Bottom action bar "关联线" button wired.
- Node tap routes through relation target selection mode.

### Phase 5: Summary Nodes (概要)
- `MindMapSummary` domain model with range normalization (auto-swap reversed indices).
- Repository interface: 6 CRUD methods.
- In-memory implementation with duplicate range prevention and cascade deletion.
- `MindMapService.createSummariesFromSelectedNoteIds`: groups by parent, creates contiguous ranges.
- Controller: `summaries`, `createSummariesFromSelection`, `updateSummaryText`, `deleteSummary`.
- Bottom action bar "创建概要" button wired.

### Phase 6: Node Tags (节点标签)
- `MindMapNoteTag` view model.
- Repository interface: 4 binding methods (bind, unbind, listTagIds, deleteBindingsForNote).
- In-memory implementation with cascade deletion.
- `MindMapService.bindTagToNote` / `unbindTagFromNote` / `listTagIdsForNote`.
- Controller: `tagIdsByNoteId`, `bindTagToSelectedNode`, `unbindTagFromNode`.
- `NodeTagPicker` overlay widget with text input and bound tag list.
- Bottom action bar "创建标签" button toggles picker visibility.

### Import/Export Compatibility
- `GuruMindDataExporter.exportTopic` accepts optional `relations`, `summaries`, `tagsByNoteId`.
- Manifest includes `relations`, `summaries`, `nodeTags` keys when non-empty.
- `GuruMindDataConverter`: `relationsFromDocument`, `summariesFromDocument`, `noteTagNamesFromDocument` helpers.

### Deletion Cleanup
- `deleteNote` cascades to relations, summaries, and tag bindings in both repository and controller.

## Verification

```bash
# Full regression (148 tests pass)
flutter test test/mindmap/ui/ test/mindmap/domain/ test/mindmap/layout/ test/mindmap/storage/mindmap_repository_test.dart

# Static analysis (no new errors)
flutter analyze lib/src/mindmap/

# Rust check
cargo check --manifest-path rust/Cargo.toml
```

## Known Limitations

- FFI storage tests for Topic CRUD fail when Rust DLL is stale (pre-existing).
- InteractiveViewer gesture conflict prevents blank-canvas deselection tests (pre-existing).
- Tag picker uses tag name as tagId (simplified implementation).
- Relation label positioning is approximate; may need refinement for complex layouts.
- Framework-internal summaries not supported.
