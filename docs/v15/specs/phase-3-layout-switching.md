# Phase 3 Spec：布局切换、框架式布局与菜单位置

## 背景

当前布局菜单可选择不同布局，但实际视觉变化不稳定；框架式布局已有 `FrameworkLayout` 和 `layoutStyle == 'framework'` 分支，却没有在布局切换入口中形成稳定可用能力。布局方向和框架式布局应成为导图级设置，而不是依赖单个节点的 `layoutStyle`。布局弹窗位置也应对齐 `prototype/思维导图页面/index.html`。

## 用户故事

- 作为用户，我打开布局菜单，菜单出现在底部布局按钮正上方且居中。
- 作为用户，我选择两侧、左侧、右侧布局时，节点方向立即发生可见变化。
- 作为用户，我可以选择框架式布局，并看到已有框架式卡片布局效果。

## 项目落点

- `lib/src/mindmap/ui/tree_layout.dart`
  - `LayoutDirection.vertical` 暂时保留但标记为实验性，不在布局菜单中展示。
- `lib/src/mindmap/ui/mindmap_controller.dart`
  - 修正 `changeLayoutDirection` 与 `recalculateLayout` 的刷新链路。
  - `changeLayoutDirection` 必须触发布局重算；否则底部菜单状态变化但节点坐标不变。
  - 明确 `LayoutDirection.horizontal` 对应 `LayoutStrategy.rightOnly`，但 UI 文案使用”右侧布局”。
  - 明确 `LayoutDirection.left` 对应 `LayoutStrategy.leftOnly`，不能继续落到 `rightOnly`。
  - 新增导图级布局状态，例如 `Topic.layoutDirection` 与 `Topic.layoutStyle`，或等价 Topic settings。
  - `Note.layoutStyle` 仅作为历史数据或导入兼容入口，不作为当前 UI 判断整棵树是否框架布局的来源。
  - 框架式布局可从任意导图切换进入，无需特定数据结构。
- `lib/src/mindmap/domain/topic.dart`、`lib/src/mindmap/storage/mindmap_repository.dart`、`rust/src/storage/mindmap.rs`
  - 补齐导图级布局状态的持久化字段和默认值。
  - 旧数据缺失布局字段时，默认使用两侧布局和普通树形布局。
- `lib/src/mindmap/ui/bottom_action_bar.dart`
  - 将 `showMenu` 定位改为按钮正上方、宽度约 100px、居中对齐，间距 2-8px。
  - 菜单项包含：两侧布局、左侧布局、右侧布局、框架式布局。
- `lib/src/mindmap/ui/mindmap_page.dart`
  - 框架式布局分支使用明确的导图级状态，避免混合根节点误判。

## 原型位置约束

参考 `prototype/思维导图页面/index.html`：

- `.layout-dropdown` 宽度为 100px。
- `left = button.left + button.width / 2 - 50`。
- `top = button.top - menu.height - 2`，Flutter 可根据实际菜单高度换算为 2-8px 间距。

## 验收标准

- 三种树形布局切换后，节点坐标重新计算且视觉方向变化。
- 框架式布局可从菜单进入，可从其他布局切回。
- 关闭并重新打开导图后，最近选择的布局方向与布局样式仍然保留。
- 布局菜单不遮挡底部工具栏，不跑到按钮下方或屏幕边缘。
- 左侧、右侧、短标题、长标题节点的父子连线仍贴边。
