# v15 任务说明：思维导图基础功能可用化

## 目标

围绕思维导图当前最影响可用性的基础功能，先形成开发蓝图，再按阶段推进规格和实现。

## 文档入口

- 开发蓝图：`docs/v15/development_blueprint.md`
- Phase 1-3 收尾：`docs/v15/walkthrough.md`
- 已知问题：`docs/v15/known_issues.md`
- Phase 1：`docs/v15/specs/phase-1-selection-and-inline-editing.md`
- Phase 2：`docs/v15/specs/phase-2-inline-node-creation.md`
- Phase 3：`docs/v15/specs/phase-3-layout-switching.md`
- Phase 4：`docs/v15/specs/phase-4-associative-lines.md`
- Phase 5：`docs/v15/specs/phase-5-summary-nodes.md`
- Phase 6：`docs/v15/specs/phase-6-node-tags.md`
- Phase 7：`docs/v15/specs/phase-7-polish-and-regression.md`

## 外部参考

- `D:/package/hierarchy`：参考层级布局与路径绘制思路。
- `E:/app/wanglin-mindmap/simple-mind-map`：参考关联线、概要、标签、布局切换的成熟交互与数据表达。
- `prototype/思维导图页面/index.html`：参考底部工具栏与布菜单位置。

## 执行计划

- Phase 1-3 计划：`docs/v15/implementation_plan.md` — **已完成**
- Phase 4-6 计划：`docs/v15/implementation_plan2.md` — **已完成**
- Phase 7 计划：`docs/v15/implementation_plan3.md` — 未开始

## 进度总览

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1: 选择 | ✅ 完成 | 拖拽模式节点选择、selectedNote/selectedNoteIds 同步 |
| Phase 2: 原地编辑 | ✅ 完成 | 双击编辑、Tab/Enter 内联创建、Escape 取消、空标题回退 |
| Phase 3: 布局切换 | ✅ 完成 | 方向映射修复、异步重算、Topic 级持久化、框架式菜单 |
| Phase 4: 关联线 | ✅ 完成 | 关联线模型、存储、Rust/FFI 持久化、贝塞尔渲染、创建流程 |
| Phase 5: 概要 | ✅ 完成 | 概要模型、连续兄弟区间分组、存储、Controller 状态 |
| Phase 6: 标签 | ✅ 完成 | 节点标签绑定、解绑、标签选择器、Controller 状态 |
| Phase 7: Polish | ⚠️ 基本完成 | 导入导出已修复并测试、持久化冒烟/回归测试已完成、快捷键已验证、文档已更新 |

## 下一步

Phase 7 核心任务已完成。剩余后续增强项见 `known_issues.md`。
