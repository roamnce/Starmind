# Phase 1 Spec：拖动模式下节点选择

## 背景

当前底部工具栏存在拖动模式和框选模式，但拖动模式下节点点击需要明确成为“选择节点”，不能因为处于画布拖动工具而失去节点选择能力。

## 用户故事

- 作为用户，我选择拖动工具后，仍然可以单击任意节点让它成为当前节点。
- 作为用户，我单击空白画布时，可以取消当前节点选择。
- 作为用户，我能通过选中态看到当前节点，后续添加、编辑、标签、关联线都基于这个选中节点。

## 项目落点

- `lib/src/mindmap/ui/mindmap_controller.dart`
  - 明确 `selectNote(Note?)` 与 `_selectedNoteIds` 的同步规则。
  - 拖动模式单选时只保留一个选中节点；框选模式保留多选集合。
- `lib/src/mindmap/ui/mindmap_page.dart`
  - 节点 `onTap` 在 `CanvasInteractMode.drag` 下调用 `controller.selectNote(note)`。
  - 画布空白区域点击调用 `controller.selectNote(null)`，但不能影响双击编辑和拖动画布。
- `lib/src/mindmap/ui/node_widget.dart`
  - 继续以 `selectedNoteIds` 或 `selectedNote` 驱动选中边框。

## 交互规则

1. 拖动模式：
   - 单击节点：选中该节点。
   - 单击空白画布：清空当前单选。
   - 按住画布拖动：平移画布，不改变选择。
2. 框选模式：
   - 保留现有框选语义。
   - 单击节点时将该节点加入已选集合。
3. 锁定模式：
   - 锁定后不允许编辑，但仍允许选择和查看节点。

## 验收标准

- 拖动工具高亮时，单击节点会出现选中边框。
- 点击底部“添加子节点”“添加同级节点”时，以刚刚单击的节点为目标。
- 空白点击不会误创建节点，不会触发编辑态。
- 新增或调整单元测试覆盖 `selectNote` 与 `selectedNoteIds` 同步。
