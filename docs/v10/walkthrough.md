# Phase1–Phase4 规格审计与交付记录

## 规格正确性审视

- Phase1 布局引擎重构：规格与当前项目结构一致，`layout/`、`rendering/`、`ui/canvas_painter.dart` 路径均可落地；性能和覆盖率门槛需要通过持续测试/benchmark 证明。
- Phase2 手写层：规格方向正确；已补齐 Dart 手写模型/控制器/UI、JSON/内存仓储，并新增 Rust SQLite `ink_layers` 表、FRB API 与 Dart FFI 仓储。
- Phase3 GuruMind 导入：规格正确；导入器支持真实样本 `D:\个人文件\Downloads\演示.gurumind`，可解析 `documents/<id>/meta.json + doc_*.hive`、manifest documents、图片资源和 topic hive 内导图节点。
- Phase4 导出与刷题：规格正确；导出器生成规范 `documents/` 目录、mindMap/note `meta.json`、`doc_*.hive`、缩略图资源与 manifest documents；刷题模式已接入页面快捷键、更多菜单、进度面板、刷题题卡与节点级手写叠加。

## 当前完成映射

| 阶段 | 规格任务 | 当前证据 |
| --- | --- | --- |
| Phase1 | LayoutEngine、TreeLayoutEngine、AnchorCalculator、三类 ConnectionRenderer、CanvasPainter 集成 | 已存在于 `lib/src/mindmap/layout/`、`lib/src/mindmap/rendering/`，并有 `test/mindmap/layout/`、`test/mindmap/rendering/` 覆盖 |
| Phase2 | InkLayer、InkLayerController、画布手写、荧光笔、橡皮擦、套索移动、节点级手写、持久化、Rust FFI 存储 | `lib/src/mindmap/ink/`、`rust/src/storage/ink_layers.rs`、`lib/src/rust/storage/ink_layers.dart`、`test/mindmap/ink/`；画布手写与节点级手写均通过 `MindMapPage`/`StudyNoteWidget` 进入 UI 并保存到 FFI |
| Phase3 | ZIP 解析、manifest/meta 解析、HiveDecoder、数据转换、导入主类、资源复制、UI 导入入口 | `lib/src/mindmap/import/`；`MindMapPage` 更多菜单“导入 GuruMind”；真实样本条件测试、导出回读测试和 `documents/` 结构验证测试 |
| Phase4 | HiveEncoder、GuruMindDataExporter、资源导出、缩略图、StudyModeController、StudyNoteWidget、StudyModePanel、快捷键、UI 导出入口 | `lib/src/mindmap/export/`、`lib/src/mindmap/study/`、`lib/src/mindmap/ui/mindmap_page.dart` 集成；更多菜单“导出 GuruMind/进入刷题模式/开启画布手写”；测试 `test/mindmap/export/`、`test/mindmap/study/` |

## 本次 review 后修正

- UI 接入：确认原先 GuruMind 导入/导出没有用户入口，“更多操作”按钮为空；已接入导入、导出、刷题模式、画布手写开关。
- 手写持久化：确认原先 `CanvasInkLayer` 只连到内存 controller；已加载/保存 canvas 与 node 两类 `ink_layers`。
- 节点级手写：确认 `StudyNoteWidget`/`NodeNoteContent` 曾只创建文件未渲染；已在刷题模式右侧显示题卡，并支持在图片/正文上叠加手写。
- 评审问题：多根布局只布局 `_noteTree.first` 的判断正确，已合并所有 root 布局结果；刷题候选包含纯标题节点的判断正确，已改为正文/图片/填空/摘录/媒体节点。
- 评审过期点：`ink_layers` SQLite 表与 FRB API 已存在并通过 FFI 测试；“Phase1–4 100% 完成”的结论在 UI 接入口补齐前不准确，本轮已补齐主要入口。

## 已运行验证

- `flutter_rust_bridge_codegen generate`：通过，已生成 `lib/src/rust/storage/ink_layers.dart` 与对应 API。
- `cargo build --release`：通过，生成 `rust/target/release/rust_lib_starmind.dll`。
- `cargo check`：通过；仅保留既有 `rust/src/api/pdf.rs` 两条 warning。
- `flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart --reporter expanded`：15 项 FFI 集成测试实际通过。
- `flutter test test/mindmap/ink`：通过，输出 `+3: All tests passed!`。
- `flutter test test/mindmap/import`：通过，包含真实 GuruMind 样本条件测试。
- `flutter test test/mindmap/export/gurumind_exporter_test.dart`：通过，输出 `+2: All tests passed!`。
- `flutter test --reporter expanded`：通过，输出 `+465: All tests passed!`。
- 定向 `dart analyze`：本轮新增/改动关键文件均输出 `No issues found!`。
- `flutter test test/mindmap/study test/mindmap/export test/mindmap/import --reporter expanded`：通过，输出 `+5: All tests passed!`。
- `flutter analyze`：仍有既有 warning/info，集中在 `lib/main.dart`、旧测试 unused import、旧 PDF 测试 override 等。

## 仅剩外部验证

- 外部 GuruMind 应用打开导出的 `.gurumind` 文件：当前机器未找到 `GuruMind.exe`，无法执行最终应用级打开验证。
