# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在本仓库中工作时提供指引。

## 指令优先级

`RULES.md`（仓库根目录，待创建）的优先级高于 agent 的默认习惯和本文件的通用建议。冲突时以 `RULES.md` 为准；`RULES.md` 未覆盖的内容才回落到本文件。

## 工作流约束

### Git Flow 分支策略

- 长期分支：`main`（生产）、`develop`（集成）。
- 短期分支前缀：
  - `feature/<topic>` 从 `develop` 切出，完成后合回 `develop`。
  - `release/<version>` 从 `develop` 切出，测试稳定后合回 `main` 并打 tag，再合回 `develop`。
  - `hotfix/<issue>` 从 `main` 切出，合回 `main` 并打 tag，再合回 `develop`。
  - `bugfix/<issue>` 从 `develop` 切出，仅修非生产缺陷。
- 不在 `main` / `develop` 上直接提交；所有变更通过 PR 合入。
- 分支名用小写连字符（`feature/mindmap-relation-anchor`），不用驼峰或空格。

### Conventional Commit（Angular 规范）

提交信息格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

- `type` 取值：`feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`。
- `scope` 用模块名（如 `mindmap`、`pdf`、`storage`、`ffi`）；跨模块或纯仓库级变更可省略。
- `subject` 用祈使句，首字母小写，结尾不加句号，控制在 72 字符内。
- 破坏性变更：在 `type` 后加 `!`（如 `feat(storage)!:`），并在 footer 写 `BREAKING CHANGE: <说明>`。
- 关联 issue：footer 写 `Refs: .scratch/<feature>/NNN-xxx.md` 或 `Closes #N`。
- 一条 commit 一件事；切勿把无关变更塞进同一次提交。

### Doxygen 风格注释

公共 API（Dart 的 `public` 类/函数、Rust 的 `pub fn`/`pub struct`）必须写 Doxygen/dartdoc 兼容注释。

- Dart 用 `///` 三斜线注释，Rust 用 `///` 文档注释。
- 必备字段：简短描述（首行）、空行后展开说明，再按需附 `@param` / `@return` / `@throws`（Rust 用 `# Arguments` / `# Returns` / `# Errors` / `# Panics`、`# Safety`）。
- `unsafe` 块旁必须紧跟 `// SAFETY:` 注释，说明为何安全前提成立。
- 私有/内部 helper 不强制，但若行为非显然应补一行说明 WHY。
- 不写 WHAT 类废话注释（"set x to 1"），只写 WHY 和不变式。

Dart 示例：

```dart
/// 把摘录文本作为子节点挂到目标 Topic 的根节点下。
///
/// 摘录来源（页码、矩形）写入 [NoteContent.pdfPosition]；调用者保证
/// [topicId] 存在。
///
/// @param topicId 目标思维导图 ID。
/// @param excerpt PDF 摘录原文。
/// @return 新创建的 [Note] 实例。
/// @throws StateError 如果 [topicId] 不存在。
Future<Note> attachExcerpt(String topicId, String excerpt) { ... }
```

Rust 示例：

```rust
/// 在事务里批量插入 mindmap 节点，保持 child_ids 顺序。
///
/// # Arguments
/// * `topic_id` - 所属 Topic UUID。
/// * `notes`    - 按插入顺序排列的节点列表。
///
/// # Errors
/// 返回 `StorageError::Sqlite` 若任何一行违反外键约束；事务整体回滚。
pub fn insert_notes(topic_id: &str, notes: &[Note]) -> Result<(), StorageError> { ... }
```

### 架构原则：高内聚、低耦合

- **按领域分层。** `domain/` 只放纯数据和接口，不引用 Flutter 框架或 FFI；`service/` 编排仓库；`ui/` 不直接调仓库，必须经 controller/service。
- **依赖朝向单一。** 上层依赖下层（UI → service → repository → FFI/storage），下层不感知上层。新增的 import 不要逆流。
- **接口隔离。** Controller/Service 依赖 `*Repository` 接口而非 `Ffi*Repository` 具体类，测试用内存实现替换。
- **不要泄漏 FFI 类型。** 生成的 `lib/src/rust/` 类型只能出现在 `Ffi*Repository` 内；其它代码用 Dart 侧 domain model。
- **跨模块通信用接口或事件，不用全局可变状态。** 若发现需要单例承载状态，先想清楚是否能下沉到 controller。
- **新增模块前先问：现有目录够不够？** 不要为单个文件造新顶层包；优先扩展 `mindmap/`、`pdf/`、`home/`、`domain/` 中已存在的子目录。

Starmind 是一款 PDF 阅读 + 思维导图的 Flutter 桌面/移动应用，通过 `flutter_rust_bridge` 2.12 桥接 Rust 后端。持久化用 SQLite（`rusqlite` bundled），PDF 渲染用 `pdfium-render`——两者都在 Rust 侧。Dart 侧负责 UI、手势、编排；Rust 侧负责存储和 PDF I/O。

UI 组件库统一用 **forui**（`forui: ^0.22.3`）。新写界面前先查 forui 文档 <https://forui.dev/docs>；只有 forui 没覆盖的场景才回落到 Material/Cupertino，并在 PR 说明里写清楚原因。不要为同一交互混用 forui 与 Material 控件——视觉漂移成本高。

做任何功能前先读 `CONTEXT.md`，它是领域术语（Document、Folder、Tag、Workspace、Split Panel、Topic、Note、MindMapRelation、MindMapSummary 等）的唯一来源。代码和文档里的术语必须与之一致。`AGENTS.md` 列出项目级 agent 约定（issue tracker、文档版本化、思维导图调试守则）。

## 常用命令

```bash
flutter pub get                          # 拉取 Dart 依赖
flutter run -d windows                   # 运行桌面端（或 -d linux/macos/chrome/<device>）
flutter analyze                          # 静态分析（lint 配置在 analysis_options.yaml）
flutter test                             # 运行 test/ 下的单元和 widget 测试
flutter test test/mindmap/storage/mindmap_repository_test.dart   # 单个测试文件
flutter test --plain-name "saves topic"  # 按名称过滤
flutter test --coverage                  # 输出 coverage/lcov.info
flutter test integration_test/simple_test.dart   # 集成测试（需要设备）
```

Rust 侧：

```bash
cd rust && cargo build                   # 单独编译 Rust 库
cd rust && cargo test                    # Rust 单元测试
flutter_rust_bridge_codegen generate     # 修改 rust/src/api/* 后重新生成 FFI 绑定
```

`flutter_rust_bridge.yaml` 配置 codegen：Rust 输入 `crate::api`，Dart 输出 `lib/src/rust`。**不要手改 `lib/src/rust/` 或 `rust/src/frb_generated.rs` 里的文件**——它们是自动生成的。

## 代码探索（graphify）

`graphify-out/` 是 **`lib/` 全部 + `rust/src/` 全部** 的知识图谱快照（含 `GRAPH_REPORT.md`、`graph.html`、`graph.json`、`manifest.json`）。**找函数关系优先看这里，再做单点 Grep**——比一个个搜索高效得多。

> 历史快照仅覆盖 `lib/src/pdf` + `lib/src/mindmap`，下一次 `/graphify` 会扩到全量范围。看到 `GRAPH_REPORT.md` 顶部仍是旧范围时立即重跑。

- **入口**：`graphify-out/GRAPH_REPORT.md`——按 Community Hubs 找子系统，按 God Nodes 看核心抽象，按 Surprising Connections 找隐性耦合。
- **可视化**：浏览器打开 `graphify-out/graph.html`，按节点/社区/边过滤。
- **原始数据**：`graph.json` 适合脚本化查询。
- **新鲜度**：`manifest.json` 记录每个文件的 mtime + hash；与现实代码差距明显时报告已过期，必须重跑。

**更新规则**：修改 `lib/` 或 `rust/src/` 下任何文件完成后跑 `/graphify` 重建快照；否则下一次探索仍读旧图，等于在过期地图上行军。该规则提升为铁律，见 `RULES.md §1.7`。

## 架构

### 分层结构
```
lib/main.dart                    # 入口：RustLib.init() 然后 WorkspacePage shell
lib/src/
  domain/                        # Dart 侧领域模型 + 仓库接口（storage_repository、document、folder、tag、annotation）
  home/                          # WorkspaceController、tab/split-panel 布局、侧边栏导航
  pdf/                           # PDF 视口、手势分发、墨迹笔画、切片渲染
  mindmap/
    domain/                      # Topic、Note、MindMapRelation、MindMapSummary、MindMapNoteTag
    storage/                     # MindMapRepository 接口 + FFI 与内存实现
    service/                     # MindMapService——编排仓库 + 导入/导出
    layout/                      # TreeLayoutEngine、AnchorCalculator、LayoutResult
    ui/                          # MindMapPage、controller、framework_layout、node_widget
    ink/、import/、export/、rendering/
  rust/                          # 生成的 FFI 绑定——不要编辑
rust/src/
  api/                           # 暴露给 Dart 的 Rust 函数（storage.rs、pdf.rs、simple.rs）
  storage/                       # SQLite 仓库：documents、folders、tags、annotations、ink_layers、mindmap
```

### 关键约定

- **Repository 模式，双实现。** 每个领域有一个接口（`MindMapRepository`、`StorageRepository`），一个走 FFI 的真实实现（`FfiMindMapRepository` → 通过 `flutter_rust_bridge` 调 Rust），以及一个用于测试的内存实现。Service 只依赖接口；`main.dart` 注入 `Ffi*Repository`。
- **Workspace 是 Split Panel 树。** `WorkspaceController` 持有 `rootLayoutNode`，递归地是 `LeafNode`（tabs + 当前索引）或 `ParentNode`（横/纵分屏）。当前 `main.dart` 直接 cast 成 `LeafNode`，因为分屏尚未接入 UI。
- **Controller 按 tab id 缓存。** `_WorkspacePageState` 维护 `_pdfControllers[docId]` 和 `_mindMapControllers[topicId]`，打开/关闭 tab 时复用状态。tab 关闭时 dispose。`MindMapService` 在所有思维导图 controller 间共享。
- **PDF 渲染是双层。** 低清整页预览始终显示；平移/缩放停止后，`tile_manager` 向 Rust 请求可见区域的高清切片（`render_scheduler`、`static_picture_cache`）并叠加覆盖。视口变换是 `Matrix4`——页面在布局树中是固定尺寸，缩放完全由图形变换层处理。
- **墨迹与视口的手势路由。** `gesture_dispatcher` 把单指/触控笔笔尖路由到墨迹层（绘制），双指/掌侧防误触路由到视口平移缩放——无需切换工具。详见 `CONTEXT.md` "手势路由" 一节。

### 跨越 FFI 边界
1. 在 `rust/src/api/storage.rs`（或 `pdf.rs`）里加一个 `pub fn`（通常 `async`）。
2. 共享类型用 `serde`-derive 的 struct；基本类型和 `String`/`Vec` 原生跨越。
3. 跑 `flutter_rust_bridge_codegen generate`，绑定会出现在 `lib/src/rust/api/...`。
4. 从 Dart 调用生成的函数；用对应的 `Ffi*Repository` 包一层，让其它代码永远不直接 import `lib/src/rust/`。

## 项目约定（来自 AGENTS.md）

- **Issue tracker。** 本地 markdown，位于 `.scratch/<feature>/NNN-title.md`，带 YAML front matter（`status`、`priority`、`assignee`、`created`）。不用 GitHub project。详见 `docs/agents/issue-tracker.md` 和 `docs/agents/triage-labels.md`。
- **版本化开发文档。** 每次迭代放到 `docs/vN/`（目前到 `v17`）。实现计划、walkthrough、分析——全部归到对应版本文件夹下。不要往 `docs/` 根目录里堆新文档。
- **ADR。** 架构决策记录放 `docs/adr/`（文件夹尚未创建，加第一个 ADR 时再建）。
- **PROGRESS 长期记忆。** 见仓库根 `PROGRESS.md`。每条经验/踩坑/决策落一份 entry 到 `docs/progress/entries/YYYY/YYYY-MM-DD-N.md`，并在 `PROGRESS.md` 的 Global TOC 追加一行。**没有 Related Commit Message 的 entry 不允许入库**；Commit Hash 在 commit 落地后补齐。
- **思维导图连线调试。** 修连线问题时，必须同时验证逻辑 `Rect` 和真实 widget `Rect`，左右两侧分别检查，短标题和长标题节点分别检查。只验证坐标公式曾导致过回归——见 `docs/analysis/mindmap-right-connection-gap-special-case.md`。

## gstack 网页自动化

所有网页浏览都走 gstack 的 `/browse` skill。**绝不使用 `mcp__claude-in-chrome__*` 工具。**

可用 gstack skills：`/office-hours`、`/plan-ceo-review`、`/plan-eng-review`、`/plan-design-review`、`/design-consultation`、`/design-shotgun`、`/design-html`、`/review`、`/ship`、`/land-and-deploy`、`/canary`、`/benchmark`、`/browse`、`/connect-chrome`、`/qa`、`/qa-only`、`/design-review`、`/setup-browser-cookies`、`/setup-deploy`、`/setup-gbrain`、`/retro`、`/investigate`、`/document-release`、`/document-generate`、`/codex`、`/cso`、`/autoplan`、`/plan-devex-review`、`/devex-review`、`/careful`、`/freeze`、`/guard`、`/unfreeze`、`/gstack-upgrade`、`/learn`。
