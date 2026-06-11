# Phase 6 Spec：节点标签

## 背景

标签用于快速标记节点主题、状态或分类。可参考 `E:/app/wanglin-mindmap/simple-mind-map/src/constants/defaultOptions.js` 的 `tagsColorMap` 与 XMind 解析中的 `tag` 字段，但本项目需要与现有 `lib/src/domain/tag.dart` 和 `rust/src/storage/tags.rs` 对齐。

## 用户故事

- 作为用户，我选中节点后点击“创建标签”，可以给节点添加一个标签。
- 作为用户，我能在节点标题下方或右侧看到标签胶囊。
- 作为用户，我可以删除某个节点标签，也可以复用已有标签。

## 数据模型建议

复用现有全局 `lib/src/domain/tag.dart`，但将 Tag 语义扩展为可绑定到不同知识对象的全局知识分类标签。节点标签不是导图私有标签，也不用于表达优先级、进度、状态等局部标记；这类局部标记继续使用导图节点图标能力。

节点侧需要新增”节点引用了哪些标签”的持久化关系：

- 保留全局 `tags` 表和 Tag 树。
- 新增节点-标签绑定关系，例如 `mindmap_note_tags(note_id, tag_id)`。
- 不建议把 `tagIds` 直接作为 `Note` 的长期存储字段。
- 标签数量无上限。

## 项目落点

- `lib/src/mindmap/domain/note.dart`：保持节点实体聚焦节点内容与结构，不把标签绑定长期固化为节点字段。
- `lib/src/domain/tag.dart`：确认标签 ID、名称、颜色结构是否满足导图节点展示。
- `lib/src/mindmap/service/mindmap_service.dart`：新增节点标签增删改查方法。
- `lib/src/mindmap/ui/node_widget.dart`：在节点内标题下方展示标签胶囊，最多展示 2-3 个，超出显示 `+N`。
- `lib/src/mindmap/ui/mindmap_page.dart` 或新增轻量浮层：标签输入和已有标签选择。
- `rust/src/storage/tags.rs`、`rust/src/storage/mindmap.rs`、`rust/src/storage/db.rs`：补齐节点-标签绑定关系和级联删除。

## 交互规则

1. 选中节点后点击标签按钮，弹出小型输入浮层，位置靠近节点或底部工具栏按钮。
2. 输入新标签名并回车：创建或复用同名标签，并绑定到节点。
3. 点击标签上的删除按钮：仅从当前节点解绑，不删除全局标签。
4. 标签颜色根据标签名哈希生成随机颜色。
5. 标签显示在节点标题下方。
6. 删除全局 Tag 时，级联删除 Document 与 Mind Map Node 的绑定。
7. v15 暂不在 Tag 树中展示节点引用计数；后续需要区分 Document count 与 Node count。

## 验收标准

- 标签添加后立即显示在节点上。
- 标签随节点持久化，重新打开导图后仍显示。
- 删除标签绑定不会删除节点。
- 长标签不会撑破节点，节点布局能根据真实尺寸重新计算。
