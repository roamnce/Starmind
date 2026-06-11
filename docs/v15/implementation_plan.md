# v15 Mindmap Interaction Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the v15 mindmap interaction foundation: drag-mode selection, inline node editing/creation, and reliable topic-level layout switching.

**Architecture:** This plan implements Phase 1-3 as one working slice because associative lines, summary nodes, and global tags all depend on stable node selection, editing, and layout state. Controller state remains the source of truth for selection/editing/layout; widgets render that state; repository and Rust storage persist topic-level layout defaults.

**Tech Stack:** Flutter/Dart, `ChangeNotifier`, existing mindmap domain/storage abstractions, Rust FRB storage bridge, Flutter widget tests, layout unit tests, `flutter analyze`.

---

## Scope

This plan covers:

- Phase 1: drag-mode node selection and blank-canvas deselection.
- Phase 2: inline editing and create-then-edit child/sibling nodes.
- Phase 3: layout direction switching, framework layout entry, menu placement, and topic-level layout persistence.

This plan intentionally leaves Phase 4-6 for separate implementation plans because directed associative lines, summary-node ranges, and global tag bindings introduce new domain models, storage tables, import/export behavior, and more regression surface. The follow-up plans should start only after this foundation passes its verification commands.

## Current Behavior Notes

- `lib/src/mindmap/ui/mindmap_controller.dart` has `selectNote(Note?)`, but it does not fully synchronize the single selected note with `_selectedNoteIds`.
- `setInteractMode(CanvasInteractMode.drag)` currently clears `_selectedNoteIds`, which weakens drag-mode selection semantics.
- `createChildNode({required String title})` and `createSiblingNode({required String title})` require a title and select the created node.
- `_layoutDirectionToStrategy(LayoutDirection.left)` currently maps left layout to `LayoutStrategy.rightOnly`; it must map to `LayoutStrategy.leftOnly`.
- `changeLayoutDirection` changes state but must also trigger layout recalculation.
- `MindMapPage`, `NodeWidget`, and `FrameworkLayout` still use `Note.layoutStyle == 'framework'` as a UI decision source; v15 must move current UI decisions to topic-level state and keep `Note.layoutStyle` only for historical/import compatibility.
- `AddNodeDialog` can remain in the repository during this slice, but add-child/add-sibling interactions should stop opening it.

## File Map

- Modify `lib/src/mindmap/ui/mindmap_controller.dart`: selection synchronization, edit state, create-and-edit APIs, layout change recalculation, topic-level layout updates.
- Modify `lib/src/mindmap/ui/mindmap_page.dart`: node tap/double-tap wiring, blank-canvas deselection guard, add child/sibling create-and-edit paths, framework layout branch using controller/topic state.
- Modify `lib/src/mindmap/ui/node_widget.dart`: render `TextField` when a note is being edited; keep current visual styling for normal and framework nodes; remove direct `note.layoutStyle` branching from UI rendering.
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`: add framework layout item and anchor layout menu above the layout button.
- Modify `lib/src/mindmap/ui/framework_layout.dart`: keep framework geometry as a layout implementation, but stop using child/root `Note.layoutStyle` as the global framework-mode switch.
- Modify `lib/src/mindmap/domain/topic.dart`: add topic-level `layoutDirection` and `layoutStyle` fields with defaults and map serialization.
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`: create topics with default layout fields and preserve them on update.
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`: convert topic-level layout fields through FRB models.
- Modify `rust/src/storage/mindmap.rs`: add topic layout fields to Rust topic model, schema, create/update/get mapping, and default values for existing rows.
- Modify `test/mindmap/ui/mindmap_controller_test.dart`: controller tests for selection, editing, creation, and layout recalculation.
- Modify `test/mindmap/ui/node_widget_test.dart`: inline editor rendering and commit/cancel behavior.
- Modify `test/mindmap/ui/mindmap_page_test.dart`: page-level selection, blank-click, and create-and-edit flows.
- Modify `test/mindmap/ui/bottom_action_bar_test.dart`: layout menu contents and callback behavior.
- Modify `test/mindmap/domain/topic_test.dart`: topic serialization defaults and copy behavior.
- Modify `test/mindmap/storage/mindmap_repository_test.dart` and `test/mindmap/storage/ffi_mindmap_repository_test.dart`: persistence of topic layout fields.
- Modify layout tests under `test/mindmap/layout/`: assert left/right strategy mapping where current coverage is missing.

## Shared Naming Contract

Use these exact string values for persisted layout fields:

```dart
const defaultTopicLayoutDirection = 'both';
const defaultTopicLayoutStyle = 'tree';

// layoutDirection values: 'both', 'left', 'right'
// layoutStyle values: 'tree', 'framework'
```

Use these controller APIs during the implementation:

```dart
String? get editingNoteId;
void beginEditing(String noteId);
Future<void> commitEditing(String noteId, String title);
void cancelEditing(String noteId);
Future<Note?> createChildNode({String? title, bool enterEditing = false});
Future<Note?> createSiblingNode({String? title, bool enterEditing = false});
Future<void> changeLayoutDirection(LayoutDirection dir);
Future<void> changeLayoutStyle(String layoutStyle);
```

Default titles:

```dart
const defaultChildNodeTitle = '新子节点';
const defaultSiblingNodeTitle = '新同级节点';
const fallbackNodeTitle = '新节点';
```

Empty-title rule:

```dart
String normalizeEditedTitle(String title, String fallbackTitle) {
  final trimmed = title.trim();
  return trimmed.isEmpty ? fallbackTitle : trimmed;
}
```

## Task 1: Controller Selection Contract

**Files:**
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: Write failing tests for single selection synchronization**

Add these tests to the existing controller test group that owns selection behavior:

```dart
test('selectNote stores the note and replaces selectedNoteIds in drag mode', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final child = await repository.createNote(topicId, 'child', parentId: root);
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  final childNote = controller.findNodeById(child)!.note;
  controller.setInteractMode(CanvasInteractMode.drag);
  controller.selectNote(childNote);

  expect(controller.selectedNote?.id, child);
  expect(controller.selectedNoteIds, {child});
});

test('selectNote null clears selectedNote and selectedNoteIds', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  controller.selectNote(controller.findNodeById(root)!.note);
  controller.selectNote(null);

  expect(controller.selectedNote, isNull);
  expect(controller.selectedNoteIds, isEmpty);
});
```

- [ ] **Step 2: Run controller tests and verify the new tests fail**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: at least one new selection test fails because `selectedNoteIds` is not synchronized with `selectNote`.

- [ ] **Step 3: Implement selection synchronization**

Update `selectNote` in `lib/src/mindmap/ui/mindmap_controller.dart` so it follows this shape:

```dart
void selectNote(Note? note) {
  _selectedNote = note;
  if (note == null) {
    _selectedNoteIds.clear();
  } else if (_interactMode == CanvasInteractMode.drag) {
    _selectedNoteIds
      ..clear()
      ..add(note.id);
  } else if (_interactMode == CanvasInteractMode.lasso) {
    _selectedNoteIds.add(note.id);
  } else {
    _selectedNoteIds
      ..clear()
      ..add(note.id);
  }
  notifyListeners();
}
```

Keep locked-mode selection enabled. Locking blocks editing, not selection.

- [ ] **Step 4: Preserve selection when switching to drag mode**

Find `setInteractMode(CanvasInteractMode mode)` and remove any unconditional `_selectedNoteIds.clear()` for `CanvasInteractMode.drag`. Keep lasso-specific initialization intact.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart
git commit -m "fix: synchronize mindmap node selection"
```

## Task 2: Page-Level Selection Wiring

**Files:**
- Modify `test/mindmap/ui/mindmap_page_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: Add a widget test for drag-mode node tap selection**

Add a page test that pumps a mindmap with one root and one child, taps the child node, and expects its selected style. Use existing test helpers in `mindmap_page_test.dart`; if the file already has a controller/repository setup helper, extend it rather than creating a second setup path.

```dart
testWidgets('drag mode tap selects a node without opening edit UI', (tester) async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  await repository.createNote(topicId, 'root');

  await tester.pumpWidget(createTestApp(
    MindMapPage(topicId: topicId, repository: repository),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('root'));
  await tester.pumpAndSettle();

  expect(find.byType(TextField), findsNothing);
  expect(find.text('root'), findsOneWidget);
});
```

If the existing constructor signature differs, adapt only the setup lines to the current helpers; keep the assertion intent unchanged.

- [ ] **Step 2: Add a widget test for blank-canvas deselection**

```dart
testWidgets('blank canvas tap clears the selected node', (tester) async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  await repository.createNote(topicId, 'root');

  await tester.pumpWidget(createTestApp(
    MindMapPage(topicId: topicId, repository: repository),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('root'));
  await tester.pumpAndSettle();

  await tester.tapAt(const Offset(12, 12));
  await tester.pumpAndSettle();

  expect(find.byType(TextField), findsNothing);
});
```

- [ ] **Step 3: Run page tests and verify failure where wiring is missing**

Run: `flutter test test/mindmap/ui/mindmap_page_test.dart`

Expected: FAIL if blank-canvas tap or node tap does not match the new contract.

- [ ] **Step 4: Wire node tap and blank-canvas tap**

In `MindMapPage`, ensure each `NodeWidget` receives an `onTap` callback equivalent to:

```dart
onTap: () {
  controller.selectNote(node.note);
},
```

For the canvas-level gesture detector, keep drag/pan handling unchanged and use the existing empty-area tap path to call:

```dart
controller.selectNote(null);
```

Do not call `selectNote(null)` from pointer-move/pan handlers.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/mindmap/ui/mindmap_page_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_page.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "fix: select mindmap nodes in drag mode"
```

## Task 3: Controller Inline Editing State

**Files:**
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: Write failing tests for begin, commit, and cancel editing**

Add:

```dart
test('beginEditing sets editingNoteId for an existing note', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  controller.beginEditing(root);

  expect(controller.editingNoteId, root);
});

test('commitEditing updates a title and clears editingNoteId', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  controller.beginEditing(root);
  await controller.commitEditing(root, 'renamed');

  expect(controller.editingNoteId, isNull);
  expect(controller.findNodeById(root)!.note.title, 'renamed');
  expect(controller.selectedNote?.id, root);
});

test('commitEditing with empty title restores a fallback title', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  controller.beginEditing(root);
  await controller.commitEditing(root, '   ');

  expect(controller.findNodeById(root)!.note.title, 'root');
});

test('cancelEditing clears editingNoteId and keeps the note', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  controller.beginEditing(root);
  controller.cancelEditing(root);

  expect(controller.editingNoteId, isNull);
  expect(controller.findNodeById(root), isNotNull);
  expect(controller.selectedNote?.id, root);
});
```

- [ ] **Step 2: Run controller tests and verify failure**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: FAIL because `editingNoteId`, `beginEditing`, `commitEditing`, and `cancelEditing` do not exist.

- [ ] **Step 3: Implement editing state and normalization**

Add fields and methods to `MindMapController`:

```dart
static const fallbackNodeTitle = '新节点';

String? _editingNoteId;
final Map<String, String> _editingFallbackTitles = {};

String? get editingNoteId => _editingNoteId;

void beginEditing(String noteId) {
  final node = findNodeById(noteId);
  if (node == null || isLocked) return;
  _editingFallbackTitles[noteId] = node.note.title.trim().isEmpty
      ? fallbackNodeTitle
      : node.note.title;
  _editingNoteId = noteId;
  selectNote(node.note);
}

Future<void> commitEditing(String noteId, String title) async {
  final node = findNodeById(noteId);
  if (node == null) return;
  final fallback = _editingFallbackTitles[noteId] ??
      (node.note.title.trim().isEmpty ? fallbackNodeTitle : node.note.title);
  final normalizedTitle = title.trim().isEmpty ? fallback : title.trim();
  await updateNodeTitle(noteId, normalizedTitle);
  _editingFallbackTitles.remove(noteId);
  _editingNoteId = null;
  final updated = findNodeById(noteId)?.note;
  if (updated != null) selectNote(updated);
  notifyListeners();
}

void cancelEditing(String noteId) {
  if (_editingNoteId != noteId) return;
  final node = findNodeById(noteId);
  _editingFallbackTitles.remove(noteId);
  _editingNoteId = null;
  if (node != null) selectNote(node.note);
  notifyListeners();
}
```

If `updateNodeTitle` already notifies listeners, keep the final `notifyListeners()` only if tests require a repaint after clearing edit state.

- [ ] **Step 4: Run tests and commit**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart
git commit -m "feat: add inline editing controller state"
```

## Task 4: Create Child/Sibling Then Enter Editing

**Files:**
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: Update creation tests for optional title and edit state**

Add:

```dart
test('createChildNode without title uses default title and enters editing', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();
  controller.selectNote(controller.findNodeById(root)!.note);

  final child = await controller.createChildNode(enterEditing: true);

  expect(child, isNotNull);
  expect(child!.title, '新子节点');
  expect(controller.selectedNote?.id, child.id);
  expect(controller.editingNoteId, child.id);
});

test('createSiblingNode without title uses default title and enters editing', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final childId = await repository.createNote(topicId, 'child', parentId: root);
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();
  controller.selectNote(controller.findNodeById(childId)!.note);

  final sibling = await controller.createSiblingNode(enterEditing: true);

  expect(sibling, isNotNull);
  expect(sibling!.title, '新同级节点');
  expect(controller.selectedNote?.id, sibling.id);
  expect(controller.editingNoteId, sibling.id);
});
```

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: FAIL because the creation APIs still require `title`.

- [ ] **Step 3: Implement optional title creation APIs**

Change method signatures and defaults:

```dart
static const defaultChildNodeTitle = '新子节点';
static const defaultSiblingNodeTitle = '新同级节点';

Future<Note?> createChildNode({String? title, bool enterEditing = false}) async {
  final parent = _selectedNote;
  if (parent == null || isLocked) return null;
  final childTitle = title?.trim().isEmpty == false ? title!.trim() : defaultChildNodeTitle;
  final childNote = await _repository.addChildNote(parent.id, childTitle);
  await loadMindMap();
  final created = findNodeById(childNote.id)?.note ?? childNote;
  selectNote(created);
  if (enterEditing) beginEditing(created.id);
  return created;
}

Future<Note?> createSiblingNode({String? title, bool enterEditing = false}) async {
  final current = _selectedNote;
  if (current == null || current.parentId == null || isLocked) return null;
  final siblingTitle = title?.trim().isEmpty == false ? title!.trim() : defaultSiblingNodeTitle;
  final siblingNote = await _repository.addSiblingNote(current.id, siblingTitle);
  await loadMindMap();
  final created = findNodeById(siblingNote.id)?.note ?? siblingNote;
  selectNote(created);
  if (enterEditing) beginEditing(created.id);
  return created;
}
```

Adapt repository call names to the exact existing methods in `mindmap_controller.dart`; keep the public controller signatures exactly as shown.

- [ ] **Step 4: Update old tests that pass `title:`**

Existing tests that call `createChildNode(title: 'x')` and `createSiblingNode(title: 'x')` should continue to compile because `title` remains named and optional.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart
git commit -m "feat: create mindmap nodes inline"
```

## Task 5: NodeWidget Inline Editor

**Files:**
- Modify `test/mindmap/ui/node_widget_test.dart`
- Modify `lib/src/mindmap/ui/node_widget.dart`

- [ ] **Step 1: Add widget tests for inline editor rendering and commit callbacks**

Add constructor-level tests using the existing `NodeWidget` setup style:

```dart
testWidgets('renders TextField when node is editing', (tester) async {
  final note = Note(
    id: 'n1',
    topicId: 't1',
    title: 'root',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  await tester.pumpWidget(MaterialApp(
    home: NodeWidget(
      note: note,
      isSelected: true,
      isEditing: true,
      onTitleCommit: (_) {},
      onEditCancel: () {},
    ),
  ));

  expect(find.byType(TextField), findsOneWidget);
  expect(find.text('root'), findsOneWidget);
});

testWidgets('Enter commits inline edit text', (tester) async {
  String? committed;
  final note = Note(
    id: 'n1',
    topicId: 't1',
    title: 'root',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  await tester.pumpWidget(MaterialApp(
    home: NodeWidget(
      note: note,
      isSelected: true,
      isEditing: true,
      onTitleCommit: (value) => committed = value,
      onEditCancel: () {},
    ),
  ));

  await tester.enterText(find.byType(TextField), 'renamed');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();

  expect(committed, 'renamed');
});
```

- [ ] **Step 2: Run node widget tests and verify failure**

Run: `flutter test test/mindmap/ui/node_widget_test.dart`

Expected: FAIL because `NodeWidget` does not accept editing props or render `TextField`.

- [ ] **Step 3: Add editing props to NodeWidget**

Add these fields with backward-compatible defaults:

```dart
final bool isEditing;
final ValueChanged<String>? onTitleCommit;
final VoidCallback? onEditCancel;
```

In the constructor:

```dart
this.isEditing = false,
this.onTitleCommit,
this.onEditCancel,
```

- [ ] **Step 4: Render inline TextField where title Text currently renders**

Create a private helper inside `NodeWidget`:

```dart
Widget _buildTitle(BuildContext context, TextStyle style) {
  if (!isEditing) {
    return Text(note.title, style: style, softWrap: true);
  }

  return TextField(
    controller: TextEditingController(text: note.title)..selectAll(),
    autofocus: true,
    minLines: 1,
    maxLines: 4,
    textInputAction: TextInputAction.done,
    style: style,
    decoration: const InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    onSubmitted: (value) => onTitleCommit?.call(value),
    onEditingComplete: () {},
  );
}
```

Replace direct title `Text` widgets in normal and framework branches with `_buildTitle(context, titleStyle)`, where `titleStyle` is the exact `TextStyle` currently passed to that branch's title.

If the cascade `..selectAll()` is unavailable, replace it with:

```dart
final controller = TextEditingController(text: note.title);
controller.selection = TextSelection(baseOffset: 0, extentOffset: note.title.length);
```

- [ ] **Step 5: Handle Escape cancellation in NodeWidget**

Wrap the editing field in `Shortcuts` and `Actions` only when `isEditing` is true:

```dart
Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
  },
  child: Actions(
    actions: {
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (_) {
          onEditCancel?.call();
          return null;
        },
      ),
    },
    child: textField,
  ),
)
```

Import `package:flutter/services.dart` if it is not already imported.

- [ ] **Step 6: Run tests and commit**

Run: `flutter test test/mindmap/ui/node_widget_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/node_widget.dart test/mindmap/ui/node_widget_test.dart
git commit -m "feat: render inline mindmap node editor"
```

## Task 6: Replace Add Dialog Entry Points With Create-And-Edit

**Files:**
- Modify `test/mindmap/ui/mindmap_page_test.dart`
- Modify `test/mindmap/ui/bottom_action_bar_test.dart` if it asserts old dialog text
- Modify `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: Add page tests for double-tap editing and add child/sibling opening inline edit**

Add a page-level double-tap regression test before wiring `onDoubleTap` in `MindMapPage`. This covers the Phase 2 requirement that double-clicking an existing node enters inline title editing in place:

```dart
testWidgets('double tapping a node enters inline title editing', (tester) async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final rootId = await repository.createNote(topicId, 'root');
  final topic = await repository.getTopic(topicId);
  await repository.updateTopic(topic!.copyWith(rootNoteIds: [rootId]));

  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MindMapPage(controller: controller),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('root'));
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tap(find.text('root'));
  await tester.pumpAndSettle();

  expect(controller.editingNoteId, rootId);
  expect(find.byType(TextField), findsOneWidget);

  final textField = tester.widget<TextField>(find.byType(TextField));
  expect(textField.controller!.text, 'root');
  expect(textField.controller!.selection.baseOffset, 0);
  expect(textField.controller!.selection.extentOffset, 'root'.length);
});
```

Add tests that tap the existing bottom action buttons or trigger their callbacks through the page. The exact finder should match current button labels/icons. Keep these assertions:

```dart
expect(find.text('Create Child Node'), findsNothing);
expect(find.byType(TextField), findsOneWidget);
expect(find.text('新子节点'), findsOneWidget);
```

For sibling:

```dart
expect(find.text('Create Sibling Node'), findsNothing);
expect(find.byType(TextField), findsOneWidget);
expect(find.text('新同级节点'), findsOneWidget);
```

- [ ] **Step 2: Run page and bottom action tests and verify failure**

Run:

```bash
flutter test test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/bottom_action_bar_test.dart
```

Expected: FAIL where double-tap does not enter inline editing yet, old dialog expectations still exist, or old add behavior still opens `AddNodeDialog`.

- [ ] **Step 3: Wire NodeWidget editing props from MindMapPage**

When constructing `NodeWidget`, pass:

```dart
isEditing: controller.editingNoteId == node.note.id,
onDoubleTap: () => controller.beginEditing(node.note.id),
onTitleCommit: (title) => controller.commitEditing(node.note.id, title),
onEditCancel: () => controller.cancelEditing(node.note.id),
```

Keep lock semantics by relying on `beginEditing` returning early when locked.

- [ ] **Step 4: Replace add child/sibling handlers**

Replace calls that open `AddNodeDialog` for add-child/add-sibling with:

```dart
await controller.createChildNode(enterEditing: true);
```

and:

```dart
await controller.createSiblingNode(enterEditing: true);
```

Keep rename/edit dialogs for flows outside v15 inline creation only if they are still used by existing menu actions.

- [ ] **Step 5: Update tests that expected AddNodeDialog**

In `bottom_action_bar_test.dart` or `mindmap_page_test.dart`, replace old assertions such as:

```dart
expect(find.text('Create Child Node'), findsOneWidget);
```

with:

```dart
expect(find.text('Create Child Node'), findsNothing);
expect(find.byType(TextField), findsOneWidget);
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
flutter test test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/bottom_action_bar_test.dart test/mindmap/ui/node_widget_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/node_widget.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/bottom_action_bar_test.dart
git commit -m "feat: create mindmap nodes with inline editing"
```

## Task 7: Layout Direction Mapping and Recalculation

**Files:**
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `test/mindmap/layout/tree_layout_engine_test.dart` or existing layout mapping test
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: Add controller tests for left mapping and recalculation**

Add:

```dart
test('changeLayoutDirection left recalculates layout with left-only positions', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final child = await repository.createNote(topicId, 'child', parentId: root);
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  await controller.changeLayoutDirection(LayoutDirection.left);

  final rootNode = controller.findNodeById(root)!;
  final childNode = controller.findNodeById(child)!;
  expect(childNode.position.dx, lessThan(rootNode.position.dx));
});

test('changeLayoutDirection right recalculates layout with right-only positions', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final root = await repository.createNote(topicId, 'root');
  final child = await repository.createNote(topicId, 'child', parentId: root);
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  await controller.changeLayoutDirection(LayoutDirection.horizontal);

  final rootNode = controller.findNodeById(root)!;
  final childNode = controller.findNodeById(child)!;
  expect(childNode.position.dx, greaterThan(rootNode.position.dx));
});
```

- [ ] **Step 2: Run controller tests and verify failure**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: FAIL for left layout if it still maps to `rightOnly`, or FAIL because `changeLayoutDirection` is not async if the current signature has not been updated.

- [ ] **Step 3: Fix mapping and recalculation**

Update `_layoutDirectionToStrategy`:

```dart
LayoutStrategy _layoutDirectionToStrategy(LayoutDirection direction) {
  switch (direction) {
    case LayoutDirection.both:
      return LayoutStrategy.bothSides;
    case LayoutDirection.left:
      return LayoutStrategy.leftOnly;
    case LayoutDirection.horizontal:
      return LayoutStrategy.rightOnly;
    case LayoutDirection.vertical:
      return LayoutStrategy.rightOnly;
  }
}
```

Update `changeLayoutDirection`:

```dart
Future<void> changeLayoutDirection(LayoutDirection dir) async {
  _layoutDirection = dir;
  recalculateLayout();
  await _persistTopicLayoutDirection(dir);
  notifyListeners();
}
```

If persistence is added in Task 8 instead, use this temporary body in Task 7 and replace it in Task 8:

```dart
Future<void> changeLayoutDirection(LayoutDirection dir) async {
  _layoutDirection = dir;
  recalculateLayout();
  notifyListeners();
}
```

- [ ] **Step 4: Update callers for async layout change**

In `bottom_action_bar.dart` and page callbacks, wrap calls with `await` where callbacks are already async, or use:

```dart
unawaited(controller.changeLayoutDirection(direction));
```

Import `dart:async` only if `unawaited` is used.

- [ ] **Step 5: Run layout-related tests and commit**

Run:

```bash
flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/layout
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart test/mindmap/layout
git commit -m "fix: recalculate mindmap layout direction changes"
```

## Task 8: Topic-Level Layout Fields in Dart Domain

**Files:**
- Modify `test/mindmap/domain/topic_test.dart`
- Modify `lib/src/mindmap/domain/topic.dart`
- Modify `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`

- [ ] **Step 1: Add topic domain tests**

Add:

```dart
test('Topic defaults to both tree layout when map fields are missing', () {
  final topic = Topic.fromMap({
    'id': 't1',
    'title': 'topic',
    'created_at': '2024-01-01T00:00:00.000',
    'updated_at': '2024-01-01T00:00:00.000',
  });

  expect(topic.layoutDirection, 'both');
  expect(topic.layoutStyle, 'tree');
});

test('Topic serializes layout fields and copyWith updates them', () {
  final topic = Topic(
    id: 't1',
    title: 'topic',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final changed = topic.copyWith(layoutDirection: 'left', layoutStyle: 'framework');

  expect(changed.layoutDirection, 'left');
  expect(changed.layoutStyle, 'framework');
  expect(changed.toMap()['layout_direction'], 'left');
  expect(changed.toMap()['layout_style'], 'framework');
});
```

- [ ] **Step 2: Run domain tests and verify failure**

Run: `flutter test test/mindmap/domain/topic_test.dart`

Expected: FAIL because layout fields do not exist.

- [ ] **Step 3: Add layout fields to Topic**

Add fields:

```dart
final String layoutDirection;
final String layoutStyle;
```

Constructor defaults:

```dart
this.layoutDirection = 'both',
this.layoutStyle = 'tree',
```

In `fromMap`:

```dart
layoutDirection: (map['layout_direction'] as String?) ?? 'both',
layoutStyle: (map['layout_style'] as String?) ?? 'tree',
```

In `toMap`:

```dart
'layout_direction': layoutDirection,
'layout_style': layoutStyle,
```

In `copyWith` parameters:

```dart
String? layoutDirection,
String? layoutStyle,
```

And copy body:

```dart
layoutDirection: layoutDirection ?? this.layoutDirection,
layoutStyle: layoutStyle ?? this.layoutStyle,
```

- [ ] **Step 4: Ensure in-memory repository creates default layout topics**

No explicit values are needed if `Topic` defaults are used. If `Topic` construction in `in_memory_mindmap_repository.dart` lists every field manually, add:

```dart
layoutDirection: 'both',
layoutStyle: 'tree',
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
flutter test test/mindmap/domain/topic_test.dart test/mindmap/storage/mindmap_repository_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/domain/topic.dart lib/src/mindmap/storage/in_memory_mindmap_repository.dart test/mindmap/domain/topic_test.dart
git commit -m "feat: add topic layout settings"
```

## Task 9: Persist Topic Layout Through FFI and Rust Storage

**Files:**
- Modify `rust/src/storage/mindmap.rs`
- Modify `lib/src/mindmap/storage/ffi_mindmap_repository.dart`
- Modify `test/mindmap/storage/ffi_mindmap_repository_test.dart`

- [ ] **Step 1: Add FFI repository test for layout persistence**

Add or extend a topic update test:

```dart
test('persists topic layout fields through ffi repository', () async {
  final repository = FfiMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final topic = await repository.getTopic(topicId);
  expect(topic, isNotNull);

  await repository.updateTopic(topic!.copyWith(
    layoutDirection: 'left',
    layoutStyle: 'framework',
  ));

  final updated = await repository.getTopic(topicId);
  expect(updated!.layoutDirection, 'left');
  expect(updated.layoutStyle, 'framework');
});
```

- [ ] **Step 2: Run FFI storage tests and verify failure**

Run: `flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart`

Expected: FAIL because Rust/FRB topic models do not include layout fields.

- [ ] **Step 3: Add Rust topic fields and schema defaults**

In `rust/src/storage/mindmap.rs`, add fields to the Rust `Topic` struct:

```rust
pub layout_direction: String,
pub layout_style: String,
```

In topic table initialization or migration path, add columns with defaults:

```sql
ALTER TABLE topics ADD COLUMN layout_direction TEXT NOT NULL DEFAULT 'both';
ALTER TABLE topics ADD COLUMN layout_style TEXT NOT NULL DEFAULT 'tree';
```

If the file uses `CREATE TABLE IF NOT EXISTS`, include:

```sql
layout_direction TEXT NOT NULL DEFAULT 'both',
layout_style TEXT NOT NULL DEFAULT 'tree',
```

When reading rows, map missing or null values to defaults:

```rust
layout_direction: row.get::<_, Option<String>>("layout_direction")?.unwrap_or_else(|| "both".to_string()),
layout_style: row.get::<_, Option<String>>("layout_style")?.unwrap_or_else(|| "tree".to_string()),
```

When creating a topic, insert defaults:

```rust
"both", "tree"
```

When updating a topic, persist `topic.layout_direction` and `topic.layout_style`.

- [ ] **Step 4: Convert FFI topic fields in Dart**

In `_convertTopic`:

```dart
layoutDirection: frbTopic.layoutDirection,
layoutStyle: frbTopic.layoutStyle,
```

In `_convertToFrbTopic`:

```dart
layoutDirection: topic.layoutDirection,
layoutStyle: topic.layoutStyle,
```

Regenerate FRB bindings if the project requires generation after Rust struct changes. Use the repository's existing FRB generation command if documented; otherwise run the same command used in previous storage model changes.

- [ ] **Step 5: Run storage tests and commit**

Run:

```bash
flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/storage/mindmap_repository_test.dart
```

Expected: PASS.

Commit:

```bash
git add rust/src/storage/mindmap.rs lib/src/mindmap/storage/ffi_mindmap_repository.dart test/mindmap/storage/ffi_mindmap_repository_test.dart
git commit -m "feat: persist mindmap topic layout settings"
```

## Task 10: Controller Uses Topic-Level Layout Settings

**Files:**
- Modify `test/mindmap/ui/mindmap_controller_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: Add tests for loading and persisting topic layout state**

Add:

```dart
test('loadMindMap initializes layout direction from topic', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  final topic = await repository.getTopic(topicId);
  await repository.updateTopic(topic!.copyWith(layoutDirection: 'left'));
  await repository.createNote(topicId, 'root');

  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  expect(controller.layoutDirection, LayoutDirection.left);
});

test('changeLayoutStyle persists framework layout on topic', () async {
  final repository = InMemoryMindMapRepository();
  final topicId = await repository.createTopic('topic');
  await repository.createNote(topicId, 'root');
  final controller = MindMapController(repository: repository, topicId: topicId);
  await controller.loadMindMap();

  await controller.changeLayoutStyle('framework');

  final topic = await repository.getTopic(topicId);
  expect(topic!.layoutStyle, 'framework');
  expect(controller.layoutStyle, 'framework');
});
```

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: FAIL because controller does not load or persist topic-level layout fields.

- [ ] **Step 3: Add layout state getters and converters**

In controller:

```dart
String _layoutStyle = 'tree';
String get layoutStyle => _layoutStyle;

LayoutDirection _layoutDirectionFromTopicValue(String value) {
  switch (value) {
    case 'left':
      return LayoutDirection.left;
    case 'right':
      return LayoutDirection.horizontal;
    case 'both':
    default:
      return LayoutDirection.both;
  }
}

String _topicValueFromLayoutDirection(LayoutDirection direction) {
  switch (direction) {
    case LayoutDirection.left:
      return 'left';
    case LayoutDirection.horizontal:
      return 'right';
    case LayoutDirection.both:
    case LayoutDirection.vertical:
      return 'both';
  }
}
```

- [ ] **Step 4: Load topic layout during `loadMindMap`**

After loading the topic:

```dart
final topic = await _repository.getTopic(_topicId);
if (topic != null) {
  _layoutDirection = _layoutDirectionFromTopicValue(topic.layoutDirection);
  _layoutStyle = topic.layoutStyle;
}
```

Keep the existing note loading and layout recalculation order so loaded layout state is applied before `recalculateLayout()`.

- [ ] **Step 5: Persist layout changes**

Add:

```dart
Future<void> _persistTopicLayout({String? layoutDirection, String? layoutStyle}) async {
  final topic = await _repository.getTopic(_topicId);
  if (topic == null) return;
  await _repository.updateTopic(topic.copyWith(
    layoutDirection: layoutDirection ?? topic.layoutDirection,
    layoutStyle: layoutStyle ?? topic.layoutStyle,
    updatedAt: DateTime.now(),
  ));
}

Future<void> changeLayoutStyle(String layoutStyle) async {
  _layoutStyle = layoutStyle == 'framework' ? 'framework' : 'tree';
  await _persistTopicLayout(layoutStyle: _layoutStyle);
  recalculateLayout();
  notifyListeners();
}
```

Update `changeLayoutDirection` to persist:

```dart
Future<void> changeLayoutDirection(LayoutDirection dir) async {
  _layoutDirection = dir;
  await _persistTopicLayout(layoutDirection: _topicValueFromLayoutDirection(dir));
  recalculateLayout();
  notifyListeners();
}
```

- [ ] **Step 6: Run tests and commit**

Run: `flutter test test/mindmap/ui/mindmap_controller_test.dart`

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_controller.dart test/mindmap/ui/mindmap_controller_test.dart
git commit -m "feat: use topic-level layout settings"
```

## Task 11: Layout Menu and Framework Layout Entry

**Files:**
- Modify `test/mindmap/ui/bottom_action_bar_test.dart`
- Modify `test/mindmap/ui/framework_layout_test.dart`
- Modify `lib/src/mindmap/ui/bottom_action_bar.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: Add bottom action bar test for framework menu item**

Add:

```dart
testWidgets('layout menu includes framework layout', (tester) async {
  LayoutDirection? selectedDirection;
  String? selectedStyle;

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BottomActionBar(
        currentLayoutDirection: LayoutDirection.both,
        currentLayoutStyle: 'tree',
        onLayoutDirectionChanged: (direction) => selectedDirection = direction,
        onLayoutStyleChanged: (style) => selectedStyle = style,
      ),
    ),
  ));

  await tester.tap(find.byTooltip('布局'));
  await tester.pumpAndSettle();

  expect(find.text('两侧布局'), findsOneWidget);
  expect(find.text('左侧布局'), findsOneWidget);
  expect(find.text('右侧布局'), findsOneWidget);
  expect(find.text('框架式布局'), findsOneWidget);

  await tester.tap(find.text('框架式布局'));
  await tester.pumpAndSettle();

  expect(selectedDirection, isNull);
  expect(selectedStyle, 'framework');
});
```

Adapt constructor parameter names to the current `BottomActionBar`; preserve the four menu labels and callback expectations.

- [ ] **Step 2: Run bottom action tests and verify failure**

Run: `flutter test test/mindmap/ui/bottom_action_bar_test.dart`

Expected: FAIL because framework layout item and style callback are not present.

- [ ] **Step 3: Add style props and menu items**

In `BottomActionBar`, add:

```dart
final String currentLayoutStyle;
final ValueChanged<String> onLayoutStyleChanged;
```

Constructor defaults should preserve existing tests if a default is allowed:

```dart
this.currentLayoutStyle = 'tree',
required this.onLayoutStyleChanged,
```

Add menu items:

```dart
PopupMenuItem<Object>(
  value: LayoutDirection.both,
  child: Text('两侧布局'),
),
PopupMenuItem<Object>(
  value: LayoutDirection.left,
  child: Text('左侧布局'),
),
PopupMenuItem<Object>(
  value: LayoutDirection.horizontal,
  child: Text('右侧布局'),
),
const PopupMenuDivider(),
PopupMenuItem<Object>(
  value: 'framework',
  child: Text('框架式布局'),
),
```

When handling the selected value:

```dart
if (value is LayoutDirection) {
  onLayoutDirectionChanged(value);
  onLayoutStyleChanged('tree');
} else if (value == 'framework') {
  onLayoutStyleChanged('framework');
}
```

- [ ] **Step 4: Anchor menu above the layout button**

Use the layout button's `BuildContext` to calculate a rectangle centered above the button:

```dart
final box = context.findRenderObject() as RenderBox;
final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
final buttonTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
final buttonSize = box.size;
const menuWidth = 100.0;
final left = buttonTopLeft.dx + buttonSize.width / 2 - menuWidth / 2;
final top = buttonTopLeft.dy - 8;

final position = RelativeRect.fromLTRB(
  left,
  top,
  overlay.size.width - left - menuWidth,
  overlay.size.height - top,
);
```

Use this `position` in `showMenu`. Keep Flutter's menu height calculation automatic; the `top` value should bias the menu above the button and leave a small gap.

- [ ] **Step 5: Switch MindMapPage framework branch to controller layoutStyle**

Replace root-note checks like:

```dart
root.note.layoutStyle == 'framework'
```

with:

```dart
controller.layoutStyle == 'framework'
```

When constructing `BottomActionBar`, pass:

```dart
currentLayoutStyle: controller.layoutStyle,
onLayoutStyleChanged: (style) => controller.changeLayoutStyle(style),
```

For layout direction callbacks:

```dart
onLayoutDirectionChanged: (direction) => controller.changeLayoutDirection(direction),
```

- [ ] **Step 6: Remove remaining UI dependency on Note.layoutStyle**

Run this audit command:

```bash
rg -n "note\\.layoutStyle|root\\.note\\.layoutStyle|layoutStyle == 'framework'" lib/src/mindmap/ui test/mindmap/ui
```

Replace any remaining UI-level `Note.layoutStyle` framework decisions with explicit topic-level inputs. `NodeWidget` should receive a boolean or enum from the caller instead of reading `note.layoutStyle`:

```dart
final bool isFrameworkNode;

const NodeWidget({
  super.key,
  required this.note,
  this.isSelected = false,
  this.isCollapsed = false,
  required this.onTap,
  this.onDoubleTap,
  this.onLongPress,
  this.onAddChild,
  this.onDelete,
  this.onToggleCollapse,
  this.customSize,
  this.controller,
  this.isFrameworkNode = false,
});
```

Then replace the framework branch in `build`:

```dart
if (isFrameworkNode) {
  return _buildFrameworkNode(context, theme, accentColor, selected);
}
```

In `MindMapPage`, pass framework mode from the controller:

```dart
isFrameworkNode: controller.layoutStyle == 'framework',
```

In `FrameworkLayout`, treat the root passed to framework layout as the framework container because the page already selected the framework layout branch. Do not inspect `node.note.layoutStyle` to decide whether the whole tree is in framework mode. If child framework containers are still needed for historical imported data, isolate that compatibility behind a named helper such as:

```dart
bool isLegacyFrameworkContainer(NoteTreeNode node) =>
    node.note.layoutStyle == 'framework';
```

Use that helper only for imported nested framework containers and document that it is not the active topic layout switch.

Re-run the audit command. Expected remaining matches are limited to:

- `lib/src/mindmap/domain/note.dart`
- `lib/src/mindmap/import/gurumind_data_converter.dart`
- compatibility tests that explicitly assert legacy import behavior

- [ ] **Step 7: Run UI tests and commit**

Run:

```bash
flutter test test/mindmap/ui/bottom_action_bar_test.dart test/mindmap/ui/framework_layout_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/bottom_action_bar.dart lib/src/mindmap/ui/mindmap_page.dart lib/src/mindmap/ui/node_widget.dart lib/src/mindmap/ui/framework_layout.dart test/mindmap/ui/bottom_action_bar_test.dart test/mindmap/ui/framework_layout_test.dart test/mindmap/ui/node_widget_test.dart
git commit -m "feat: add topic-level framework layout switching"
```

## Task 12: Keyboard Shortcuts Use Inline Creation

**Files:**
- Modify `test/mindmap/ui/shortcuts_mapping_test.dart`
- Modify `test/mindmap/ui/mindmap_page_test.dart`
- Modify `lib/src/mindmap/ui/mindmap_page.dart` or the shortcut handler file that owns Tab/Enter mapping

- [ ] **Step 1: Add shortcut regression tests**

Add assertions for `Tab` and `Enter` flows using existing shortcut test helpers:

```dart
expect(find.byType(TextField), findsOneWidget);
expect(find.text('新子节点'), findsOneWidget);
```

for `Tab`, and:

```dart
expect(find.byType(TextField), findsOneWidget);
expect(find.text('新同级节点'), findsOneWidget);
```

for `Enter`.

- [ ] **Step 2: Run shortcut tests and verify failure**

Run:

```bash
flutter test test/mindmap/ui/shortcuts_mapping_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: FAIL if shortcuts still route to add dialogs or do not enter editing.

- [ ] **Step 3: Replace shortcut handlers**

For selected node shortcuts:

```dart
TabIntent: CallbackAction<TabIntent>(
  onInvoke: (_) {
    unawaited(controller.createChildNode(enterEditing: true));
    return null;
  },
),
EnterIntent: CallbackAction<EnterIntent>(
  onInvoke: (_) {
    unawaited(controller.createSiblingNode(enterEditing: true));
    return null;
  },
),
```

If the project uses custom intent classes, keep those classes and only replace the body.

- [ ] **Step 4: Run tests and commit**

Run:

```bash
flutter test test/mindmap/ui/shortcuts_mapping_test.dart test/mindmap/ui/mindmap_page_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/src/mindmap/ui/mindmap_page.dart test/mindmap/ui/shortcuts_mapping_test.dart test/mindmap/ui/mindmap_page_test.dart
git commit -m "feat: route mindmap shortcuts to inline creation"
```

## Task 13: Connection Anchor Regression Guardrail

**Files:**
- Modify `test/mindmap/ui/connection_anchor_test.dart`
- Modify `test/mindmap/layout/anchor_calculator_test.dart` if needed

- [ ] **Step 1: Add or confirm left/right short/long title anchor coverage**

Ensure tests include these four cases:

```dart
test('right layout short title connection touches node edge', () { /* existing or new assertion */ });
test('right layout long title connection touches node edge', () { /* existing or new assertion */ });
test('left layout short title connection touches node edge', () { /* existing or new assertion */ });
test('left layout long title connection touches node edge', () { /* existing or new assertion */ });
```

The assertions must compare logical Rect anchors and actual widget Rect anchors where the UI test can access rendered bounds:

```dart
final rect = tester.getRect(find.text('long node title'));
expect(anchor.dx, closeTo(rect.left, 1.0));
```

Use `rect.right` for right-side anchors and `rect.left` for left-side anchors.

- [ ] **Step 2: Run anchor tests**

Run:

```bash
flutter test test/mindmap/ui/connection_anchor_test.dart test/mindmap/layout/anchor_calculator_test.dart
```

Expected: PASS. If a gap appears, fix the anchor calculation before proceeding.

- [ ] **Step 3: Commit guardrail tests or fixes**

Commit only if files changed:

```bash
git add test/mindmap/ui/connection_anchor_test.dart test/mindmap/layout/anchor_calculator_test.dart lib/src/mindmap/layout/anchor_calculator.dart
git commit -m "test: cover mindmap connection anchors after layout switching"
```

## Task 14: Full Regression and Documentation Closeout

**Files:**
- Create or modify `docs/v15/walkthrough.md`
- Create or modify `docs/v15/known_issues.md`
- Modify `docs/v15/task.md` if it tracks phase status

- [ ] **Step 1: Run focused mindmap UI regression**

Run:

```bash
flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/node_widget_test.dart test/mindmap/ui/bottom_action_bar_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/shortcuts_mapping_test.dart test/mindmap/ui/framework_layout_test.dart test/mindmap/ui/connection_anchor_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run layout and storage regression**

Run:

```bash
flutter test test/mindmap/layout test/mindmap/domain/topic_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: no new errors. Existing unrelated warnings must be recorded in the walkthrough with file paths.

- [ ] **Step 4: Write walkthrough**

Create `docs/v15/walkthrough.md` with:

```md
# v15 Phase 1-3 Walkthrough

## Implemented

- Drag-mode node tap selects exactly one node and blank-canvas tap clears selection.
- Child/sibling creation now creates a visible node first and enters inline editing.
- Empty inline edit submissions restore the existing/default title instead of deleting the node.
- Layout direction switching recalculates node positions.
- Topic-level layout fields persist tree/framework style and left/both/right direction.
- Layout menu includes tree and framework entries and opens above the layout button.

## Verification

- `flutter test test/mindmap/ui/mindmap_controller_test.dart test/mindmap/ui/node_widget_test.dart test/mindmap/ui/bottom_action_bar_test.dart test/mindmap/ui/mindmap_page_test.dart test/mindmap/ui/shortcuts_mapping_test.dart test/mindmap/ui/framework_layout_test.dart test/mindmap/ui/connection_anchor_test.dart`
- `flutter test test/mindmap/layout test/mindmap/domain/topic_test.dart test/mindmap/storage/mindmap_repository_test.dart test/mindmap/storage/ffi_mindmap_repository_test.dart`
- `flutter analyze`

## Phase 4-6 Inputs Now Available

- Associative lines can rely on `selectedNote` as the directed source node.
- Summary nodes can rely on stable layout recalculation after tree changes.
- Global tag bindings can rely on node selection without adding local priority/progress tags.
```

- [ ] **Step 5: Write known issues**

Create `docs/v15/known_issues.md` with:

```md
# v15 Known Issues

## Phase 1-3

- Framework layout is now selected from topic-level layout state. Legacy `Note.layoutStyle` is retained only for imported or historical node data and must not be used as the active whole-map UI switch.

## Deferred To Phase 4-7

- Associative line editing, deletion, control-point dragging, and persistence are deferred to Phase 4.
- Summary nodes are deferred to Phase 5.
- Framework-internal summary rendering is deferred beyond the first Phase 5 implementation and must be re-evaluated during Phase 7 polish.
- Global tag bindings for mindmap nodes are deferred to Phase 6.
```

- [ ] **Step 6: Commit closeout docs**

Run:

```bash
git add docs/v15/walkthrough.md docs/v15/known_issues.md docs/v15/task.md
git commit -m "docs: record v15 phase 1-3 walkthrough"
```

## Final Verification Matrix

Run these before declaring Phase 1-3 complete:

```bash
flutter test test/mindmap/ui/mindmap_controller_test.dart
flutter test test/mindmap/ui/node_widget_test.dart
flutter test test/mindmap/ui/bottom_action_bar_test.dart
flutter test test/mindmap/ui/mindmap_page_test.dart
flutter test test/mindmap/ui/shortcuts_mapping_test.dart
flutter test test/mindmap/ui/framework_layout_test.dart
flutter test test/mindmap/ui/connection_anchor_test.dart
flutter test test/mindmap/layout
flutter test test/mindmap/domain/topic_test.dart
flutter test test/mindmap/storage/mindmap_repository_test.dart
flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart
flutter analyze
```

Expected final result: all listed commands pass, or the walkthrough records only pre-existing unrelated analyzer warnings with exact paths.

## Self-Review

- Spec coverage: Phase 1 is covered by Tasks 1-2; Phase 2 is covered by Tasks 3-6 and 12; Phase 3 is covered by Tasks 7-11 and 13.
- Phase boundary: Phase 4 directed lines, Phase 5 summary ranges, and Phase 6 global tags are excluded from this implementation slice and should receive separate plans after this slice lands.
- Type consistency: Public controller APIs use `editingNoteId`, `beginEditing`, `commitEditing`, `cancelEditing`, optional-title `createChildNode`/`createSiblingNode`, async `changeLayoutDirection`, and `changeLayoutStyle` consistently across controller, page, and tests.
- Verification: Each task has a focused test command and the final matrix includes UI, layout, storage, and analyzer checks.
