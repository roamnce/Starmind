# Phase 2: 节点内手写笔记 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按 task 推进。所有 Step 用 `- [ ]` checkbox 跟踪。

**Goal:** 每个 Note 节点可包含独立的 Markdown 内容 + 手写墨迹层；通过长按节点弹出底部 `DraggableScrollableSheet` 编辑；节点卡片上自动显示墨迹缩略图。

**Architecture:** 复用 Phase 1 的 `StrokeRenderer` / `StrokeStabilizer` / `InkLayerController` / `FfiInkLayerRepository`，扩展 `Note` 模型加 `inkLayerId`（指向 `ink_layers` 表中 `type='node'` 的记录）。新增 `NodeDetailPanel`、`MarkdownEditor`、`NodeInkEditor`、`InkThumbnailPainter` 四个组件，墨迹层透明叠加在 Markdown 上方，通过 IgnorePointer/HitTestBehavior 实现穿透。

**Tech Stack:** Flutter + forui（`forui: ^0.22.3`，详情面板顶部条/关闭按钮优先用 forui）、`flutter_markdown` 或类似 Markdown 渲染包、`DraggableScrollableSheet`、Phase 1 的 ink 基础设施。

**性能约束（必须满足）：** NodeWidget 缩略图必须缓存为 `dart:ui.Image`，key = `inkLayerId + updatedAt`；不允许每次 paint 都从 `InkLayer.strokes` 重画 CustomPaint。

---

## 背景

MarginNote 的核心体验：每个节点不仅是文本标签，还可以包含 Markdown 内容和手写批注。用户在阅读 PDF 时摘录的内容会自动生成节点，然后在节点详情中添加笔记和手写。

现有 `InkLayerOwnerType.node` 已预留节点级手写层支持。

---

## 功能规格

### 2.1 触发方式

| 操作 | 行为 |
|------|------|
| 双击节点 | 原地编辑标题（已有功能，不变） |
| 长按节点 → 菜单选择"编辑详情" | 弹出底部详情面板 |

### 2.2 详情面板布局

底部弹出 `DraggableScrollableSheet`：

```
┌─────────────────────────────────────────┐
│ ───────                              [×] │  ← 拖拽条 + 关闭按钮
├─────────────────────────────────────────┤
│ [节点标题 - 可编辑]                     │  ← 标题栏
├─────────────────────────────────────────┤
│                                         │
│   Markdown 内容区                       │  ← 全功能 Markdown 编辑器
│   （支持标题、列表、代码块等）          │
│                                         │
├─────────────────────────────────────────┤
│   手写笔记区                            │  ← 透明墨迹层叠加
│   ┌─────────────────────────────────┐   │
│   │  [手写墨迹浮在 Markdown 上方]   │   │
│   └─────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤
│   [笔] [荧光笔] [橡皮] [撤销] [清除]   │  ← 墨迹工具栏
└─────────────────────────────────────────┘
```

**关键设计决策：**
- 手写层透明叠加在 Markdown 区域上方（非分离 Tab）
- 用户可在手写层上直接看到 Markdown 内容作为参考
- 手写层独立存储，不影响 Markdown 内容

### 2.3 手写笔记缩略图

节点卡片上显示手写笔记预览：

```
┌──────────────────┐
│ 节点标题         │
│ ┌────────────┐   │
│ │ [缩略图]   │   │  ← 48x48，透明度 0.7
│ └────────────┘   │
└──────────────────┘
```

**显示规则（与 MarginNote 一致）：**
- 节点包含手写墨迹时自动显示缩略图
- 缩略图实时反映墨迹内容
- 无需用户手动标记

### 2.4 数据模型

扩展现有 Note 模型：

```dart
class Note {
  final String id;
  final String topicId;          // 所属主题 ID
  final String title;            // 节点标题
  final NoteContent? content;    // Markdown 内容（JSON segments）
  final String? inkLayerId;      // 手写层 ID（可选）
  final List<String> childIds;   // 子节点 ID
  final String? pdfId;           // 关联 PDF ID（v16 Phase 4）
  // ...
}
```

`inkLayerId` 指向 `InkLayer` 表中 `ownerType = node` 的记录。

---

## 技术方案

每个 Plan 都按「写失败测试 → 跑 FAIL → 写最小实现 → 跑 PASS → graphify → commit」的 TDD 节奏。

---

### Plan 2-A：Note 模型扩展 `inkLayerId`

**文件:**
- 修改: `lib/src/mindmap/domain/note.dart`
- 测试: `test/mindmap/domain/note_test.dart`（已存在，追加）

- [ ] **Step 1: 写失败测试**

```dart
test('Note copyWith preserves inkLayerId; toJson/fromJson roundtrips', () {
  final note = Note(id: 'n1', topicId: 't1', title: 'foo').copyWith(inkLayerId: 'layer-1');
  expect(note.inkLayerId, 'layer-1');
  final restored = Note.fromJson(note.toJson());
  expect(restored.inkLayerId, 'layer-1');
});
```

- [ ] **Step 2: 跑测试** Run: `flutter test test/mindmap/domain/note_test.dart` Expected: FAIL（`inkLayerId` 未定义）
- [ ] **Step 3: 在 `Note` 加 `final String? inkLayerId`，更新 `copyWith` / `toJson` / `fromJson`**。注意 `copyWith` 处理「显式置 null」要用 sentinel 模式或单独 `clearInkLayerId` 参数，否则无法解除关联。
- [ ] **Step 4: 跑测试** Expected: PASS
- [ ] **Step 5:** `/graphify` + commit `feat(mindmap): add Note.inkLayerId for node-level ink linkage`

---

### Plan 2-B：底部详情面板（forui DraggableScrollableSheet 壳）

**文件:**
- 创建: `lib/src/mindmap/ui/panels/node_detail_panel.dart`
- 测试: `test/mindmap/ui/panels/node_detail_panel_test.dart`

- [ ] **Step 1: 写 widget 测试** — `pumpWidget(NodeDetailPanel(note: ...))` 后断言：① 标题栏显示节点 title；② 拖拽条可见；③ 点击关闭按钮触发 `onClose` 回调
- [ ] **Step 2: 跑测试 → FAIL**（class 不存在）
- [ ] **Step 3: 创建 `NodeDetailPanel`**：`DraggableScrollableSheet(initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9)`，子树 `Column` = `[拖拽条 + 关闭按钮（forui FButton.icon）, 标题栏, Expanded(child: child slot), 工具栏 slot]`。先用占位填 Markdown / Ink slot。
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(mindmap): add NodeDetailPanel skeleton`

---

### Plan 2-C：Markdown 编辑器（实时渲染）

**文件:**
- 创建: `lib/src/mindmap/ui/editors/markdown_editor.dart`
- 测试: `test/mindmap/ui/editors/markdown_editor_test.dart`
- `pubspec.yaml`: 评估 `flutter_markdown` 是否已存在；不存在则加 `flutter_markdown: ^0.7.x` 并跑 `flutter pub get`

- [ ] **Step 1: 写测试** — 输入 `# Title`，断言 `RichText` 渲染出 H1；工具栏点击「粗体」按钮把当前光标插入 `**`；图片上传按钮触发 `onImagePicked` 回调
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现** — 左 `TextField`（多行）右 `Markdown`（flutter_markdown）实时渲染；顶部工具栏：B / I / H1 / H2 / H3 / list / code / link / image。图片选择走 `image_picker`，存到 `getApplicationDocumentsDirectory() + /node_images/<uuid>.png`。
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(mindmap): add MarkdownEditor with live preview`

---

### Plan 2-D：节点手写层编辑器（透明穿透叠加）

**文件:**
- 创建: `lib/src/mindmap/ui/editors/node_ink_editor.dart`
- 创建: `lib/src/mindmap/ui/widgets/ink_toolbar.dart`（复用 Phase 1 的工具栏，抽出共享组件）
- 测试: `test/mindmap/ui/editors/node_ink_editor_test.dart`

- [ ] **Step 1: 写测试** — 在 Markdown 区域空白处点击事件应穿透到下层（断言下层 `TextField` 获得焦点）；启用 ink 工具后同一位置点击不再穿透，画出墨迹
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现** — `Stack` 内 Markdown 在底层，墨迹层 `Listener` + `CustomPaint`（复用 Phase 1 的 `StrokeRenderer`）在上层。墨迹层用 `IgnorePointer(ignoring: !isInkActive)` 控制穿透；`ownerType = InkLayerOwnerType.node`，`ownerId = note.id`。撤销/重做用环形 buffer 保留最近 20 步（在 `InkLayerController` 上加 `pushHistory` / `undo` / `redo`，或本组件本地维护，看是否需要跨组件复用决定）。
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(mindmap): add NodeInkEditor with passthrough overlay`

---

### Plan 2-E：长按菜单 + 节点详情面板入口

**文件:**
- 修改: `lib/src/mindmap/ui/node_widget.dart`
- 修改: `lib/src/mindmap/ui/components/node_context_menu.dart`（Phase 1 已创建）
- 测试: `test/mindmap/ui/node_context_menu_test.dart`

- [ ] **Step 1: 写测试** — 长按节点弹出菜单，菜单包含「编辑详情」项，点击后调用 `showModalBottomSheet` 渲染 `NodeDetailPanel`
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 在 `NodeContextMenu` 追加「编辑详情」入口；`NodeWidget.onLongPress` 处接入**
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(mindmap): wire node long-press to detail panel`

---

### Plan 2-F：节点卡片缩略图（带缓存，强制约束）

**文件:**
- 创建: `lib/src/mindmap/ui/painters/ink_thumbnail_painter.dart`
- 创建: `lib/src/mindmap/ui/widgets/ink_thumbnail_cache.dart`
- 修改: `lib/src/mindmap/ui/node_widget.dart`
- 测试: `test/mindmap/ui/painters/ink_thumbnail_cache_test.dart`

**性能约束（必须满足）：** 缩略图通过 `PictureRecorder` → `Picture.toImage(48, 48)` 生成 `dart:ui.Image`，按 `inkLayerId + updatedAt` 做 LRU 缓存（容量 100）。NodeWidget 直接 `RawImage(image: cached)`，**不允许每次 paint 都重画 CustomPaint**。

- [ ] **Step 1: 写测试**

```dart
test('thumbnail cache returns same Image when inkLayerId+updatedAt unchanged', () async {
  final cache = InkThumbnailCache();
  final layer = InkLayer(...);
  final img1 = await cache.getOrBuild(layer);
  final img2 = await cache.getOrBuild(layer);
  expect(identical(img1, img2), isTrue);
});

test('thumbnail cache rebuilds when updatedAt changes', () async {
  final cache = InkThumbnailCache();
  final layer1 = InkLayer(updatedAt: t1, ...);
  final layer2 = layer1.copyWith(updatedAt: t2);
  expect(identical(await cache.getOrBuild(layer1), await cache.getOrBuild(layer2)), isFalse);
});
```

- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现 `InkThumbnailCache`（`LinkedHashMap<String, ui.Image>`，容量 100，溢出按 LRU 淘汰）+ `InkThumbnailPainter`**
- [ ] **Step 4: 在 `NodeWidget` 中：若 `note.inkLayerId != null`，从注入的 `InkLayerRepository` 拿到 layer，调用 `cache.getOrBuild(layer)`，再用 `RawImage(opacity: 0.7)` 显示**
- [ ] **Step 5: 跑测试 → PASS**
- [ ] **Step 6:** `/graphify` + commit `feat(mindmap): add cached ink thumbnail on node card`

---

## 交付物清单

| 文件路径 | 说明 |
|----------|------|
| `lib/src/mindmap/domain/note.dart` | Note 模型扩展（inkLayerId） |
| `lib/src/mindmap/ui/panels/node_detail_panel.dart` | 底部详情面板（深色主题） |
| `lib/src/mindmap/ui/editors/markdown_editor.dart` | Markdown 编辑器（实时渲染） |
| `lib/src/mindmap/ui/editors/node_ink_editor.dart` | 节点手写编辑器（4 种工具） |
| `lib/src/mindmap/ui/widgets/ink_toolbar.dart` | 手写工具栏（复用于画布和节点） |
| `lib/src/mindmap/ui/painters/ink_thumbnail_painter.dart` | 缩略图绘制器 |
| `lib/src/mindmap/ui/node_widget.dart` | 长按菜单 + 缩略图 |

---

## 验收标准

- [ ] 长按节点 → 菜单显示"编辑详情"选项
- [ ] 点击"编辑详情" → 底部弹出详情面板
- [ ] 详情面板可拖拽调整高度（0.5-0.9）
- [ ] Markdown 编辑器支持基本格式（粗体、列表、代码）
- [ ] 手写层透明叠加，可独立绘制
- [ ] 手写内容实时保存
- [ ] 关闭面板后再次打开，内容保留
- [ ] 节点卡片显示手写缩略图（有墨迹时）
- [ ] 双击节点仍为原地编辑标题（不受影响）

---

## 依赖

- Phase 1（手写画布层 - 墨迹渲染基础设施）
- v15 Phase 2（原地编辑 - 双击交互已实现）

---

## 设计决策（已锁定）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| Markdown 编辑器 | 完整功能 | 表格、代码高亮、图片上传、链接等 |
| Markdown 预览 | 实时渲染 | 边编辑边渲染，无分栏 |
| 图片存储 | 本地存储 | 存到应用本地文件系统 |
| 手写层交互 | 穿透模式 | 透明叠加，点击事件穿透到下层 Markdown |
| 缩略图显示 | 自动显示 | 有墨迹即显示，与 MarginNote 一致 |
| 工具栏位置 | 面板底部固定 | 不跟随键盘 |
| 详情面板主题 | 深色主题 | 金色边框，与底部操作栏一致 |
| 手写工具 | 4 种 | 钢笔/铅笔、荧光笔、橡皮擦、套索工具 |
| 笔迹颜色 | 8 种基础色 | 红、橙、黄、绿、蓝、紫、黑、灰 |
| 笔迹粗细 | 自定义滑块 | 用户可调节粗细 |
| 荧光笔颜色 | 5 种荧光色 | 半透明黄、绿、蓝、粉、橙 |
| 撤销/重做 | 20 步 | 最多撤销最近 20 步操作 |

---

## 待澄清问题

无
