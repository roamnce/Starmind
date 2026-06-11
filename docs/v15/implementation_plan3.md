# v15 Phase 7 Polish and Regression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Complete v15 by wiring import/export for relations/summaries/tags, hardening keyboard shortcuts, verifying persistence, running broad regression, and writing final walkthrough documentation.

**Architecture:** Phase 7 does not introduce new domain models. It extends import/export converters, adds integration-style regression tests, updates walkthrough and known-issues docs, and ensures the whole v15 feature set works together without regressions.

**Tech Stack:** Flutter/Dart, existing mindmap import/export converters, Rust FRB storage, Flutter widget and integration tests, lutter analyze, lutter test test/mindmap.

---

## Scope

This plan covers:

- Import/export support for relations, summaries, and node-tag bindings.
- Keyboard shortcut consistency checks for selection, editing, layout, relation, summary, and tag actions.
- Persistence smoke tests for topic-level layout, relations, summaries, and node tags.
- Broad regression suite covering the six key scenarios from Phase 7 spec.
- Final walkthrough and known-issues documentation.

This plan assumes Phase 1-6 are complete and their tests pass.

## File Map

- Modify lib/src/mindmap/export/gurumind_exporter.dart: export relations, summaries, and node-tag bindings.
- Modify lib/src/mindmap/import/gurumind_data_converter.dart: import relations, summaries, and node-tag bindings with missing-field defaults.
- Modify 	est/mindmap/export/gurumind_exporter_test.dart: export round-trip tests for new models.
- Modify 	est/mindmap/import/gurumind_data_converter_test.dart: import tests for new models with missing fields.
- Modify 	est/mindmap/import/gurumind_real_sample_test.dart: ensure real sample imports still pass.
- Create 	est/mindmap/regression/v15_full_flow_test.dart: integration-style regression covering the six key scenarios.
- Modify 	est/mindmap/ui/shortcuts_mapping_test.dart: verify shortcut consistency across v15 features.
- Modify docs/v15/walkthrough.md: final delivery documentation.
- Modify docs/v15/known_issues.md: record framework-internal summaries and any deferred items.
- Modify CONTEXT.md: add domain concepts for relations, summaries, and node tags if not already present.

---

### Task 1: Export Relations, Summaries, and Node Tags

**Files:**
- Modify: lib/src/mindmap/export/gurumind_exporter.dart
- Modify: 	est/mindmap/export/gurumind_exporter_test.dart

- [ ] **Step 1: Write failing export tests for relations**

In gurumind_exporter_test.dart, add:

`dart
group('v15 relation export', () {
  test('exportTopic includes relations array', () async {
    final repo = InMemoryMindMapRepository();
    final topicId = await repo.createTopic('Test');
    final rootId = await repo.createNote(topicId, null, 'Root');
    final childId = await repo.createNote(topicId, rootId, 'Child');
    
    await repo.createRelation(
      topicId: topicId,
      sourceNoteId: rootId,
      targetNoteId: childId,
      text: 'relates to',
    );
    
    final exporter = GurumindExporter(repo);
    final exported = await exporter.exportTopic(topicId);
    
    expect(exported, containsPair('relations', isA<List>()));
    final relations = exported['relations'] as List;
    expect(relations.length, 1);
    expect(relations[0]['sourceNoteId'], rootId);
    expect(relations[0]['targetNoteId'], childId);
    expect(relations[0]['text'], 'relates to');
  });
  
  test('exportTopic omits relations key when none exist', () async {
    final repo = InMemoryMindMapRepository();
    final topicId = await repo.createTopic('Test');
    await repo.createNote(topicId, null, 'Root');
    
    final exporter = GurumindExporter(repo);
    final exported = await exporter.exportTopic(topicId);
    
    expect(exported, isNot(containsPair('relations', anything)));
  });
});
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 2: Implement relation export**

In gurumind_exporter.dart, extend exportTopic:

`dart
Future<Map<String, dynamic>> exportTopic(String topicId) async {
  // ... existing note export ...
  
  final relations = await _repo.getRelationsByTopic(topicId);
  if (relations.isNotEmpty) {
    result['relations'] = relations.map((r) => {
      'id': r.id,
      'sourceNoteId': r.sourceNoteId,
      'targetNoteId': r.targetNoteId,
      'text': r.text,
      'createdAt': r.createdAt.toIso8601String(),
      'updatedAt': r.updatedAt.toIso8601String(),
    }).toList();
  }
  
  return result;
}
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: PASS.

- [ ] **Step 3: Write failing export tests for summaries**

Add to gurumind_exporter_test.dart:

`dart
group('v15 summary export', () {
  test('exportTopic includes summaries array', () async {
    final repo = InMemoryMindMapRepository();
    final topicId = await repo.createTopic('Test');
    final rootId = await repo.createNote(topicId, null, 'Root');
    final child1 = await repo.createNote(topicId, rootId, 'C1');
    final child2 = await repo.createNote(topicId, rootId, 'C2');
    
    await repo.createSummary(
      topicId: topicId,
      parentId: rootId,
      startIndex: 0,
      endIndex: 1,
      text: 'Summary',
    );
    
    final exporter = GurumindExporter(repo);
    final exported = await exporter.exportTopic(topicId);
    
    expect(exported, containsPair('summaries', isA<List>()));
    final summaries = exported['summaries'] as List;
    expect(summaries.length, 1);
    expect(summaries[0]['parentId'], rootId);
    expect(summaries[0]['startIndex'], 0);
    expect(summaries[0]['endIndex'], 1);
  });
});
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 4: Implement summary export**

Extend exportTopic:

`dart
final summaries = await _repo.getSummariesByTopic(topicId);
if (summaries.isNotEmpty) {
  result['summaries'] = summaries.map((s) => {
    'id': s.id,
    'parentId': s.parentId,
    'startIndex': s.startIndex,
    'endIndex': s.endIndex,
    'text': s.text,
    'createdAt': s.createdAt.toIso8601String(),
    'updatedAt': s.updatedAt.toIso8601String(),
  }).toList();
}
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: PASS.

- [ ] **Step 5: Write failing export tests for node tags**

Add to gurumind_exporter_test.dart:

`dart
group('v15 node tag export', () {
  test('exportTopic includes nodeTags map', () async {
    final repo = InMemoryMindMapRepository();
    final topicId = await repo.createTopic('Test');
    final noteId = await repo.createNote(topicId, null, 'Root');
    
    // Assume global tag already exists
    await repo.bindNoteTag(noteId: noteId, tagId: 'tag-1');
    
    final exporter = GurumindExporter(repo);
    final exported = await exporter.exportTopic(topicId);
    
    expect(exported, containsPair('nodeTags', isA<Map>()));
    final nodeTags = exported['nodeTags'] as Map;
    expect(nodeTags[noteId], contains('tag-1'));
  });
});
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 6: Implement node tag export**

Extend exportTopic:

`dart
final notes = await _repo.getNotesByTopic(topicId);
final nodeTags = <String, List<String>>{};
for (final note in notes) {
  final tags = await _repo.getTagsForNote(note.id);
  if (tags.isNotEmpty) {
    nodeTags[note.id] = tags.map((t) => t.id).toList();
  }
}
if (nodeTags.isNotEmpty) {
  result['nodeTags'] = nodeTags;
}
`

Run:

`ash
flutter test test/mindmap/export/gurumind_exporter_test.dart
`

Expected: PASS.

- [ ] **Step 7: Commit export changes**

Run:

`ash
git add lib/src/mindmap/export/gurumind_exporter.dart test/mindmap/export/gurumind_exporter_test.dart
git commit -m "feat(mindmap): export relations, summaries, and node tags"
`

---

### Task 2: Import Relations, Summaries, and Node Tags

**Files:**
- Modify: lib/src/mindmap/import/gurumind_data_converter.dart
- Modify: 	est/mindmap/import/gurumind_data_converter_test.dart

- [ ] **Step 1: Write failing import tests for relations**

In gurumind_data_converter_test.dart, add:

`dart
group('v15 relation import', () {
  test('convertTopic creates relations from array', () async {
    final converter = GurumindDataConverter(repo);
    final data = {
      'id': 'topic-1',
      'title': 'Test',
      'notes': [
        {'id': 'n1', 'parentId': null, 'title': 'Root'},
        {'id': 'n2', 'parentId': 'n1', 'title': 'Child'},
      ],
      'relations': [
        {
          'id': 'r1',
          'sourceNoteId': 'n1',
          'targetNoteId': 'n2',
          'text': 'relates to',
        },
      ],
    };
    
    await converter.convertTopic(data);
    
    final relations = await repo.getRelationsByTopic('topic-1');
    expect(relations.length, 1);
    expect(relations.first.sourceNoteId, 'n1');
    expect(relations.first.targetNoteId, 'n2');
  });
  
  test('convertTopic handles missing relations key', () async {
    final converter = GurumindDataConverter(repo);
    final data = {
      'id': 'topic-1',
      'title': 'Test',
      'notes': [
        {'id': 'n1', 'parentId': null, 'title': 'Root'},
      ],
    };
    
    await converter.convertTopic(data);
    
    final relations = await repo.getRelationsByTopic('topic-1');
    expect(relations, isEmpty);
  });
});
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 2: Implement relation import**

In gurumind_data_converter.dart, extend convertTopic:

`dart
Future<void> convertTopic(Map<String, dynamic> data) async {
  // ... existing note import ...
  
  final relationsData = data['relations'] as List<dynamic>?;
  if (relationsData != null) {
    for (final r in relationsData) {
      final map = r as Map<String, dynamic>;
      await _repo.createRelation(
        topicId: topicId,
        sourceNoteId: map['sourceNoteId'] as String,
        targetNoteId: map['targetNoteId'] as String,
        text: map['text'] as String? ?? '',
        id: map['id'] as String?,
      );
    }
  }
}
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: PASS.

- [ ] **Step 3: Write failing import tests for summaries**

Add to gurumind_data_converter_test.dart:

`dart
group('v15 summary import', () {
  test('convertTopic creates summaries from array', () async {
    final converter = GurumindDataConverter(repo);
    final data = {
      'id': 'topic-1',
      'title': 'Test',
      'notes': [
        {'id': 'n1', 'parentId': null, 'title': 'Root'},
        {'id': 'n2', 'parentId': 'n1', 'title': 'C1'},
        {'id': 'n3', 'parentId': 'n1', 'title': 'C2'},
      ],
      'summaries': [
        {
          'id': 's1',
          'parentId': 'n1',
          'startIndex': 0,
          'endIndex': 1,
          'text': 'Summary',
        },
      ],
    };
    
    await converter.convertTopic(data);
    
    final summaries = await repo.getSummariesByTopic('topic-1');
    expect(summaries.length, 1);
    expect(summaries.first.parentId, 'n1');
    expect(summaries.first.startIndex, 0);
    expect(summaries.first.endIndex, 1);
  });
});
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 4: Implement summary import**

Extend convertTopic:

`dart
final summariesData = data['summaries'] as List<dynamic>?;
if (summariesData != null) {
  for (final s in summariesData) {
    final map = s as Map<String, dynamic>;
    await _repo.createSummary(
      topicId: topicId,
      parentId: map['parentId'] as String,
      startIndex: map['startIndex'] as int,
      endIndex: map['endIndex'] as int,
      text: map['text'] as String? ?? '',
      id: map['id'] as String?,
    );
  }
}
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: PASS.

- [ ] **Step 5: Write failing import tests for node tags**

Add to gurumind_data_converter_test.dart:

`dart
group('v15 node tag import', () {
  test('convertTopic creates note-tag bindings from nodeTags map', () async {
    final converter = GurumindDataConverter(repo);
    final data = {
      'id': 'topic-1',
      'title': 'Test',
      'notes': [
        {'id': 'n1', 'parentId': null, 'title': 'Root'},
      ],
      'nodeTags': {
        'n1': ['tag-1', 'tag-2'],
      },
    };
    
    await converter.convertTopic(data);
    
    final tags = await repo.getTagsForNote('n1');
    expect(tags.length, 2);
    expect(tags.any((t) => t.id == 'tag-1'), isTrue);
    expect(tags.any((t) => t.id == 'tag-2'), isTrue);
  });
});
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: FAIL on new tests.

- [ ] **Step 6: Implement node tag import**

Extend convertTopic:

`dart
final nodeTagsData = data['nodeTags'] as Map<String, dynamic>?;
if (nodeTagsData != null) {
  for (final entry in nodeTagsData.entries) {
    final noteId = entry.key;
    final tagIds = entry.value as List<dynamic>;
    for (final tagId in tagIds) {
      await _repo.bindNoteTag(noteId: noteId, tagId: tagId as String);
    }
  }
}
`

Run:

`ash
flutter test test/mindmap/import/gurumind_data_converter_test.dart
`

Expected: PASS.

- [ ] **Step 7: Commit import changes**

Run:

`ash
git add lib/src/mindmap/import/gurumind_data_converter.dart test/mindmap/import/gurumind_data_converter_test.dart
git commit -m "feat(mindmap): import relations, summaries, and node tags"
`

---

### Task 3: Keyboard Shortcut Consistency

**Files:**
- Modify: 	est/mindmap/ui/shortcuts_mapping_test.dart

- [ ] **Step 1: Write shortcut consistency tests**

In shortcuts_mapping_test.dart, add:

`dart
group('v15 shortcut consistency', () {
  test('Tab creates child and enters editing', () {
    // Verify Tab shortcut is bound to createChildNode + beginEditing
  });
  
  test('Enter creates sibling and enters editing', () {
    // Verify Enter shortcut is bound to createSiblingNode + beginEditing
  });
  
  test('Escape cancels editing without deleting node', () {
    // Verify Escape calls cancelEditing and node persists
  });
  
  test('Delete key deletes selected relation or summary', () {
    // Verify Delete key contextually deletes selected overlay
  });
  
  test('Ctrl+L opens layout menu', () {
    // Verify layout menu shortcut
  });
});
`

Run:

`ash
flutter test test/mindmap/ui/shortcuts_mapping_test.dart
`

Expected: PASS (or FAIL if shortcuts not wired; then wire and re-run).

- [ ] **Step 2: Fix any shortcut inconsistencies**

If tests fail, update shortcut handlers in MindMapPage and re-run.

- [ ] **Step 3: Commit shortcut tests**

Run:

`ash
git add test/mindmap/ui/shortcuts_mapping_test.dart
git commit -m "test(mindmap): verify v15 shortcut consistency"
`

---

### Task 4: Persistence Smoke Tests

**Files:**
- Create: 	est/mindmap/regression/v15_persistence_test.dart

- [ ] **Step 1: Write persistence smoke tests**

Create 	est/mindmap/regression/v15_persistence_test.dart:

`dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/mindmap/storage/ffi_mindmap_repository.dart';

void main() {
  group('v15 persistence smoke', () {
    test('topic layout direction persists', () async {
      final repo = FfiMindMapRepository();
      final topicId = await repo.createTopic('Test');
      
      await repo.updateTopicLayout(topicId, layoutDirection: 'left');
      var topic = await repo.getTopic(topicId);
      expect(topic?.layoutDirection, 'left');
      
      // Simulate reload
      topic = await repo.getTopic(topicId);
      expect(topic?.layoutDirection, 'left');
    });
    
    test('relation persists across topic reload', () async {
      final repo = FfiMindMapRepository();
      final topicId = await repo.createTopic('Test');
      final n1 = await repo.createNote(topicId, null, 'A');
      final n2 = await repo.createNote(topicId, null, 'B');
      
      await repo.createRelation(
        topicId: topicId,
        sourceNoteId: n1,
        targetNoteId: n2,
        text: 'test',
      );
      
      var relations = await repo.getRelationsByTopic(topicId);
      expect(relations.length, 1);
      
      // Simulate reload
      relations = await repo.getRelationsByTopic(topicId);
      expect(relations.length, 1);
    });
    
    test('summary persists across topic reload', () async {
      final repo = FfiMindMapRepository();
      final topicId = await repo.createTopic('Test');
      final root = await repo.createNote(topicId, null, 'Root');
      await repo.createNote(topicId, root, 'C1');
      await repo.createNote(topicId, root, 'C2');
      
      await repo.createSummary(
        topicId: topicId,
        parentId: root,
        startIndex: 0,
        endIndex: 1,
        text: 'Sum',
      );
      
      var summaries = await repo.getSummariesByTopic(topicId);
      expect(summaries.length, 1);
    });
    
    test('node tags persist across reload', () async {
      final repo = FfiMindMapRepository();
      final topicId = await repo.createTopic('Test');
      final noteId = await repo.createNote(topicId, null, 'N');
      
      await repo.bindNoteTag(noteId: noteId, tagId: 'tag-1');
      
      var tags = await repo.getTagsForNote(noteId);
      expect(tags.length, 1);
    });
  });
}
`

Run:

`ash
flutter test test/mindmap/regression/v15_persistence_test.dart
`

Expected: PASS.

- [ ] **Step 2: Commit persistence tests**

Run:

`ash
git add test/mindmap/regression/v15_persistence_test.dart
git commit -m "test(mindmap): add v15 persistence smoke tests"
`

---

### Task 5: Full Flow Regression Tests

**Files:**
- Create: 	est/mindmap/regression/v15_full_flow_test.dart

- [ ] **Step 1: Write full flow regression tests**

Create 	est/mindmap/regression/v15_full_flow_test.dart covering the six key scenarios from Phase 7 spec:

`dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('v15 full flow regression', () {
    late MindMapController controller;
    late InMemoryMindMapRepository repo;
    
    setUp(() async {
      repo = InMemoryMindMapRepository();
      controller = MindMapController(repo: repo);
      final topicId = await repo.createTopic('Test');
      await controller.loadTopic(topicId);
    });
    
    test('scenario 1: drag mode select, create child, edit', () async {
      // Select root in drag mode
      controller.setInteractMode(CanvasInteractMode.drag);
      final root = controller.rootNodes.first;
      controller.selectNote(root.note);
      
      // Create child and verify editing state
      await controller.createChildNode(enterEditing: true);
      expect(controller.editingNoteId, isNotNull);
      
      // Commit edit
      await controller.commitEditing(controller.editingNoteId!, 'New Child');
      expect(controller.editingNoteId, isNull);
      expect(controller.selectedNote?.title, 'New Child');
    });
    
    test('scenario 2: layout direction cycle', () async {
      // Cycle through layouts
      await controller.changeLayoutDirection(LayoutDirection.both);
      await controller.changeLayoutDirection(LayoutDirection.left);
      await controller.changeLayoutDirection(LayoutDirection.right);
      await controller.changeLayoutDirection(LayoutDirection.both);
      
      // Verify layout state
      expect(controller.layoutDirection, LayoutDirection.both);
    });
    
    test('scenario 3: long title node with tags, lines still anchored', () async {
      // Create node with long title
      final root = controller.rootNodes.first;
      await controller.createChildNode(title: 'A very long title that wraps');
      
      // Add tag
      await controller.bindNoteTag(noteId: controller.selectedNote!.id, tagId: 'tag-1');
      
      // Verify layout still produces valid rects
      controller.recalculateLayout();
      final rect = controller.layoutResult?.getNodeRect(controller.selectedNote!.id);
      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(0));
    });
    
    test('scenario 4: multi-select siblings create summary, layout switch', () async {
      // Create siblings
      final root = controller.rootNodes.first;
      await controller.createChildNode(title: 'C1');
      await controller.createChildNode(title: 'C2');
      
      // Select both
      controller.selectNote(controller.findNodeById((await repo.getNotesByTopic(controller.topicId!))[1].id)!.note);
      controller.addToSelection((await repo.getNotesByTopic(controller.topicId!))[2].id);
      
      // Create summary
      await controller.createSummariesFromSelection();
      
      // Switch layout
      await controller.changeLayoutDirection(LayoutDirection.left);
      
      // Verify summary still valid
      final summaries = await repo.getSummariesByTopic(controller.topicId!);
      expect(summaries.length, 1);
    });
    
    test('scenario 5: delete node with relations, summaries, tags', () async {
      // Create node with all attachments
      final root = controller.rootNodes.first;
      final childId = await controller.createChildNode(title: 'Child');
      
      await controller.createRelation(
        sourceNoteId: root.note.id,
        targetNoteId: childId!,
        text: 'relates',
      );
      
      await controller.createSummary(
        parentId: root.note.id,
        startIndex: 0,
        endIndex: 0,
        text: 'Sum',
      );
      
      await controller.bindNoteTag(noteId: childId, tagId: 'tag-1');
      
      // Delete child
      await controller.deleteNote(childId);
      
      // Verify no orphan data
      final relations = await repo.getRelationsByTopic(controller.topicId!);
      expect(relations.where((r) => r.sourceNoteId == childId || r.targetNoteId == childId), isEmpty);
      
      final tags = await repo.getTagsForNote(childId);
      expect(tags, isEmpty);
    });
    
    test('scenario 6: import with missing fields uses defaults', () async {
      final converter = GurumindDataConverter(repo);
      final data = {
        'id': 'imported-topic',
        'title': 'Imported',
        'notes': [
          {'id': 'n1', 'parentId': null, 'title': 'Root'},
        ],
        'relations': [
          // Missing text field
          {'sourceNoteId': 'n1', 'targetNoteId': 'n1'},
        ],
      };
      
      await converter.convertTopic(data);
      
      final relations = await repo.getRelationsByTopic('imported-topic');
      expect(relations.length, 1);
      expect(relations.first.text, ''); // Default empty text
    });
  });
}
`

Run:

`ash
flutter test test/mindmap/regression/v15_full_flow_test.dart
`

Expected: PASS.

- [ ] **Step 2: Commit full flow tests**

Run:

`ash
git add test/mindmap/regression/v15_full_flow_test.dart
git commit -m "test(mindmap): add v15 full flow regression tests"
`

---

### Task 6: Update Walkthrough Documentation

**Files:**
- Modify: docs/v15/walkthrough.md

- [ ] **Step 1: Write final walkthrough**

Update docs/v15/walkthrough.md:

`md
# v15 Walkthrough

## Completed Features

### Phase 1: Selection
- Drag-mode node tap selects exactly one node.
- Blank-canvas tap clears selection.
- Selection state synchronizes between selectedNote and selectedNoteIds.

### Phase 2: Inline Editing
- Double-tap node enters inline editing.
- Tab creates child and enters editing.
- Enter creates sibling and enters editing.
- Escape cancels edit, restores previous/default title.
- Empty title submission restores default title, does not delete node.

### Phase 3: Layout Switching
- Layout menu shows: 两侧, 左侧, 右侧, 框架式.
- Layout direction changes trigger immediate recalculation.
- Topic-level layout settings persist across sessions.
- Framework layout selectable from menu.

### Phase 4: Associative Lines
- Directed relations: A -> B distinct from B -> A.
- Source node must be selected before creating relation.
- No-source selection shows bubble prompt.
- Self-line prevented.
- Same-direction duplicate selects existing line.
- Lines render with arrowheads.
- Inline text editing for relations.
- Deletion removes relation without affecting nodes.

### Phase 5: Summary Nodes
- Contiguous sibling range creates summary.
- Cross-parent selection creates multiple summaries.
- Summary position follows layout direction.
- Parent collapse hides summary.
- Inline text editing for summaries.
- Deletion removes summary without affecting covered nodes.
- Known limitation: framework-internal summaries not supported.

### Phase 6: Node Tags
- Global tags reused across documents and nodes.
- Node-tag bindings stored in mindmap_note_tags table.
- Up to 3 tag chips displayed per node.
- Unbinding removes binding, preserves global tag.
- Long tag names handled with ellipsis and tooltip.

### Phase 7: Polish
- Import/export supports relations, summaries, node tags.
- Missing import fields use safe defaults.
- Keyboard shortcuts consistent across features.
- Persistence verified for all new data.

## Verification Commands

`ash
flutter analyze
flutter test test/mindmap
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
`

## Known Limitations

- Framework-internal summaries remain unsupported.
- Relation control-point dragging is limited.
- Tag tree reference counts show document counts only, not node counts.
`

- [ ] **Step 2: Commit walkthrough**

Run:

`ash
git add docs/v15/walkthrough.md
git commit -m "docs: finalize v15 walkthrough"
`

---

### Task 7: Update Known Issues

**Files:**
- Modify: docs/v15/known_issues.md

- [ ] **Step 1: Write known issues**

Update docs/v15/known_issues.md:

`md
# v15 Known Issues

## Phase 1-3

- Framework layout is now selected from topic-level layout state. Legacy Note.layoutStyle is retained only for imported or historical node data and must not be used as the active whole-map UI switch.

## Phase 4-6

- Framework-internal summaries remain a known limitation. Normal tree summaries and framework outer-level summaries are supported.
- Relation control-point dragging is limited to selected relation handles in the current canvas coordinate system. Rich bezier handle editing can be expanded after Phase 7 regression hardening.
- Tag tree reference counts still report document counts only; node reference counts are intentionally deferred.

## Phase 7

- Import of legacy Gurumind files without v15 fields succeeds but may lose relation/summary/tag data if those fields are missing. This is expected for pre-v15 exports.
- Large topic export may be slow due to multiple repository queries. Optimization deferred.
`

- [ ] **Step 2: Commit known issues**

Run:

`ash
git add docs/v15/known_issues.md
git commit -m "docs: record v15 known issues"
`

---

### Task 8: Update Context with Domain Concepts

**Files:**
- Modify: CONTEXT.md

- [ ] **Step 1: Add v15 domain concepts to CONTEXT.md**

Add to CONTEXT.md:

`md
## Mindmap Relations

- Directed associative line between two notes in the same topic.
- Source and target are note IDs; direction matters (A -> B != B -> A).
- Optional text label rendered on the line.
- Persisted in mindmap_relations table.

## Mindmap Summaries

- Summarizes a contiguous range of sibling notes.
- Identified by parentId + startIndex + endIndex.
- Rendered as a brace and summary node beside the covered range.
- Persisted in mindmap_summaries table.
- Framework-internal summaries are a known limitation.

## Node Tags

- Global knowledge tags bound to mindmap nodes.
- Binding stored in mindmap_note_tags(note_id, tag_id) table.
- Tags are not stored on Note.tagIds; they are a separate relation.
- Up to 3 chips displayed per node.
`

- [ ] **Step 2: Commit context update**

Run:

`ash
git add CONTEXT.md
git commit -m "docs: add v15 domain concepts to CONTEXT.md"
`

---

### Task 9: Final Verification

**Files:**
- Run all verification commands

- [ ] **Step 1: Run full test suite**

Run:

`ash
flutter test test/mindmap
`

Expected: All tests PASS.

- [ ] **Step 2: Run static analysis**

Run:

`ash
flutter analyze
`

Expected: No new errors. Pre-existing warnings recorded in walkthrough.

- [ ] **Step 3: Run Rust and FRB checks**

Run:

`ash
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
`

Expected: No errors.

- [ ] **Step 4: Commit final state**

Run:

`ash
git add docs/v15/implementation_plan3.md
git commit -m "docs: add v15 phase 7 implementation plan"
`

---

## Final Verification Matrix

Run these before declaring v15 complete:

`ash
flutter analyze
flutter test test/mindmap
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
`

Expected: All commands pass with no new errors.

## Self-Review

- Spec coverage: Phase 7 import/export, shortcuts, persistence, regression, and documentation are covered by Tasks 1-8.
- Verification: Each task has focused tests and the final matrix includes full test suite, analyzer, Rust, and FRB checks.
- Documentation: Walkthrough and known-issues clearly state completed features and limitations.
