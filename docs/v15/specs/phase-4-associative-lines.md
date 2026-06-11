# Phase 4 Spec：跨节点关联线

## 背景

关联线用于表达有方向的非父子层级关系。可参考 `E:/app/wanglin-mindmap/simple-mind-map/src/plugins/AssociativeLine.js` 的“从当前激活节点连接到目标节点、终点带箭头、可带默认文字”的交互，也可参考 `D:/package/mind_map_flutter` 中 `ArrowData.fromNodeId/toNodeId` 与箭头创建流程，但实现应适配 Flutter Canvas 与本项目数据层。

## 用户故事

- 作为用户，我选中一个节点后点击“关联线”，再点击另一个节点，可以创建一条从起点指向终点的关联线。
- 作为用户，我未选中节点时点击“关联线”，会看到气泡提示“创建连线前需要先选择一个起始节点”。
- 作为用户，我能看到关联线连接在两个节点边界，而不是连接到中心点或悬空。
- 作为用户，我可以选中关联线，编辑文字或删除关联线。

## 数据模型建议

新增 Dart domain：`lib/src/mindmap/domain/mindmap_relation.dart`。

字段建议：

- `id`：关联线 ID。
- `topicId`：所属导图。
- `sourceNoteId`：起点节点，关联线从该节点发出。
- `targetNoteId`：终点节点，关联线指向该节点。
- `text`：默认“关联”。
- `controlPoints`：可选控制点，用于后续拖拽调线。
- `style`：可选样式，默认虚线或当前主题关联线样式。
- `createdAt`、`updatedAt`。

## 项目落点

- `lib/src/mindmap/domain/mindmap_relation.dart`：新增模型与 JSON 映射。
- `lib/src/mindmap/storage/mindmap_repository.dart`：新增关联线 CRUD 接口。
- `lib/src/mindmap/storage/in_memory_mindmap_repository.dart`：补齐内存实现和测试夹具。
- `lib/src/mindmap/storage/ffi_mindmap_repository.dart`、`rust/src/storage/mindmap.rs`：补齐持久化实现。
- `lib/src/mindmap/service/mindmap_service.dart`：提供 `createRelation`、`updateRelation`、`deleteRelation`、`listRelations`。
- `lib/src/mindmap/ui/mindmap_controller.dart`：新增 `RelationCreationMode` 或等价状态，保存起点节点、当前待选终点；未选中起点时暴露气泡提示事件。
- `lib/src/mindmap/ui/canvas_painter.dart`：渲染关联线和文字。

## 交互规则

1. 未选中节点时点击关联线按钮，不进入创建状态，并显示气泡提示”创建连线前需要先选择一个起始节点”。
2. 选中节点 A 后点击关联线按钮，进入”选择终点”状态，A 作为起点。
3. 点击节点 B 创建 `A -> B` 关联线，默认文本为”关联”。
4. 创建过程中悬停或移动到可作为终点的节点时，应给目标节点临时高亮反馈。
3. 点击空白区域取消创建状态。
4. 点击关联线进入关联线选中态；选中后显示控制点，允许拖拽调整曲线形状；再次点击文字或快捷键进入编辑。
5. 不允许 A 到 A 的关联线。
6. 同一方向的重复关联线不新增；再次创建 `A -> B` 时选中已有 `A -> B` 关联线。
7. 反向关联线视为不同关系，允许同时存在 `A -> B` 与 `B -> A`。

## 样式规则

- 关联线默认为实线，颜色跟随当前主题。
- 关联线终点默认显示箭头。
- 选中态显示控制点，支持拖拽调整曲线。

## 验证要求

- 必须验证逻辑 Rect 与真实 Widget Rect 是否一致。
- 必须覆盖左侧布局、右侧布局、两侧布局。
- 必须覆盖短标题节点和长标题节点。
- 删除节点时，应删除或隐藏与该节点相关的关联线，不能留下断线。

## 验收标准

- 关联线创建、显示、编辑文字、删除均可用。
- 未选中节点时点击关联线按钮会出现起点选择提示。
- `A -> B` 与 `B -> A` 可同时存在，并能通过箭头方向区分。
- 切换布局后，关联线重新计算锚点并保持贴边。
- 保存并重新打开导图后，关联线仍存在。
