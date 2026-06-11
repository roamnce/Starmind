# v16 任务说明：MarginNote 式手写思维导图

## 目标

实现手写批注与思维导图的深度融合，构建「阅读 → 摘录 → 结构化」的知识闭环基础。

## 文档入口

- 开发蓝图：`docs/v16/development_blueprint.md`
- Phase 1：`docs/v16/specs/phase-1-canvas-ink-layer.md`
- Phase 2：`docs/v16/specs/phase-2-node-ink-notes.md`
- Phase 3：`docs/v16/specs/phase-3-ink-to-node.md`

## 前置条件

- v15 Phase 4-6 完成（关联线、概要、标签）
- 另一个 AI 正在推进

## 进度总览

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1: 手写画布层 | ✅ 规格完成（2026-06-11 审阅修订） | 工具栏、手势路由、墨迹渲染、接入已有 ink_layers 持久化 |
| Phase 2: 节点手写笔记 | ✅ 规格完成（2026-06-11 审阅修订） | 详情面板、缩略图（带缓存）、独立墨迹层 |
| Phase 3: 手写转节点 | ✅ 规格完成（2026-06-11 审阅修订） | 套索选择、$1 手势识别（阈值 0.9，默认关闭） |

### 2026-06-11 审阅修订要点

- Phase 1-3 全部补 Plan Header（Goal / Architecture / Tech Stack）
- Plan 1-D 锁死单一状态源：`interactMode == ink`，删除 `_isInkMode` 双状态机
- Plan 1-E 不重建 schema：接入已有 `FfiInkLayerRepository` + `ink_layers` 表
- Plan 1-A / 1-B 改成标准 TDD red-green 顺序
- Phase 2 / 3 拆 Step 颗粒度到 2-5 分钟可执行
- Phase 2 缩略图强制 `dart:ui.Image` 缓存（防 50+ 节点掉帧）
- Phase 3 手势识别阈值 0.8 → 0.9（减少自然书写误触）
- 补 `development_blueprint.md`（task.md 顶端链接现已生效）

## v16 范围锁定

v16 仅包含 Phase 1-3，实现手写思维导图的核心基础能力。

Phase 4（PDF 摘录联动）和 Phase 5（复习系统）移至 v17。

## 下一步

等待 v15 Phase 4-6 验收后，开始 v16 Phase 1 实现。