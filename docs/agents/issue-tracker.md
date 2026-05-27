# Issue tracker: Local markdown

Issues 存储为本仓库内的 markdown 文件。

## 目录结构

每个 feature 或工作流在 `.scratch/` 下有自己的子目录：

```
.scratch/
  pdf-crash-on-android/
    001-initial-report.md
    002-repro-steps.md
  feature-mind-map/
    001-spec.md
```

## Issue 文件格式

每个文件包含 YAML front matter 和正文：

```markdown
---
status: needs-triage
priority: normal
assignee: 
created: 2026-05-23
---

# 标题

问题描述...
```

`status` 字段取值见 `triage-labels.md`。

## 创建 Issue

使用 `/triage` 技能或手动在 `.scratch/` 下创建子目录和 markdown 文件。

## 读取 Issue

扫描 `.scratch/*/` 下所有 markdown 文件，读取 front matter 中的 `status`、`priority` 等字段。