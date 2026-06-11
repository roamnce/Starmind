# PROGRESS Table of Contents

## Purpose
- 把长期可复用的经验、踩坑、决策落点沉到仓库里，作为 toolbook 风格的索引。
- 每条记录单独成文，本文件只做全局查询目录。
- 强制每条 entry 关联一次代码变更（commit），让经验可回溯到具体改动。

## Storage Layout
- TOC 文件：`PROGRESS.md`（仓库根目录，本文件）
- Entry 根目录：`docs/progress/entries/`
- 年份子目录：`docs/progress/entries/YYYY/`
- Entry 文件名：`YYYY-MM-DD-N.md`（`N` 从 `1` 起，按当天顺序递增）
- Page ID：`YYYYMMDD-N`

## Entry Template
1. **Date**：`YYYY-MM-DD`
2. **Title**：简短的祈使句标题
3. **Background / Issue**：触发背景与问题描述
4. **Actions / Outcome**：做了什么、最终结果
5. **Lessons / Refinements**：可复用的经验或预防规则
6. **Related Commit Message**（必填）：完整 Conventional Commit 标题，如 `fix(mindmap): correct right-side anchor offset`
7. **Related Commit Hash**（建议）：完整或短 SHA，如 `2eeb488`

## TOC Rules
- 每新增一个 entry 文件，必须在 Global TOC 追加一行；漏登记的 entry 视为未入库。
- 没有 **Related Commit Message** 的 entry 不允许入库；TOC 也不得登记。
- 仅 **Related Commit Hash** 缺失时允许暂存（commit 尚未推前），但需在 commit 落地后补齐。
- TOC 行按 `Date` 升序排列，同日按 `N` 升序。
- `Path` 列用相对仓库根的路径，统一以 `./` 开头。
- `Keywords` 至少 2 个，用半角逗号分隔，便于检索。

## Global TOC
| Page ID | Date | Title | Path | Commit | Keywords |
| --- | --- | --- | --- | --- | --- |
