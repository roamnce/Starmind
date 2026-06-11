# v15 Mindmap Relations, Summaries, and Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 4-6: directed associative lines, summary nodes, and global tag bindings for mindmap nodes.

**Architecture:** Phase 4-6 add three domain concepts without changing the parent-child `Note` tree as the source of structural truth. Relations and summaries live beside notes as topic-scoped records; tags remain global knowledge tags with a separate note-tag binding table. The controller owns interaction state, repositories own persistence, layout/painter code consumes computed rects from `LayoutResult`, and widgets render editable overlays.

**Tech Stack:** Flutter/Dart, `ChangeNotifier`, existing mindmap repository/service/controller layers, SQLite through Rust + flutter_rust_bridge 2.12.0, `CustomPainter`, Flutter widget tests, Dart domain/storage tests, `flutter_rust_bridge_codegen generate`, `cargo check`, `flutter analyze`.

---

## Scope

This plan covers:

- Phase 4: associative line model, storage, controller flow, canvas rendering, text editing, deletion, duplicate handling, and anchor regression.
- Phase 5: summary model, contiguous sibling range semantics, layout output, summary rendering, inline summary editing, deletion, collapse behavior, and known issue recording for framework-internal summaries.
- Phase 6: global tag reuse, note-tag binding storage, node tag picker, node tag chips, unbinding, long-tag layout regression, and cascade cleanup.

This plan intentionally leaves full Phase 7 polish for a later plan. Phase 7 should add end-to-end walkthrough, import/export completion, and broad regression documentation after this plan lands.

## Current Baseline

- `MindMapController` already has stable node selection and multi-selection after Phase 1-3.
- `LayoutResult` exposes node centers, node sizes, and `getNodeRect(String nodeId)`.
- `MindMapCanvasPainter` draws parent-child connections and can be extended to draw extra overlays.
- `MindMapRepository` currently stores topics and notes only.
- Global tags are represented by `lib/src/domain/tag.dart`, `StorageRepository`, `rust/src/storage/tags.rs`, and the FFI storage API.
- Phase 6 must not add permanent `tagIds` to `Note`; node tags are bindings, not note fields.

## File Map

- Create `lib/src/mindmap/domain/mindmap_relation.dart`: directed relation model and JSON/map conversion.
- Create `lib/src/mindmap/domain/mindmap_summary.dart`: summary range model and JSON/map conversion.
- Create `lib/src/mindmap/domain/mindmap_note_tag.dart`: note-tag binding view model for UI and service return values.
- Modify `lib/src/mindmap/storage/mindmap_repository.dart`: relation CRUD, summary CRUD, note-tag binding APIs.
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`: in-memory maps for relations, summaries, and note-tag bindings, including cleanup on note deletion.
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`: convert new FRB models and expose repository methods.
- Modify `rust/src/storage/db.rs`: create `mindmap_relations`, `mindmap_summaries`, and `mindmap_note_tags`.
- Modify `rust/src/storage/mindmap.rs`: new Rust structs and CRUD functions for relations, summaries, and node tag bindings.
- Modify `rust/src/storage/tags.rs`: add lookup-by-name support for tag reuse and cascade cleanup of node bindings when deleting a tag.
- Modify `rust/src/api/storage.rs`: re-export structs and expose FFI functions.
- Modify generated files under `lib/src/rust/` and `rust/src/frb_generated.rs` by running `flutter_rust_bridge_codegen generate`.
- Modify `lib/src/mindmap/service/mindmap_service.dart`: high-level relation, summary, and note-tag operations.
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`: relation creation mode, selected relation/summary/tag overlay state, summary creation from selections, tag picker flows.
- Modify `lib/src/mindmap/ui/mindmap_page.dart`: route node taps through relation target handling, render relation/summary/tag overlays, wire toolbar actions.
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`: add relation, summary, and tag action callbacks or buttons if not already present.
- Modify `lib/src/mindmap/ui/canvas_painter.dart`: draw associative lines and summary braces/lines.
- Create `lib/src/mindmap/ui/relation_label_widget.dart`: selected/editable relation text overlay.
- Create `lib/src/mindmap/ui/summary_node_widget.dart`: selected/editable summary text widget.
- Create `lib/src/mindmap/ui/node_tag_picker.dart`: compact tag input and existing-tag picker overlay.
- Modify `lib/src/mindmap/ui/node_widget.dart`: display up to three tag chips under node title and expose chip unbind callbacks.
- Modify tests under `test/mindmap/domain`, `test/mindmap/storage`, `test/mindmap/service`, `test/mindmap/ui`, `test/mindmap/layout`, and `test/mindmap/import`/`export` where called out below.

## Shared Contracts

Use these exact default values:

```dart
const defaultRelationText = '关联';
const defaultSummaryText = '概要';
const relationStyleSolid = 'solid';
const maxVisibleNodeTags = 3;
```

Use these controller-level concepts:

```dart
enum RelationCreationMode { idle, choosingTarget }

String? get relationSourceNoteId;
String? get highlightedRelationTargetId;
String? get selectedRelationId;
String? get selectedSummaryId;

Future<void> startRelationCreation();
Future<void> handleNodeTapForRelationTarget(String targetNoteId);
void cancelRelationCreation();
Future<void> updateRelationText(String relationId, String text);
Future<void> deleteRelation(String relationId);

Future<void> createSummariesFromSelection();
Future<void> updateSummaryText(String summaryId, String text);
Future<void> deleteSummary(String summaryId);

Future<void> bindTagToSelectedNode(String tagName);
Future<void> unbindTagFromNode(String noteId, String tagId);
```

Normalize editable labels with this rule:

```dart
String normalizeLabel(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
```

## Task 1: Phase 4 Domain And In-Memory Repository

**Files:**
- Create `lib/src/mindmap/domain/mindmap_relation.dart`
- Create `test/mindmap/domain/mindmap_relation_test.dart`
- Modify `lib/src/mindmap/storage/mindmap_repository.dart`
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`
- Modify `test/mindmap/storage/mindmap_repository_test.dart`

- [ ] **Step 1: Write failing relation domain tests**

Add `test/mindmap/domain/mindmap_relation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mindmap_relation.dart';

void main() {
  group('MindMapRelation', () {
    test('uses default text and style when optional values are absent', () {
      final now = DateTime.utc(2026, 6, 7);
      final relation = MindMapRelation(
        id: 'rel-1',
        topicId: 'topic-1',
        sourceNoteId: '1-a',
        targetNoteId: '1-b',
        createdAt: now,
        updatedAt: now,
      );

      expect(relation.text, '关联');
      expect(relation.style, 'solid');
      expect(relation.controlPoints, isEmpty);
    });

    test('round trips through map with control points', () {
      final now = DateTime.utc(2026, 6, 7);
      final relation = MindMapRelation(
        id: 'rel-1',
        topicId: 'topic-1',
        sourceNoteId: '1-a',
        targetNoteId: '1-b',
        text: 'causes',
        controlPoints: const [
          RelationControlPoint(x: 12, y: 20),
          RelationControlPoint(x: 40, y: 28),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final restored = MindMapRelation.fromMap(relation.toMap());

      expect(restored.id, relation.id);
      expect(restored.topicId, relation.topicId);
      expect(restored.sourceNoteId, relation.sourceNoteId);
      expect(restored.targetNoteId, relation.targetNoteId);
      expect(restored.text, 'causes');
      expect(restored.controlPoints.map((p) => '${p.x},${p.y}'), ['12.0,20.0', '40.0,28.0']);
    });
  });
}
```

- [ ] **Step 2: Run domain test and verify failure**

Run: `flutter test test/mindmap/domain/mindmap_relation_test.dart`

Expected: FAIL because `MindMapRelation` does not exist.

- [ ] **Step 3: Implement relation model**

Create `lib/src/mindmap/domain/mindmap_relation.dart`:

```dart
import 'dart:convert';

const defaultRelationText = '关联';
const relationStyleSolid = 'solid';

class RelationControlPoint {
  final double x;
  final double y;

  const RelationControlPoint({required this.x, required this.y});

  factory RelationControlPoint.fromJson(Map<String, dynamic> json) {
    return RelationControlPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class MindMapRelation {
  final String id;
  final String topicId;
  final String sourceNoteId;
  final String targetNoteId;
  final String text;
  final List<RelationControlPoint> controlPoints;
  final String style;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MindMapRelation({
    required this.id,
    required this.topicId,
    required this.sourceNoteId,
    required this.targetNoteId,
    this.text = defaultRelationText,
    this.controlPoints = const [],
    this.style = relationStyleSolid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MindMapRelation.fromMap(Map<String, dynamic> map) {
    final rawControlPoints = map['control_points_json'] as String?;
    final decodedControlPoints = rawControlPoints == null || rawControlPoints.isEmpty
        ? const <RelationControlPoint>[]
        : (jsonDecode(rawControlPoints) as List)
            .map((item) => RelationControlPoint.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

    return MindMapRelation(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      sourceNoteId: map['source_note_id'] as String,
      targetNoteId: map['target_note_id'] as String,
      text: (map['text'] as String?) ?? defaultRelationText,
      controlPoints: decodedControlPoints,
      style: (map['style'] as String?) ?? relationStyleSolid,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'source_note_id': sourceNoteId,
        'target_note_id': targetNoteId,
        'text': text,
        'control_points_json': controlPoints.isEmpty
            ? null
            : jsonEncode(controlPoints.map((point) => point.toJson()).toList()),
        'style': style,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MindMapRelation copyWith({
    String? text,
    List<RelationControlPoint>? controlPoints,
    String? style,
    DateTime? updatedAt,
  }) {
    return MindMapRelation(
      id: id,
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      text: text ?? this.text,
      controlPoints: controlPoints ?? this.controlPoints,
      style: style ?? this.style,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 4: Add failing in-memory repository tests**

Append these tests to `test/mindmap/storage/mindmap_repository_test.dart`:

```dart
test('relation CRUD prevents same-direction duplicates', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final sourceId = await repository.createNote(topicId, 'source');
  final targetId = await repository.createNote(topicId, 'target');

  final created = await repository.createRelation(
    topicId: topicId,
    sourceNoteId: sourceId,
    targetNoteId: targetId,
  );
  final duplicate = await repository.createRelation(
    topicId: topicId,
    sourceNoteId: sourceId,
    targetNoteId: targetId,
  );
  final reverse = await repository.createRelation(
    topicId: topicId,
    sourceNoteId: targetId,
    targetNoteId: sourceId,
  );

  expect(duplicate, created);
  expect(reverse, isNot(created));
  expect(await repository.listRelations(topicId), hasLength(2));
});

test('deleting a note removes connected relations', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final sourceId = await repository.createNote(topicId, 'source');
  final targetId = await repository.createNote(topicId, 'target');
  await repository.createRelation(
    topicId: topicId,
    sourceNoteId: sourceId,
    targetNoteId: targetId,
  );

  await repository.deleteNote(targetId);

  expect(await repository.listRelations(topicId), isEmpty);
});
```

- [ ] **Step 5: Extend repository interface and in-memory implementation**

Add these methods to `MindMapRepository`:

```dart
Future<String> createRelation({
  required String topicId,
  required String sourceNoteId,
  required String targetNoteId,
  String text = defaultRelationText,
});
Future<MindMapRelation?> getRelation(String id);
Future<void> updateRelation(MindMapRelation relation);
Future<void> deleteRelation(String id);
Future<List<MindMapRelation>> listRelations(String topicId);
Future<MindMapRelation?> findRelationByEndpoints({
  required String topicId,
  required String sourceNoteId,
  required String targetNoteId,
});
Future<void> deleteRelationsForNote(String noteId);
```

Import `mindmap_relation.dart` in repository files. In `InMemoryMindMapRepository`, add a relation map and sequence:

```dart
final Map<String, MindMapRelation> _relations = {};
int _relationSequence = 0;
```

Implement same-direction duplicate handling:

```dart
@override
Future<String> createRelation({
  required String topicId,
  required String sourceNoteId,
  required String targetNoteId,
  String text = defaultRelationText,
}) async {
  final existing = await findRelationByEndpoints(
    topicId: topicId,
    sourceNoteId: sourceNoteId,
    targetNoteId: targetNoteId,
  );
  if (existing != null) return existing.id;

  final id = 'rel-${++_relationSequence}';
  final now = DateTime.now();
  _relations[id] = MindMapRelation(
    id: id,
    topicId: topicId,
    sourceNoteId: sourceNoteId,
    targetNoteId: targetNoteId,
    text: text,
    createdAt: now,
    updatedAt: now,
  );
  return id;
}
```

Update `deleteNote` to call `deleteRelationsForNote(id)` before removing the note.

- [ ] **Step 6: Run tests and commit**

Run:

```bash
flutter test test/mindmap/domain/mindmap_relation_test.dart test/mindmap/storage/mindmap_repository_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/domain/mindmap_relation.dart lib/src/mindmap/storage/mindmap_repository.dart lib/src/mindmap/storage/in_memory_mindmap_repository.dart test/mindmap/domain/mindmap_relation_test.dart test/mindmap/storage/mindmap_repository_test.dart
git commit -m "feat: add mindmap relation domain storage"
```

## Task 2: Phase 4 Rust And FFI Relation Persistence

**Files:**
- Modify `rust/src/storage/db.rs`
- Modify `rust/src/storage/mindmap.rs`
- Modify `rust/src/api/storage.rs`
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`
- Modify generated files under `lib/src/rust/` and `rust/src/frb_generated.rs`
- Modify `test/mindmap/storage/ffi_mindmap_repository_test.dart`

- [ ] **Step 1: Add failing FFI relation persistence test**

Add a test to `test/mindmap/storage/ffi_mindmap_repository_test.dart` that uses the same initialization helper as existing FFI tests:

```dart
test('persists relations through FFI repository', () async {
  final repository = createInitializedFfiMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final sourceId = await repository.createNote(topicId, 'source');
  final targetId = await repository.createNote(topicId, 'target');

  final relationId = await repository.createRelation(
    topicId: topicId,
    sourceNoteId: sourceId,
    targetNoteId: targetId,
  );

  final relation = await repository.getRelation(relationId);
  expect(relation, isNotNull);
  expect(relation!.sourceNoteId, sourceId);
  expect(relation.targetNoteId, targetId);
  expect(relation.text, '关联');

  final updated = relation.copyWith(text: 'depends on', updatedAt: DateTime.now());
  await repository.updateRelation(updated);

  expect((await repository.getRelation(relationId))!.text, 'depends on');
  expect(await repository.listRelations(topicId), hasLength(1));
});
```

- [ ] **Step 2: Run FFI test and verify failure**

Run: `flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart`

Expected: FAIL because FFI relation methods are missing.

- [ ] **Step 3: Add SQLite table**

In `rust/src/storage/db.rs`, create the table after `mindmap_notes`:

```rust
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS mindmap_relations (
        id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        source_note_id TEXT NOT NULL,
        target_note_id TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '关联',
        control_points_json TEXT,
        style TEXT NOT NULL DEFAULT 'solid',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(topic_id, source_note_id, target_note_id),
        FOREIGN KEY(topic_id) REFERENCES mindmap_topics(id) ON DELETE CASCADE,
        FOREIGN KEY(source_note_id) REFERENCES mindmap_notes(id) ON DELETE CASCADE,
        FOREIGN KEY(target_note_id) REFERENCES mindmap_notes(id) ON DELETE CASCADE
    )
    "#,
    [],
).map_err(|e| format!("Failed to create mindmap_relations table: {}", e))?;
```

Add indexes:

```rust
conn.execute(
    "CREATE INDEX IF NOT EXISTS idx_mindmap_relations_topic ON mindmap_relations(topic_id)",
    [],
).map_err(|e| format!("Failed to create idx_mindmap_relations_topic index: {}", e))?;
```

- [ ] **Step 4: Add Rust relation struct and CRUD functions**

In `rust/src/storage/mindmap.rs`, add:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MindMapRelation {
    pub id: String,
    pub topic_id: String,
    pub source_note_id: String,
    pub target_note_id: String,
    pub text: String,
    pub control_points_json: Option<String>,
    pub style: String,
    pub created_at: i64,
    pub updated_at: i64,
}
```

Implement `create_relation`, `get_relation`, `update_relation`, `delete_relation`, `list_relations`, `find_relation_by_endpoints`, and `delete_relations_for_note`. `create_relation` must first query the unique endpoint pair and return the existing ID when found.

- [ ] **Step 5: Expose FFI API and generate bridge files**

In `rust/src/api/storage.rs`, re-export the struct:

```rust
pub use crate::storage::mindmap::{Topic, Note, MindMapRelation};
```

Add FFI functions:

```rust
pub fn mindmap_create_relation(
    topic_id: String,
    source_note_id: String,
    target_note_id: String,
    text: String,
) -> Result<String, String> {
    crate::storage::mindmap::create_relation(topic_id, source_note_id, target_note_id, text)
}
```

Add matching wrappers for get/update/delete/list/find/delete-for-note. Then run:

```bash
flutter_rust_bridge_codegen generate
```

Expected: generated Dart files include `MindMapRelation` and storage API methods.

- [ ] **Step 6: Convert relation models in FfiMindMapRepository**

Add conversion methods:

```dart
MindMapRelation _convertRelation(frb.MindMapRelation relation) {
  return MindMapRelation(
    id: relation.id,
    topicId: relation.topicId,
    sourceNoteId: relation.sourceNoteId,
    targetNoteId: relation.targetNoteId,
    text: relation.text,
    controlPoints: relation.controlPointsJson == null
        ? const []
        : (jsonDecode(relation.controlPointsJson!) as List)
            .map((item) => RelationControlPoint.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
    style: relation.style,
    createdAt: DateTime.fromMillisecondsSinceEpoch(relation.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(relation.updatedAt),
  );
}
```

Implement the repository interface by calling generated FFI functions.

- [ ] **Step 7: Run persistence verification and commit**

Run:

```bash
cargo check --manifest-path rust/Cargo.toml
flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart
```

Expected: PASS.

Commit:

```bash
git add rust/src/storage/db.rs rust/src/storage/mindmap.rs rust/src/api/storage.rs rust/src/frb_generated.rs lib/src/rust lib/src/mindmap/storage/ffi_mindmap_repository.dart test/mindmap/storage/ffi_mindmap_repository_test.dart
git commit -m "feat: persist mindmap relations through ffi"
```

## Task 3: Phase 4 Controller Creation Flow

**Files:**
- Modify `lib/src/mindmap/service/mindmap_service.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`
- Modify `test/mindmap/service/mindmap_service_test.dart`
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`

- [ ] **Step 1: Write failing service and controller tests**

Add a service test:

```dart
test('createRelation rejects self relation and reuses duplicate endpoint pair', () async {
  final repository = InMemoryMindMapRepository();
  final service = MindMapService(repository);
  final topic = await service.createTopic('topic');
  final source = await service.createNote(topicId: topic.id, title: 'source');
  final target = await service.createNote(topicId: topic.id, title: 'target');

  await expectLater(
    service.createRelation(topicId: topic.id, sourceNoteId: source.id, targetNoteId: source.id),
    throwsStateError,
  );

  final first = await service.createRelation(
    topicId: topic.id,
    sourceNoteId: source.id,
    targetNoteId: target.id,
  );
  final second = await service.createRelation(
    topicId: topic.id,
    sourceNoteId: source.id,
    targetNoteId: target.id,
  );

  expect(second.id, first.id);
});
```

Add controller tests:

```dart
test('startRelationCreation without selected node exposes prompt and stays idle', () async {
  final controller = createLoadedControllerWithRoot();

  await controller.startRelationCreation();

  expect(controller.relationCreationMode, RelationCreationMode.idle);
  expect(controller.transientMessage, '创建连线前需要先选择一个起始节点');
});

test('clicking a target creates relation from selected source', () async {
  final controller = createLoadedControllerWithRootAndChild();
  final root = controller.noteTree.first.note;
  final child = controller.noteTree.first.children.first.note;

  controller.selectNote(root);
  await controller.startRelationCreation();
  await controller.handleNodeTapForRelationTarget(child.id);

  expect(controller.relationCreationMode, RelationCreationMode.idle);
  expect(controller.relations.single.sourceNoteId, root.id);
  expect(controller.relations.single.targetNoteId, child.id);
  expect(controller.selectedRelationId, controller.relations.single.id);
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
flutter test test/mindmap/service/mindmap_service_test.dart test/mindmap/ui/mindmap_controller_test.dart
```

Expected: FAIL because service/controller methods are absent.

- [ ] **Step 3: Implement service methods**

Add methods to `MindMapService`:

```dart
Future<MindMapRelation> createRelation({
  required String topicId,
  required String sourceNoteId,
  required String targetNoteId,
  String text = defaultRelationText,
}) async {
  if (sourceNoteId == targetNoteId) {
    throw StateError('Relation source and target must be different notes');
  }
  final id = await _repository.createRelation(
    topicId: topicId,
    sourceNoteId: sourceNoteId,
    targetNoteId: targetNoteId,
    text: text,
  );
  final relation = await _repository.getRelation(id);
  return relation!;
}
```

Add `listRelations`, `updateRelationText`, and `deleteRelation`.

- [ ] **Step 4: Implement controller relation state**

Add state:

```dart
RelationCreationMode _relationCreationMode = RelationCreationMode.idle;
RelationCreationMode get relationCreationMode => _relationCreationMode;
String? _relationSourceNoteId;
String? get relationSourceNoteId => _relationSourceNoteId;
String? _selectedRelationId;
String? get selectedRelationId => _selectedRelationId;
String? _transientMessage;
String? get transientMessage => _transientMessage;
List<MindMapRelation> _relations = [];
List<MindMapRelation> get relations => List.unmodifiable(_relations);
```

Implement:

```dart
Future<void> startRelationCreation() async {
  if (_selectedNote == null) {
    _transientMessage = '创建连线前需要先选择一个起始节点';
    _relationCreationMode = RelationCreationMode.idle;
    notifyListeners();
    return;
  }
  _relationSourceNoteId = _selectedNote!.id;
  _relationCreationMode = RelationCreationMode.choosingTarget;
  _transientMessage = null;
  notifyListeners();
}
```

In `handleNodeTapForRelationTarget`, create the relation, reload relation list, select the relation, and clear creation state. If the target equals source, set `transientMessage` to `不能连接到同一个节点`.

- [ ] **Step 5: Wire page and toolbar**

In `MindMapPage` node tap handling, route taps through relation mode:

```dart
onTap: () async {
  if (widget.controller.relationCreationMode == RelationCreationMode.choosingTarget) {
    await widget.controller.handleNodeTapForRelationTarget(note.id);
    return;
  }
  widget.controller.selectNote(note);
  _centerOnNode(noteId, pos, size);
},
```

In `BottomActionBar`, wire the relation button callback:

```dart
onCreateRelation: controller.startRelationCreation,
```

If the button does not exist, add a button using `Icons.account_tree_outlined` and tooltip text `关联线`.

- [ ] **Step 6: Add page test for prompt**

Add:

```dart
testWidgets('relation button without selected node shows prompt', (tester) async {
  final controller = createLoadedControllerWithRoot();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: MindMapPage(controller: controller))));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('关联线'));
  await tester.pumpAndSettle();

  expect(find.text('创建连线前需要先选择一个起始节点'), findsOneWidget);
});
```

- [ ] **Step 7: Run tests and commit**

Run:

```bash
flutter test test/mindmap/service/mindmap_service_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/service/mindmap_service.dart lib/src/mindmap/ui/mindmap_controller.dart lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/bottom_action_bar.dart test/mindmap/service/mindmap_service_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "feat: add associative line creation flow"
```

## Task 4: Phase 4 Relation Rendering, Selection, Editing, And Deletion

**Files:**
- Modify `lib/src/mindmap/ui/canvas_painter.dart`
- Create `lib/src/mindmap/ui/relation_label_widget.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`
- Modify `test/mindmap/ui/canvas_painter_test.dart`
- Modify `test/mindmap/ui/connection_anchor_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`

- [ ] **Step 1: Write failing painter tests**

Add to `canvas_painter_test.dart`:

```dart
test('shouldRepaint returns true when associative relations change', () {
  final first = MindMapCanvasPainter(associativeRelations: const []);
  final second = MindMapCanvasPainter(
    associativeRelations: [
      AssociativeRelationPaintData(
        id: 'rel-1',
        sourceId: '1-a',
        targetId: '1-b',
        startPoint: Offset.zero,
        endPoint: Offset(80, 0),
        labelCenter: Offset(40, -16),
        text: '关联',
        isSelected: false,
      ),
    ],
  );

  expect(second.shouldRepaint(first), isTrue);
});
```

- [ ] **Step 2: Create paint data and render relation arrows**

Add a small paint DTO inside `canvas_painter.dart` or a new file if the painter becomes too large:

```dart
class AssociativeRelationPaintData {
  final String id;
  final String sourceId;
  final String targetId;
  final Offset startPoint;
  final Offset endPoint;
  final Offset labelCenter;
  final String text;
  final bool isSelected;

  const AssociativeRelationPaintData({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.startPoint,
    required this.endPoint,
    required this.labelCenter,
    required this.text,
    required this.isSelected,
  });
}
```

Add `associativeRelations` to `MindMapCanvasPainter`, draw each line after parent-child connections, and draw an arrowhead at `endPoint`. Selected lines use a wider stroke and draw two circular control handles.

- [ ] **Step 3: Compute relation paint data from real node rects**

In `MindMapPage`, convert relations using `layoutResult.getNodeRect`:

```dart
final relationPaintData = widget.controller.relations.map((relation) {
  final sourceRect = layoutResult.getNodeRect(relation.sourceNoteId);
  final targetRect = layoutResult.getNodeRect(relation.targetNoteId);
  if (sourceRect == null || targetRect == null) return null;
  final (start, end) = AnchorCalculator.calculateAnchorPair(
    fromCenter: sourceRect.center,
    fromSize: sourceRect.size,
    toCenter: targetRect.center,
    toSize: targetRect.size,
  );
  return AssociativeRelationPaintData(
    id: relation.id,
    sourceId: relation.sourceNoteId,
    targetId: relation.targetNoteId,
    startPoint: start,
    endPoint: end,
    labelCenter: Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - 18),
    text: relation.text,
    isSelected: widget.controller.selectedRelationId == relation.id,
  );
}).whereType<AssociativeRelationPaintData>().toList();
```

Use `_offsetLayoutResult`-style offsetting for relation paint data when the canvas is shifted by `+500`.

- [ ] **Step 4: Add relation label widget**

Create `relation_label_widget.dart` with a compact label and editing state:

```dart
class RelationLabelWidget extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onTap;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  const RelationLabelWidget({
    super.key,
    required this.text,
    required this.isSelected,
    required this.isEditing,
    required this.onTap,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      final controller = TextEditingController(text: text)..selectAll();
      return TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: onCommit,
        onEditingComplete: () => onCommit(controller.text),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC8841A) : const Color(0xFF242930),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Add page tests for edit and delete**

Add widget tests:

```dart
testWidgets('relation label can be selected and edited', (tester) async {
  final controller = await createControllerWithRelation();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: MindMapPage(controller: controller))));
  await tester.pumpAndSettle();

  await tester.tap(find.text('关联'));
  await tester.pumpAndSettle();
  expect(controller.selectedRelationId, controller.relations.single.id);

  await tester.tap(find.text('关联'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'supports');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  expect(controller.relations.single.text, 'supports');
});
```

Add a delete test that selects the relation and invokes the existing delete action or `Delete` key, then expects `controller.relations` to be empty.

- [ ] **Step 6: Add anchor guardrail tests**

In `connection_anchor_test.dart`, cover associative relations for left, right, and both-side layout. Each test must compare logical rect anchors with widget rect anchors for short and long titles. Use `rect.right` for rightward relation starts and `rect.left` for leftward relation starts.

- [ ] **Step 7: Run tests and commit**

Run:

```bash
flutter test test/mindmap/ui/canvas_painter_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/canvas_painter.dart lib/src/mindmap/ui/relation_label_widget.dart lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/canvas_painter_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "feat: render and edit associative lines"
```

## Task 5: Phase 5 Summary Domain And Storage

**Files:**
- Create `lib/src/mindmap/domain/mindmap_summary.dart`
- Create `test/mindmap/domain/mindmap_summary_test.dart`
- Modify `lib/src/mindmap/storage/mindmap_repository.dart`
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`
- Modify `rust/src/storage/db.rs`
- Modify `rust/src/storage/mindmap.rs`
- Modify `rust/src/api/storage.rs`
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`
- Modify generated FRB files
- Modify `test/mindmap/storage/mindmap_repository_test.dart`
- Modify `test/mindmap/storage/ffi_mindmap_repository_test.dart`

- [ ] **Step 1: Write failing summary domain tests**

Create `test/mindmap/domain/mindmap_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mindmap_summary.dart';

void main() {
  test('normalizes reversed ranges and keeps default text', () {
    final now = DateTime.utc(2026, 6, 7);
    final summary = MindMapSummary(
      id: 'sum-1',
      topicId: 'topic-1',
      parentId: '1-parent',
      startIndex: 4,
      endIndex: 2,
      createdAt: now,
      updatedAt: now,
    );

    expect(summary.startIndex, 2);
    expect(summary.endIndex, 4);
    expect(summary.text, '概要');
  });
}
```

- [ ] **Step 2: Implement summary model**

Create `mindmap_summary.dart`:

```dart
const defaultSummaryText = '概要';

class MindMapSummary {
  final String id;
  final String topicId;
  final String parentId;
  final int startIndex;
  final int endIndex;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  MindMapSummary({
    required this.id,
    required this.topicId,
    required this.parentId,
    required int startIndex,
    required int endIndex,
    this.text = defaultSummaryText,
    required this.createdAt,
    required this.updatedAt,
  })  : startIndex = startIndex <= endIndex ? startIndex : endIndex,
        endIndex = startIndex <= endIndex ? endIndex : startIndex;

  factory MindMapSummary.fromMap(Map<String, dynamic> map) => MindMapSummary(
        id: map['id'] as String,
        topicId: map['topic_id'] as String,
        parentId: map['parent_id'] as String,
        startIndex: map['start_index'] as int,
        endIndex: map['end_index'] as int,
        text: (map['text'] as String?) ?? defaultSummaryText,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'parent_id': parentId,
        'start_index': startIndex,
        'end_index': endIndex,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
```

- [ ] **Step 3: Add repository and persistence APIs**

Add repository methods:

```dart
Future<String> createSummary({
  required String topicId,
  required String parentId,
  required int startIndex,
  required int endIndex,
  String text = defaultSummaryText,
});
Future<MindMapSummary?> getSummary(String id);
Future<void> updateSummary(MindMapSummary summary);
Future<void> deleteSummary(String id);
Future<List<MindMapSummary>> listSummaries(String topicId);
Future<void> deleteSummariesForNote(String noteId);
```

Add SQLite table:

```rust
CREATE TABLE IF NOT EXISTS mindmap_summaries (
    id TEXT PRIMARY KEY,
    topic_id TEXT NOT NULL,
    parent_id TEXT NOT NULL,
    start_index INTEGER NOT NULL,
    end_index INTEGER NOT NULL,
    text TEXT NOT NULL DEFAULT '概要',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE(topic_id, parent_id, start_index, end_index),
    FOREIGN KEY(topic_id) REFERENCES mindmap_topics(id) ON DELETE CASCADE,
    FOREIGN KEY(parent_id) REFERENCES mindmap_notes(id) ON DELETE CASCADE
)
```

Run `flutter_rust_bridge_codegen generate` after adding Rust struct and API wrappers.

- [ ] **Step 4: Add storage tests**

Add in-memory and FFI tests asserting:

- duplicate `topicId + parentId + startIndex + endIndex` returns the existing summary ID;
- deleting a parent note deletes its summaries;
- `listSummaries(topicId)` returns summaries in parent/start-index order.

- [ ] **Step 5: Run tests and commit**

Run:

```bash
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
flutter test test/mindmap/domain/mindmap_summary_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/domain/mindmap_summary.dart lib/src/mindmap/storage/mindmap_repository.dart lib/src/mindmap/storage/in_memory_mindmap_repository.dart lib/src/mindmap/storage/ffi_mindmap_repository.dart rust/src/storage/db.rs rust/src/storage/mindmap.rs rust/src/api/storage.rs rust/src/frb_generated.rs lib/src/rust test/mindmap/domain/mindmap_summary_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart
git commit -m "feat: add mindmap summary storage"
```

## Task 6: Phase 5 Summary Range Semantics And Layout

**Files:**
- Modify `lib/src/mindmap/service/mindmap_service.dart`
- Modify `lib/src/mindmap/layout/layout_result.dart`
- Modify `lib/src/mindmap/layout/tree_layout_engine.dart`
- Modify `lib/src/mindmap/ui/canvas_painter.dart`
- Modify `test/mindmap/service/mindmap_service_test.dart`
- Modify `test/mindmap/layout/tree_layout_engine_test.dart`
- Modify `test/mindmap/ui/connection_anchor_test.dart`

- [ ] **Step 1: Write failing range service tests**

Add:

```dart
test('summary ranges are grouped by parent and expanded to continuous child index ranges', () async {
  final fixture = await createServiceWithParentAndFourChildren();
  final summaries = await fixture.service.createSummariesFromSelectedNoteIds(
    topicId: fixture.topicId,
    selectedNoteIds: {fixture.children[0].id, fixture.children[2].id},
  );

  expect(summaries, hasLength(1));
  expect(summaries.single.parentId, fixture.parent.id);
  expect(summaries.single.startIndex, 0);
  expect(summaries.single.endIndex, 2);
});
```

Add a second test where selected notes belong to two parents and expect two summary records.

- [ ] **Step 2: Implement summary range creation service**

In `MindMapService`, add:

```dart
Future<List<MindMapSummary>> createSummariesFromSelectedNoteIds({
  required String topicId,
  required Set<String> selectedNoteIds,
}) async {
  final notes = await _repository.getNotesByTopic(topicId);
  final byId = {for (final note in notes) note.id: note};
  final parentToChildIndexes = <String, List<int>>{};

  for (final noteId in selectedNoteIds) {
    final note = byId[noteId];
    if (note == null) continue;
    final parentId = note.parentId ?? note.id;
    final parent = note.parentId == null ? note : byId[parentId];
    if (parent == null) continue;
    final childIndex = note.parentId == null ? 0 : parent.childIds.indexOf(note.id);
    if (childIndex < 0) continue;
    parentToChildIndexes.putIfAbsent(parentId, () => []).add(childIndex);
  }

  final result = <MindMapSummary>[];
  for (final entry in parentToChildIndexes.entries) {
    final indexes = entry.value..sort();
    final id = await _repository.createSummary(
      topicId: topicId,
      parentId: entry.key,
      startIndex: indexes.first,
      endIndex: indexes.last,
    );
    final summary = await _repository.getSummary(id);
    if (summary != null) result.add(summary);
  }
  return result;
}
```

- [ ] **Step 3: Extend layout result with summary paint data**

Add to `layout_result.dart`:

```dart
class SummaryLayoutData {
  final String summaryId;
  final String parentId;
  final Rect coveredBounds;
  final Rect summaryRect;
  final Path linePath;
  final bool isLeftSide;

  const SummaryLayoutData({
    required this.summaryId,
    required this.parentId,
    required this.coveredBounds,
    required this.summaryRect,
    required this.linePath,
    required this.isLeftSide,
  });
}
```

Add `List<SummaryLayoutData> summaries` to `LayoutResult` with an empty default.

- [ ] **Step 4: Calculate summary geometry in layout engine**

Add a method that receives summaries from the controller/page and computes:

- `coveredBounds` from child rects in `[startIndex, endIndex]`;
- right layout summary node at `coveredBounds.right + config.horizontalSpacing / 2`;
- left layout summary node at `coveredBounds.left - config.horizontalSpacing / 2`;
- a right-angle brace path that starts at covered top, bends around the covered range, and ends at `summaryRect`.

The engine must skip summaries whose parent is collapsed or whose range is outside current child IDs.

- [ ] **Step 5: Add layout tests for left, right, both-side, short title, long title**

In `tree_layout_engine_test.dart`, add tests that build a parent with three children and one summary. Assert:

- right layout `summaryRect.left > coveredBounds.right`;
- left layout `summaryRect.right < coveredBounds.left`;
- both-side layout follows the side of the covered children;
- long-title node sizes are reflected by `coveredBounds`.

- [ ] **Step 6: Draw summary lines**

In `MindMapCanvasPainter`, add `summaryLayouts` and draw each `linePath` before relation lines and after parent-child connections. Use the same accent color family as selected nodes; selected summaries use wider stroke.

- [ ] **Step 7: Run tests and commit**

Run:

```bash
flutter test test/mindmap/service/mindmap_service_test.dart test/mindmap/layout/tree_layout_engine_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/ui/canvas_painter_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/service/mindmap_service.dart lib/src/mindmap/layout/layout_result.dart lib/src/mindmap/layout/tree_layout_engine.dart lib/src/mindmap/ui/canvas_painter.dart test/mindmap/service/mindmap_service_test.dart test/mindmap/layout/tree_layout_engine_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/ui/canvas_painter_test.dart
git commit -m "feat: calculate and draw summary ranges"
```

## Task 7: Phase 5 Summary UI Creation, Editing, Deletion, And Known Issue

**Files:**
- Create `lib/src/mindmap/ui/summary_node_widget.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`
- Modify `docs/v15/known_issues.md`
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`

- [ ] **Step 1: Add failing controller tests**

Add:

```dart
test('createSummariesFromSelection creates summary for selected siblings', () async {
  final controller = await createLoadedControllerWithParentAndThreeChildren();
  final childIds = controller.noteTree.first.children.map((child) => child.note.id).toList();
  controller.replaceSelectedNoteIds({childIds[0], childIds[1]});

  await controller.createSummariesFromSelection();

  expect(controller.summaries, hasLength(1));
  expect(controller.summaries.single.text, '概要');
  expect(controller.selectedSummaryId, controller.summaries.single.id);
});
```

- [ ] **Step 2: Implement controller summary state**

Add:

```dart
List<MindMapSummary> _summaries = [];
List<MindMapSummary> get summaries => List.unmodifiable(_summaries);
String? _selectedSummaryId;
String? get selectedSummaryId => _selectedSummaryId;
String? _editingSummaryId;
String? get editingSummaryId => _editingSummaryId;
```

Load summaries when loading a topic. Implement `createSummariesFromSelection`, `beginEditingSummary`, `updateSummaryText`, and `deleteSummary`.

- [ ] **Step 3: Add summary node widget**

Create `summary_node_widget.dart`:

```dart
class SummaryNodeWidget extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onCommit;

  const SummaryNodeWidget({
    super.key,
    required this.text,
    required this.isSelected,
    required this.isEditing,
    required this.onTap,
    required this.onDoubleTap,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      final controller = TextEditingController(text: text)..selectAll();
      return TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: onCommit,
      );
    }
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF242930),
          border: Border.all(color: isSelected ? const Color(0xFFC8841A) : const Color(0x40C8841A)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire page and toolbar**

Add a summary toolbar button with tooltip `创建概要`. On tap, call `controller.createSummariesFromSelection()`. Overlay `SummaryNodeWidget` at each `SummaryLayoutData.summaryRect`. Double-tap enters editing.

- [ ] **Step 5: Add widget tests**

Add tests for:

- multi-select siblings then tap `创建概要` creates and displays `概要`;
- double-tap summary enters `TextField`;
- editing empty summary restores `概要`;
- deleting a selected summary removes it from the page.

- [ ] **Step 6: Record framework-internal summary limitation**

Update `docs/v15/known_issues.md`:

```md
## Phase 5

- Framework-internal summaries are not part of the first summary implementation. Phase 5 supports summaries around normal tree ranges and framework outer-level ranges only. Revisit nested framework summaries during Phase 7 polish after relation and tag regressions are stable.
```

- [ ] **Step 7: Run tests and commit**

Run:

```bash
flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/summary_node_widget.dart lib/src/mindmap/ui/mindmap_controller.dart lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/bottom_action_bar.dart docs/v15/known_issues.md test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "feat: add summary node interactions"
```

## Task 8: Phase 6 Node Tag Binding Storage And Service

**Files:**
- Create `lib/src/mindmap/domain/mindmap_note_tag.dart`
- Modify `lib/src/mindmap/storage/mindmap_repository.dart`
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`
- Modify `lib/src/mindmap/service/mindmap_service.dart`
- Modify `rust/src/storage/db.rs`
- Modify `rust/src/storage/tags.rs`
- Modify `rust/src/storage/mindmap.rs`
- Modify `rust/src/api/storage.rs`
- Modify generated FRB files
- Modify `test/mindmap/storage/mindmap_repository_test.dart`
- Modify `test/mindmap/storage/ffi_mindmap_repository_test.dart`
- Modify `test/mindmap/service/mindmap_service_test.dart`

- [ ] **Step 1: Write failing tag binding tests**

Add:

```dart
test('binding tag to note reuses existing tag name and unbinding keeps global tag', () async {
  final mindmapRepository = InMemoryMindMapRepository();
  final storageRepository = InMemoryStorageRepository();
  final service = MindMapService(mindmapRepository, storageRepository: storageRepository);
  final topic = await service.createTopic('topic');
  final note = await service.createNote(topicId: topic.id, title: 'node');

  final first = await service.bindTagToNote(noteId: note.id, tagName: 'AI');
  final second = await service.bindTagToNote(noteId: note.id, tagName: 'AI');

  expect(second.tag.id, first.tag.id);
  expect(await service.listTagsForNote(note.id), hasLength(1));

  await service.unbindTagFromNote(noteId: note.id, tagId: first.tag.id);
  expect(await service.listTagsForNote(note.id), isEmpty);
  expect((await storageRepository.getTagTree()).children.map((tag) => tag.name), contains('AI'));
});
```

- [ ] **Step 2: Add note-tag domain view**

Create `mindmap_note_tag.dart`:

```dart
import '../../domain/tag.dart';

class MindMapNoteTag {
  final String noteId;
  final Tag tag;

  const MindMapNoteTag({
    required this.noteId,
    required this.tag,
  });
}
```

- [ ] **Step 3: Add binding repository APIs**

Add to `MindMapRepository`:

```dart
Future<void> bindTagToNote({required String noteId, required String tagId});
Future<void> unbindTagFromNote({required String noteId, required String tagId});
Future<List<String>> listTagIdsForNote(String noteId);
Future<void> deleteNoteTagBindingsForNote(String noteId);
```

In in-memory repository, store:

```dart
final Map<String, Set<String>> _noteTagIds = {};
```

Cleanup note bindings in `deleteNote`.

- [ ] **Step 4: Add Rust note-tag table and cascade**

In `db.rs`:

```rust
conn.execute(
    r#"
    CREATE TABLE IF NOT EXISTS mindmap_note_tags (
        note_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(note_id, tag_id),
        FOREIGN KEY(note_id) REFERENCES mindmap_notes(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
    )
    "#,
    [],
).map_err(|e| format!("Failed to create mindmap_note_tags table: {}", e))?;
```

In `tags.rs`, make `delete_tag` rely on the `ON DELETE CASCADE` relation. In `mindmap.rs`, add bind/list/unbind functions.

- [ ] **Step 5: Add tag reuse by name**

Add to `StorageRepository`:

```dart
Future<Tag?> findTagByName(String name);
```

Implement in-memory by walking the tag tree. Implement FFI by adding a Rust `find_tag_by_name(name: String) -> Result<Option<TagNode>, String>` that returns a single tag node with empty children and current document count.

- [ ] **Step 6: Implement service methods**

Modify `MindMapService` constructor:

```dart
MindMapService(
  this._repository, {
  StorageRepository? storageRepository,
}) : _storageRepository = storageRepository;
```

Implement:

```dart
Future<MindMapNoteTag> bindTagToNote({
  required String noteId,
  required String tagName,
}) async {
  final storage = _storageRepository;
  if (storage == null) {
    throw StateError('StorageRepository is required for note tags');
  }
  final normalizedName = tagName.trim();
  if (normalizedName.isEmpty) {
    throw StateError('Tag name must not be empty');
  }
  final existing = await storage.findTagByName(normalizedName);
  final tagId = existing?.id ??
      await storage.createTag(normalizedName, null, colorHexForTagName(normalizedName));
  await _repository.bindTagToNote(noteId: noteId, tagId: tagId);
  final tag = existing ?? await storage.findTagByName(normalizedName);
  return MindMapNoteTag(noteId: noteId, tag: tag!);
}
```

Use a deterministic hash color helper such as `colorHexForTagName(String name)` in `lib/src/mindmap/utils/color_utils.dart`.

- [ ] **Step 7: Run generation and storage tests**

Run:

```bash
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
flutter test test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/service/mindmap_service_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/domain/mindmap_note_tag.dart lib/src/mindmap/storage/mindmap_repository.dart lib/src/mindmap/storage/in_memory_mindmap_repository.dart lib/src/mindmap/storage/ffi_mindmap_repository.dart lib/src/mindmap/service/mindmap_service.dart lib/src/domain/storage_repository.dart lib/src/domain/in_memory_storage_repository.dart lib/src/domain/ffi_storage_repository.dart lib/src/mindmap/utils/color_utils.dart rust/src/storage/db.rs rust/src/storage/tags.rs rust/src/storage/mindmap.rs rust/src/api/storage.rs rust/src/frb_generated.rs lib/src/rust test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/service/mindmap_service_test.dart
git commit -m "feat: add note tag bindings"
```

## Task 9: Phase 6 Tag Picker And Node Chip Rendering

**Files:**
- Create `lib/src/mindmap/ui/node_tag_picker.dart`
- Modify `lib/src/mindmap/ui/node_widget.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`
- Modify `test/mindmap/ui/node_widget_test.dart`
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`
- Modify `test/mindmap/ui/connection_anchor_test.dart`

- [ ] **Step 1: Write failing NodeWidget tag chip tests**

Add:

```dart
testWidgets('shows up to three node tag chips and overflow count', (tester) async {
  final note = createNote('node');
  final tags = [
    createTag('AI'),
    createTag('Reading'),
    createTag('Long Label'),
    createTag('Extra'),
  ];

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NodeWidget(
        note: note,
        onTap: () {},
        tags: tags,
      ),
    ),
  ));

  expect(find.text('AI'), findsOneWidget);
  expect(find.text('Reading'), findsOneWidget);
  expect(find.text('Long Label'), findsOneWidget);
  expect(find.text('+1'), findsOneWidget);
});
```

- [ ] **Step 2: Add tags parameter and chip layout**

In `NodeWidget`, add:

```dart
final List<Tag> tags;
final void Function(String tagId)? onRemoveTag;
```

Render chips below the title. Use `Wrap` with constrained chip width:

```dart
Wrap(
  spacing: 4,
  runSpacing: 4,
  children: visibleTags.map((tag) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (tag.color ?? const Color(0xFFC8841A)).withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(tag.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }).toList(),
)
```

After adding tags, node size measurement must include the chip row so parent-child and associative lines stay attached to real widget bounds.

- [ ] **Step 3: Implement controller tag state**

Load tags by note ID into:

```dart
final Map<String, List<Tag>> _tagsByNoteId = {};
Map<String, List<Tag>> get tagsByNoteId => Map.unmodifiable(_tagsByNoteId);
```

Add selected-node tag methods:

```dart
Future<void> bindTagToSelectedNode(String tagName) async {
  final note = _selectedNote;
  if (note == null) {
    _transientMessage = '创建标签前需要先选择节点';
    notifyListeners();
    return;
  }
  await _service.bindTagToNote(noteId: note.id, tagName: tagName);
  await _reloadTagsForTopic();
  notifyListeners();
}
```

- [ ] **Step 4: Create tag picker overlay**

Create `node_tag_picker.dart` with a `TextField`, existing tag list, Enter-to-bind, and Escape-to-close. Position it near selected node when a node rect exists; otherwise anchor it above the bottom toolbar tag button.

- [ ] **Step 5: Wire page and toolbar**

Add a tag toolbar button with tooltip `创建标签`. On tap:

```dart
if (controller.selectedNote == null) {
  controller.showTransientMessage('创建标签前需要先选择节点');
  return;
}
setState(() => _isTagPickerVisible = true);
```

Pass tags to each `NodeWidget`:

```dart
tags: widget.controller.tagsByNoteId[note.id] ?? const [],
onRemoveTag: (tagId) => widget.controller.unbindTagFromNode(note.id, tagId),
```

- [ ] **Step 6: Add UI regression tests**

Add tests for:

- selecting a node and entering a new tag shows the chip immediately;
- entering an existing tag name reuses one global tag and does not duplicate the chip;
- clicking chip delete unbinds from the node and leaves the global tag in the tree;
- long tag text does not overflow the node and anchor tests still pass.

- [ ] **Step 7: Run tests and commit**

Run:

```bash
flutter test test/mindmap/ui/node_widget_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/connection_anchor_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/node_tag_picker.dart lib/src/mindmap/ui/node_widget.dart lib/src/mindmap/ui/mindmap_controller.dart lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/bottom_action_bar.dart test/mindmap/ui/node_widget_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/connection_anchor_test.dart
git commit -m "feat: add node tag picker and chips"
```

## Task 10: Phase 4-6 Deletion Cleanup And Regression

**Files:**
- Modify `lib/src/mindmap/service/mindmap_service.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`
- Modify `test/mindmap/service/mindmap_service_test.dart`
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`

- [ ] **Step 1: Add deletion cleanup tests**

Add service tests:

```dart
test('deleting node removes related relations summaries and tag bindings', () async {
  final fixture = await createServiceWithRelationsSummariesAndTags();

  await fixture.service.deleteNote(fixture.targetNoteId);

  expect(await fixture.service.listRelations(fixture.topicId), isEmpty);
  expect(await fixture.service.listSummaries(fixture.topicId), isEmpty);
  expect(await fixture.service.listTagsForNote(fixture.targetNoteId), isEmpty);
});
```

- [ ] **Step 2: Centralize cleanup in service deleteNote**

Ensure `MindMapService.deleteNote` deletes or delegates cleanup in this order:

```dart
await _repository.deleteRelationsForNote(id);
await _repository.deleteSummariesForNote(id);
await _repository.deleteNoteTagBindingsForNote(id);
await _repository.deleteNote(id);
```

If the repository implementation already cascades these records, still keep explicit service calls for in-memory determinism and test readability.

- [ ] **Step 3: Reload all overlay data after tree mutations**

After create/delete/update note paths in `MindMapController`, reload:

```dart
await _reloadRelationsForTopic();
await _reloadSummariesForTopic();
await _reloadTagsForTopic();
recalculateLayout();
```

- [ ] **Step 4: Add page regression for combined workflow**

Add a widget test that performs:

1. select node;
2. create child and edit title;
3. add tag;
4. create relation from parent to child;
5. multi-select children and create summary;
6. delete child;
7. assert no orphan relation/summary/tag chip remains.

- [ ] **Step 5: Run tests and commit**

Run:

```bash
flutter test test/mindmap/service/mindmap_service_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/service/mindmap_service.dart lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/service/mindmap_service_test.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "fix: clean up mindmap overlay data on node deletion"
```

## Task 11: Phase 4-6 Import Export Compatibility

**Files:**
- Modify `lib/src/mindmap/export/gurumind_exporter.dart`
- Modify `lib/src/mindmap/import/gurumind_data_converter.dart`
- Modify `lib/src/mindmap/import/gurumind_importer.dart`
- Modify `lib/src/mindmap/service/mindmap_service.dart`
- Modify `test/mindmap/export/gurumind_exporter_test.dart`
- Modify `test/mindmap/import/gurumind_data_converter_test.dart`
- Modify `test/mindmap/import/gurumind_real_sample_test.dart`

- [ ] **Step 1: Add failing converter tests**

Add tests that export a topic with one relation, one summary, and one node tag binding and assert the serialized document includes:

```dart
expect(document['relations'], isA<List>());
expect(document['summaries'], isA<List>());
expect(document['nodeTags'], isA<List>());
```

Add import tests that omit these keys and assert conversion still succeeds with empty lists.

- [ ] **Step 2: Extend exporter input**

Change `GuruMindDataExporter.exportTopic` to accept:

```dart
List<MindMapRelation> relations = const [],
List<MindMapSummary> summaries = const [],
Map<String, List<Tag>> tagsByNoteId = const {},
```

Write them into the topic hive document under `relations`, `summaries`, and `nodeTags`.

- [ ] **Step 3: Extend converter**

In `GuruMindDataConverter`, add explicit helper methods:

```dart
List<MindMapRelation> relationsFromDocument(Map<String, dynamic> document, {required String topicId});
List<MindMapSummary> summariesFromDocument(Map<String, dynamic> document, {required String topicId});
Map<String, List<String>> noteTagNamesFromDocument(Map<String, dynamic> document);
```

Use empty lists/maps when keys are absent.

- [ ] **Step 4: Persist imported records**

In `GuruMindImporter`, after notes are imported and IDs normalized, persist relations, summaries, and note tags through `MindMapService` so duplicate and validation rules are shared with interactive creation.

- [ ] **Step 5: Run import/export tests and commit**

Run:

```bash
flutter test test/mindmap/export/gurumind_exporter_test.dart test/mindmap/import/gurumind_data_converter_test.dart test/mindmap/import/gurumind_real_sample_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/export/gurumind_exporter.dart lib/src/mindmap/import/gurumind_data_converter.dart lib/src/mindmap/import/gurumind_importer.dart lib/src/mindmap/service/mindmap_service.dart test/mindmap/export/gurumind_exporter_test.dart test/mindmap/import/gurumind_data_converter_test.dart test/mindmap/import/gurumind_real_sample_test.dart
git commit -m "feat: include mindmap overlays in gurumind import export"
```

## Task 12: Phase 4-6 Closeout Documentation And Verification

**Files:**
- Create or modify `docs/v15/walkthrough_phase4_6.md`
- Modify `docs/v15/known_issues.md`
- Modify `docs/v15/task.md`

- [ ] **Step 1: Run focused domain, storage, and service tests**

Run:

```bash
flutter test test/mindmap/domain/mindmap_relation_test.dart test/mindmap/domain/mindmap_summary_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/service/mindmap_service_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run focused UI and layout tests**

Run:

```bash
flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/node_widget_test.dart test/mindmap/ui/canvas_painter_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/layout
```

Expected: PASS.

- [ ] **Step 3: Run bridge and analyzer checks**

Run:

```bash
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
flutter analyze
```

Expected: generated files are unchanged after generation, Rust check passes, and analyzer reports no new errors. Existing unrelated analyzer warnings must be recorded with exact file paths.

- [ ] **Step 4: Write walkthrough**

Create `docs/v15/walkthrough_phase4_6.md`:

```md
# v15 Phase 4-6 Walkthrough

## Implemented

- Associative lines can be created from a selected source node to a target node, rendered with arrowheads, selected, edited, deleted, and persisted.
- Summary nodes can be created from selected sibling ranges, rendered beside covered ranges, edited inline, deleted, and persisted.
- Node tags reuse global tags, bind through `mindmap_note_tags`, render as chips on nodes, unbind without deleting global tags, and persist across reloads.

## Verification

- `flutter test test/mindmap/domain/mindmap_relation_test.dart test/mindmap/domain/mindmap_summary_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/service/mindmap_service_test.dart`
- `flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/node_widget_test.dart test/mindmap/ui/canvas_painter_test.dart test/mindmap/ui/connection_anchor_test.dart test/mindmap/layout`
- `flutter_rust_bridge_codegen generate`
- `cargo check --manifest-path rust/Cargo.toml`
- `flutter analyze`
```

- [ ] **Step 5: Update known issues**

Ensure `docs/v15/known_issues.md` contains:

```md
## Phase 4-6

- Framework-internal summaries remain a known limitation. Normal tree summaries and framework outer-level summaries are supported.
- Relation control-point dragging is limited to selected relation handles in the current canvas coordinate system. Rich bezier handle editing can be expanded after Phase 7 regression hardening.
- Tag tree reference counts still report document counts only; node reference counts are intentionally deferred.
```

- [ ] **Step 6: Commit closeout docs**

Run:

```bash
git add docs/v15/walkthrough_phase4_6.md docs/v15/known_issues.md docs/v15/task.md
git commit -m "docs: record v15 phase 4-6 walkthrough"
```

## Final Verification Matrix

Run these before declaring Phase 4-6 complete:

```bash
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
flutter test test/mindmap/domain/mindmap_relation_test.dart
flutter test test/mindmap/domain/mindmap_summary_test.dart
flutter test test/mindmap/storage/mindmap_repository_test.dart
flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart
flutter test test/mindmap/service/mindmap_service_test.dart
flutter test test/mindmap/ui/mindmap_controller_test.dart
flutter test test/mindmap/ui/mindmap_page_test.dart
flutter test test/mindmap/ui/node_widget_test.dart
flutter test test/mindmap/ui/canvas_painter_test.dart
flutter test test/mindmap/ui/connection_anchor_test.dart
flutter test test/mindmap/layout
flutter test test/mindmap/export/gurumind_exporter_test.dart
flutter test test/mindmap/import/gurumind_data_converter_test.dart
flutter test test/mindmap/import/gurumind_real_sample_test.dart
flutter analyze
```

Expected final result: all listed commands pass, or the walkthrough records only pre-existing unrelated analyzer warnings with exact paths.

## Self-Review

- Spec coverage: Phase 4 relation creation, no-source prompt, A->B and B->A directionality, duplicate prevention, line editing/deletion, anchor recalculation, and persistence are covered by Tasks 1-4 and 10-11.
- Spec coverage: Phase 5 summary range creation, continuous sibling range normalization, cross-parent splitting, collapse hiding, layout side rules, inline editing, and framework-internal known issue recording are covered by Tasks 5-7 and 12.
- Spec coverage: Phase 6 global tag reuse, node-tag binding table, tag chip display, unbinding, long tag layout, and tag deletion cascade are covered by Tasks 8-9 and 10.
- Verification: Each implementation slice includes focused tests, and the final matrix includes domain, storage, service, UI, layout, import/export, Rust, FRB generation, and analyzer checks.
