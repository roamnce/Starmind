# GuruMind 导入入口与状态错乱修复交付记录

## 修复内容

- 将 GuruMind 导入入口从思维导图页“更多操作”移除，新增到主页“新建/导入”菜单。
- 主页导入成功后刷新主页思维导图列表，并通过 `WorkspaceController.openMindMap(importedTopic.id, importedTopic.title)` 打开导入结果的独立标签页。
- 移除 `MindMapController.importGuruMindFile()`，避免在当前已打开 topic controller 内执行 `selectTopic(importedTopic)` 污染标签页状态。
- 将 Rust `update_topic` 和 `update_note` 改为 `INSERT ... ON CONFLICT DO UPDATE`，让 GuruMind 导入的新 topic/note 能真实写入 FFI SQLite。
- 修复 GuruMind note `parentId` 未加 `1-` 前缀的问题，使 `id`、`parentId`、`childIds`、`rootNoteIds` 使用一致的 Starmind note ID 格式。

## 验证结果

- `cargo check`：通过；仅保留既有 `rust/src/api/pdf.rs` 两条 warning。
- `cargo build --release`：通过；已重建 `rust/target/release/rust_lib_starmind.dll`。
- `flutter test test/mindmap/storage/ffi_mindmap_repository_test.dart test/mindmap/import --reporter expanded`：通过，`+21: All tests passed!`。
- `flutter test --reporter expanded`：通过，`+469: All tests passed!`。
- 临时 SQLite + FFI 导入 `D:\个人文件\Downloads\演示.gurumind`：成功，topic title 为 `演示`，FFI `getAllTopics()` 返回 1 个导入 topic，导图树 root 数为 7，可达导图节点数为 18；额外 1 个 `2-` 节点是非导图笔记节点，不属于导图树 root/child 链。

## 仍需注意

- `dart analyze` 对 `lib/main.dart` 仍报告 6 条既有 `use_build_context_synchronously` info，位置集中在 PDF 导出相关旧代码，不属于本次 GuruMind 导入修复链路。
