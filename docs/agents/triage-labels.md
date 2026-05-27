# Triage labels

本仓库使用五个标准 triage 状态，对应 local markdown issue 的 `status:` 字段。

| 状态 | 含义 |
|------|------|
| `needs-triage` | 需要维护者评估 |
| `needs-info` | 等待上报人补充信息 |
| `ready-for-agent` | 完全明确，AI 可直接处理 |
| `ready-for-human` | 需要人工实现 |
| `wontfix` | 不处理 |

状态流转：`needs-triage` → `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`。