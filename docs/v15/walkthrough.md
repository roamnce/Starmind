# v15 Walkthrough

## Overview

v15 delivers the "MindMap Interaction Foundation" milestone, covering Phase 1-7 with complete selection, inline editing, layout switching, associative lines, summary nodes, node tags, and polish.

## Implemented Features

### Phase 1: Selection
- Drag-mode node tap selects exactly one node and synchronizes `selectedNote` with `selectedNoteIds`.
- `setInteractMode(drag)` preserves existing selection instead of clearing it.
- Blank-canvas tap deselection wired but blocked by InteractiveViewer gesture conflict (see Known Issues).

### Phase 2: Inline Editing
- Controller exposes `editingNoteId`, `beginEditing`, `commitEditing`, `cancelEditing`.
- Double-tap node enters inline title editing.
- Tab creates child node with default title `'新子节点'` and enters inline editing.
- Enter creates sibling node with default title `'新同级节点'` and enters inline editing.
- Escape cancels editing and restores previous/default title.
- Empty title submission restores the fallback title instead of deleting the node.
- Bottom action bar "Add Child" and "Add Sibling" buttons use inline creation.

### Phase 3: Layout Switching
- `LayoutDirection.left` correctly maps to `LayoutStrategy.leftOnly`.
- `changeLayoutDirection` is async and triggers `recalculateLayout()`.
- `changeLayoutStyle('framework')` switches to framework layout and persists.
- Topic-level `layoutDirection` and `layoutStyle` fields persist through FFI/Rust storage.
- Layout menu includes "框架式布局" option alongside direction items.

### Phase 4: Associative Lines (关联线)
- `MindMapRelation` domain model with control points.
- Repository CRUD with same-direction deduplication and cascade deletion.
- Rust storage with `mindmap_relations` table.
- Controller: `RelationCreationMode`, `startRelationCreation`, `handleNodeTapForRelationTarget`.
- Canvas painter: bezier curve rendering with arrowheads.
- `RelationLabelWidget`: tap to select, double-tap to edit.
- Bottom action bar "关联线" button wired.

### Phase 5: Summary Nodes (概要)
- `MindMapSummary` domain model with range normalization.
- Repository CRUD with duplicate range prevention and cascade deletion.
- `MindMapService.createSummariesFromSelectedNoteIds`: groups by parent, creates contiguous ranges.
- Controller: `summaries`, `createSummariesFromSelection`, `updateSummaryText`, `deleteSummary`.
- Canvas painter: orthogonal bracket lines with text labels.
- Summary brackets follow layout direction (right/left/both sides).
- Bottom action bar "创建概要" button wired.

### Phase 6: Node Tags (节点标签)
- `TagNode` FFI type from Rust storage.
- Repository: `bindTagToNote`, `unbindTagFromNote`, `listTagIdsForNote`, `getTagTree`, `createTag`.
- Controller: `tagsByNoteId` (complete TagNode objects), `bindTagToSelectedNode`, `unbindTagFromNode`.
- `NodeTagPicker` overlay with text input and bound tag chips.
- `NodeWidget` displays tag chips (up to 3) on nodes.
- Auto-creates tags by name with hash-based colors.
- Bottom action bar "创建标签" button toggles picker visibility.

### Phase 7: Polish & Regression
- Tag display loads complete `TagNode` objects with `name` field.
- Summary bracket rendering with orthogonal lines and text labels.
- Import/export supports relations, summaries, and node tags.
- Deletion cascades to relations, summaries, and tag bindings.

## Verification

```bash
# Full regression
flutter test test/mindmap/

# Storage tests (17 pass)
flutter test test/mindmap/storage/mindmap_repository_test.dart

# Static analysis
flutter analyze lib/src/mindmap/

# Rust check
cargo check --manifest-path rust/Cargo.toml
```

## Known Issues

See `known_issues.md` for details.

## Architecture Notes

- Domain models in `lib/src/mindmap/domain/`
- Repository pattern: `MindMapRepository` interface with `FfiMindMapRepository` and `InMemoryMindMapRepository`
- Controller: `MindMapController` manages UI state, relations, summaries, tags
- Canvas painter: `MindMapCanvasPainter` renders connections, associative lines, summary brackets
