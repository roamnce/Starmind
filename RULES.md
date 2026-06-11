# RULES.md

本文件是 Starmind 仓库的**项目铁律**。优先级高于 `CLAUDE.md`、`AGENTS.md` 与所有 agent 默认习惯。冲突时以本文件为准。

> 状态：骨架版。条目逐步填入；空条目不代表无约束，只代表尚未明文化。

---

## 1. 项目铁律（不可违反）

每条铁律的格式：

```
- **<规则名>**：<一句话规则>。
  - 触发场景：<什么时候适用>
  - 违反后果：<会出什么问题 / 历史教训>
  - 验证方式：<怎么自查或在 PR 里验证>
```

### 1.1 领域与术语
- **术语唯一来源**：所有 domain 概念以 `CONTEXT.md` 为准；命名出现冲突时改代码不改文档。
  - 触发场景：命名 class / function / variable / DB 字段 / UI 文案
  - 违反后果：Dart 与 Rust 两侧用语漂移，跨模块沟通成本爆炸
  - 验证方式：PR 自查清单中勾"已对照 CONTEXT.md"

### 1.2 代码生成产物
- **生成文件禁止手改**：`lib/src/rust/`、`rust/src/frb_generated.rs` 一律不允许手动编辑。
  - 触发场景：调整 FFI 接口、新增 Rust API
  - 违反后果：下次 `flutter_rust_bridge_codegen generate` 全部丢失
  - 验证方式：PR diff 不应触及生成文件，除非 commit type 是 `chore(codegen)`

### 1.3 提交与分支
- **Conventional Commit 强制**：每条 commit 必须符合 Angular 规范，见 `CLAUDE.md` "工作流约束 / Conventional Commit"。
- **分支隔离**：禁止在 `main` / `develop` 上直接提交，全部走 `feature/` / `bugfix/` / `release/` / `hotfix/` PR。

### 1.4 长期记忆
- **PROGRESS Commit 关联**：`PROGRESS.md` 任何 entry 缺 `Related Commit Message` 一律不得入库；Hash 可暂缓，commit 落地后必须补齐。
  - 验证方式：`PROGRESS.md` Global TOC 每行 `Commit` 列非空

### 1.5 架构边界
- **依赖单向**：UI → service → repository → FFI/storage，下层不感知上层；新 import 不允许逆流。
- **FFI 类型不外泄**：`lib/src/rust/` 生成类型只能出现在 `Ffi*Repository` 内，禁止泄漏到 domain / service / UI。

### 1.6 注释与文档
- **公开 API 必须 Doxygen 注释**：Dart 用 `///` + dartdoc 字段，Rust 用 `///` + `# Arguments` / `# Errors` / `# Safety`。
- **`unsafe` 块必须 `// SAFETY:` 紧邻说明**。

### 1.7 代码探索与 graphify 同步
- **覆盖范围**：graphify 索引 `lib/` 全部 + `rust/src/` 全部。生成产物（`lib/src/rust/`、`rust/src/frb_generated.rs`）由 graphify skill 内部过滤，不在更新触发范围内。
- **探索先读 graphify**：动手改 `lib/` 或 `rust/src/` 前，先看 `graphify-out/GRAPH_REPORT.md` 与 `graph.html`；纯文本 Grep 是补充，不是起点。
  - 违反后果：错过隐性依赖，改 A 炸 B
- **改完必须更新 graphify**：任何对 `lib/` 或 `rust/src/`（非生成文件）的功能改动落地后、合并 PR 前，跑 `/graphify` 重建 `graphify-out/`。
  - 触发场景：新增/删除文件、修改 import 或 `use`、抽取/合并类型或函数、跨 FFI 增减 API
  - 违反后果：`manifest.json` 与现实漂移，下一位 agent 在过期图上行军
  - 验证方式：PR 提交前确认 `graphify-out/manifest.json` 包含本次新增/重命名的文件，且 `GRAPH_REPORT.md` 顶部范围与日期为最新

### 1.8 UI 组件库
- **forui 优先**：写界面默认用 forui（`forui: ^0.22.3`），先查 <https://forui.dev/docs>。
- **混用要写理由**：同一交互不允许 forui 与 Material/Cupertino 控件并存。若 forui 不覆盖必须回落，在 PR 说明里写清楚是哪条文档查过、为什么不行。
  - 违反后果：视觉/交互漂移，dark mode 与主题适配成本叠加

---

## 2. 例外条款（明文授权才能违反）

例外只能写在本节，不允许在代码注释里临时声明"本次例外"。

### 2.1 已批准的例外
- *（暂无）*

### 2.2 例外申请模板
```
- **<例外名>**（生效日期 YYYY-MM-DD，提案 PR / Issue 链接）
  - 例外的规则：<指向 §1.x>
  - 适用范围：<文件 / 模块 / 时间窗>
  - 原因：<为什么必须破例>
  - 退出条件：<什么时候撤销这条例外>
```

---

## 3. 与 CLAUDE.md / AGENTS.md / CONTEXT.md 的边界

| 文件 | 内容 | 优先级 |
| --- | --- | --- |
| `RULES.md` | 项目级铁律 + 例外 | 最高 |
| `CONTEXT.md` | 领域术语唯一来源 | 术语类问题以此为准 |
| `AGENTS.md` | Agent 工作流约定（issue tracker、文档版本化等） | 工作流类问题以此为准 |
| `CLAUDE.md` | Claude Code 通用指引（架构、命令、模式） | 通用建议；与 RULES.md 冲突时以 RULES.md 为准 |
| `PROGRESS.md` | 长期记忆索引 | 仅做查询；规则在本文件 §1.4 |

边界原则：
- **能写进 RULES 的不写进 CLAUDE。** CLAUDE 写"建议"，RULES 写"必须"。
- **能写进 CONTEXT 的不写进 RULES。** RULES 不重复术语定义，只引用。
- **AGENTS 是流程，RULES 是底线。** AGENTS 描述"怎么做"，RULES 划"绝对不能怎样"。

---

## 4. 修订历史
| 日期 | 变更 | Commit |
| --- | --- | --- |
| 2026-06-10 | 初始骨架 | _待补_ |
