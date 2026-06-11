# GuruMind 导入 UI 与状态错乱问题调研报告

## 背景

用户反馈：

1. GuruMind 导入入口不应放在思维导图页面的“更多操作”中，应放到主页“新建/导入”按钮中，新增“导入 GuruMind”，并移除思维导图页更多菜单里的导入入口。
2. 在已打开 `123` 思维导图标签页时，从思维导图页导入 `D:\个人文件\Downloads\演示.gurumind` 或其它 `.gurumind` 文件后：
   - 面包屑/页面状态变成“演示”；
   - 标签页标题仍是 `123`；
   - 页面显示 `No nodes`；
   - 返回主页后没有看到名为“演示”的导图；
   - 再打开原 `123` 后，`123` 原内容也看不到，导入的“演示”也看不到。

## 调研范围

本次只做问题定位与报告，不做功能修复。检查范围：

- 主页新建/导入菜单：`lib/main.dart`
- 标签页控制与 MindMapController 缓存：`lib/main.dart`、`lib/src/home/tab_navigation_controller.dart`
- GuruMind 导入调用链：`lib/src/mindmap/ui/mindmap_page.dart`、`lib/src/mindmap/ui/mindmap_controller.dart`、`lib/src/mindmap/service/mindmap_service.dart`、`lib/src/mindmap/import/`
- FFI/Rust mindmap 存储：`lib/src/mindmap/storage/ffi_mindmap_repository.dart`、`rust/src/storage/mindmap.rs`

## 现象复盘

当前导入入口位于思维导图页面的更多菜单：

- `MindMapPage` 更多菜单触发 `_importGuruMindFile()`。
- `_importGuruMindFile()` 调用当前页面的 `widget.controller.importGuruMindFile(filePath)`。
- 当前 controller 是打开的标签页对应的 controller，例如 `123` 标签页下的 `MindMapController(123)`。

导入成功回调后，当前 controller 内部会执行：

```dart
await loadTopics();
selectTopic(result.topic);
```

这会把当前 `123` controller 的 `_selectedTopic` 改成导入结果 `演示`，但不会更新外层 TabNavigation 的 TabItem，也不会新开 `演示` 标签页。因此 UI 很容易进入“标签仍是 123，但 controller selectedTopic 是演示”的混合状态。

## 证据

### 1. 主页“新建/导入”菜单目前没有 GuruMind 入口

`lib/main.dart` 的 `_showCreateMenu` 当前只有两项：

- 新建思维导图
- 导入 PDF

导入 GuruMind 没有被接到主页菜单，而是被接到了 `MindMapPage` 的更多菜单。这与用户期望不一致，也与导入操作的语义不一致：GuruMind 导入是 workspace/topic 级操作，不应该依赖当前已打开的某个 topic controller。

### 2. 标签页状态与 MindMapController 状态是两套状态

`TabNavigationController.openMindMap(topicId, title)` 以 `topicId` 查重并打开/切换标签页，TabItem 的 `id/title` 不会因为内部 controller 调了 `selectTopic()` 自动改变。

主界面通过 `_getOrBuildMindMapController(activeTab.id)` 缓存 controller：

- controller cache key 是标签页 id，例如 `123` 的 topicId；
- 导入后当前 controller 内部 selectedTopic 变成 `演示`；
- 但 cache key 和 activeTab 仍然是 `123`。

这解释了“面包屑变成演示，但标签还是 123”。

### 3. GuruMindImporter 对 FFI 仓储的保存方式是错误的

`GuruMindImporter.importFile()` 解析完成后保存数据的方式是：

```dart
await _repository.updateTopic(topic);
for (final note in notes) {
  await _repository.updateNote(note);
}
```

这在 `InMemoryMindMapRepository` 中表现为 upsert，因为 `updateTopic/updateNote` 直接写入 map；但在 FFI/Rust 仓储中不是 upsert。

Rust 实现是纯 SQL UPDATE：

```sql
UPDATE mindmap_topics SET ... WHERE id = ?;
UPDATE mindmap_notes SET ... WHERE id = ?;
```

如果 topic/note 原本不存在，SQLite UPDATE 影响 0 行，但当前 Rust 函数仍返回 `Ok(())`，没有检查 affected rows，也没有 INSERT fallback。

因此在真实应用中，导入器会“解析成功、返回 success”，但新 topic/note 实际没有插入数据库。这个问题解释了：

- 主页没有出现“演示”；
- 退出当前页后再进主页看不到导入结果；
- tests 没暴露问题，因为现有 GuruMind import/export 测试使用的是 `InMemoryMindMapRepository`，不是 FFI 仓储。

### 4. `演示.gurumind` 内存导入探针显示解析本身成功

使用 `InMemoryMindMapRepository` 对 `D:\个人文件\Downloads\演示.gurumind` 做不写生产库的探针，结果：

- 文件存在；
- `ImportResult.isSuccess == true`；
- topic title 是 `演示`；
- topic id 是 `0-6f73097d-26ad-4537-9cb2-156e22f17160`；
- root 数量为 7；
- notes 数量为 19。

这说明 ZIP/Hive 解析链路不是主要失败点，主要失败在真实 FFI 持久化与 UI 状态接入。

### 5. ID 规范化还存在结构隐患

探针里发现部分 note 的 `id` 已规范化为 `1-...`，但 `parentId` 仍保留 GuruMind 原始 UUID（未加 `1-` 前缀），例如：

- note id：`1-16ee3d66-d830-49f1-8737-6eefa6089a7f`
- parentId：`b9b32257-0868-45a1-9dd2-05a15f09b34a`

当前 converter 对 `child_ids/childIds/rootNodes` 做了 `_toStarmindNoteId`，但 `parent_id/parentId` 没做同样规范化。

虽然 Rust `get_note_children()` 主要从父节点 `child_ids` 查询子节点，不完全依赖 child 的 `parent_id`，但不规范的 parentId 会影响：

- fallback root 计算：`notes.where((note) => note.parentId == null)`；
- 后续删除、移动、重排、父子关系维护；
- 任何依赖 parentId 的 UI/查询逻辑。

这是独立于 UI 入口和 FFI upsert 的第二层数据一致性隐患。

## 根因结论

### 根因 A：导入入口放错层级

导入 GuruMind 当前放在 `MindMapPage` 的更多菜单中，导致导入动作绑定到“当前打开的 topic controller”。正确层级应是主页/workspace 的“新建/导入”。

### 根因 B：导入后直接切换当前 controller 的 selectedTopic，未同步标签页

`MindMapController.importGuruMindFile()` 调 `selectTopic(result.topic)`，会把当前 `123` controller 内部状态切到 `演示`，但外层 tab 仍是 `123`。这造成标签标题、controller selectedTopic、controller cache key 三者不一致。

### 根因 C：FFI/Rust updateTopic/updateNote 不是 upsert，导致导入数据没真正写入生产数据库

导入器用 `updateTopic/updateNote` 保存全新 topic/note，但 Rust 只做 UPDATE，不存在时静默 0 行，仍返回成功。真实应用导入结果因此不会出现在主页列表。

### 根因 D：GuruMind parentId 没规范化，存在树结构一致性风险

导入器把 note id/childIds/rootIds 转为 Starmind ID，但 parentId 未转，导致父子关系双向字段不一致。

## 为什么会出现用户描述的组合症状

1. 用户在 `123` 标签页中点击“导入 GuruMind”。
2. 当前 `123` 的 `MindMapController` 解析出 `演示` topic，并执行 `selectTopic(演示)`。
3. UI 面包屑/标题读取 controller.selectedTopic，因此显示“演示”。
4. 外层 TabItem 没变，仍是 `123`，所以标签页标题还是 `123`。
5. FFI update 没插入新 topic/note，数据库没有“演示”。
6. controller 尝试加载 `演示` 的 note tree，但 FFI 中没有对应数据，结果为空，页面显示 `No nodes`。
7. 回主页 `_loadTopics()` 从 FFI 读所有 topics，读不到“演示”。
8. 再打开 `123` 时，可能复用已经被污染的 controller cache 或加载到空树，表现为 `123` 内容也不见。

## 修复建议

### 必须修复 1：移动 UI 入口

- 从 `MindMapPage` 更多菜单移除“导入 GuruMind”。
- 在主页 `_showCreateMenu` 中新增“导入 GuruMind”。
- 主页导入成功后应执行：
  1. 写入数据库；
  2. 刷新主页 topic 列表；
  3. 调用 `workspaceController.openMindMap(importedTopic.id, importedTopic.title)` 打开/切换到导入 topic 的独立标签页。

### 必须修复 2：不要让当前 topic controller 承担 workspace 导入

建议把 GuruMind 导入从 `MindMapController.importGuruMindFile()` 下移/迁移到 workspace/home 层 helper，例如：

- `_handleGuruMindFileSelection(BuildContext context, WorkspaceController controller)`；
- 或 `WorkspaceController.importGuruMindFile(...)`；
- 或 `MindMapService.importGuruMindFile(...)` + HomeDashboard 刷新/打开。

导入成功后不应在旧 controller 里 `selectTopic(result.topic)`。

### 必须修复 3：为导入提供真正的 insert/upsert API

可选方案：

1. 新增 repository 方法：`upsertTopic(Topic)`、`upsertNote(Note)`，导入器专用；
2. 修改 FFI/Rust `updateTopic/updateNote` 为 upsert；
3. 在 `updateTopic/updateNote` 中检查 affected rows，0 行时返回错误，避免静默成功。

推荐方案是新增明确的 `upsert` 方法，避免改变普通 update 的语义。

### 必须修复 4：规范化 parentId

在 `GuruMindDataConverter._normalizeNoteMap()` 中，`parent_id` 应与 `id/child_ids/root_note_ids` 走同一套 `_toStarmindNoteId` 规范化逻辑。

### 必须补测试

1. FFI 导入集成测试：真实或构造 `.gurumind` 导入后，`getAllTopics()` 必须包含导入 topic，`getNotesByTopic()` 必须有节点。
2. UI 状态测试：从主页导入后应打开新 topic tab；当前已有 topic tab 不应被污染。
3. converter 单元测试：parentId、childIds、rootNoteIds 必须统一带 `1-` 前缀。
4. 回归测试：在已打开 `123` 标签页时导入 `演示.gurumind` 后，`123` 标签页仍指向 `123`，导入结果应在独立 `演示` 标签页打开。

## 风险评估

- 入口迁移风险低：只是 UI 位置和调用者变化。
- upsert API 风险中：涉及 Rust、FRB 生成、Dart repository 接口和测试。
- parentId 规范化风险低到中：会改变导入数据结构，但方向与 Starmind ID 约定一致。
- 修复后需要重新生成 FRB 并跑全量测试。

## 建议执行顺序

1. 移除 MindMapPage 的 GuruMind 导入菜单项。
2. 在主页“新建/导入”菜单添加“导入 GuruMind”。
3. 新增/修复导入持久化 upsert 链路。
4. 修复 parentId ID 规范化。
5. 导入成功后刷新主页 topic 列表并打开导入 topic 独立标签页。
6. 添加 FFI 导入与 UI 状态回归测试。
7. 运行 `flutter_rust_bridge_codegen generate`、`cargo check`、相关 Flutter tests、全量 `flutter test`。
