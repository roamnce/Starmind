## Agent skills

### Issue tracker

Issues 使用 local markdown 存储，放在 `.scratch/<feature>/` 目录下。详见 `docs/agents/issue-tracker.md`。

### Triage labels

使用五个标准 triage 状态标签，对应 local markdown issue 的 `status:` 字段。详见 `docs/agents/triage-labels.md`。

### Domain docs

Single-context：根目录 `CONTEXT.md` + `docs/adr/`。详见 `docs/agents/domain.md`。

### Development Documents Versioning (开发文档版本管理规则)

所有的开发迭代应按照 `v1`、`v2`... 的文件夹进行组织，存储在 `docs/` 下（例如 `docs/v1/`, `docs/v2/` 等）。
每次开发的开发计划（例如 `implementation_plan.md`）、交付文档（例如 `walkthrough.md`）以及相关的分析和任务清单等，都必须统一保存到对应开发阶段的文件夹内，以便归档和追溯。