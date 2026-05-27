# Domain docs

## 布局

Single-context。项目只有一个全局领域上下文。

- **术语表**：根目录 `CONTEXT.md`
- **架构决策记录**：`docs/adr/`（待创建）

## 读取规则

1. 技能开始工作前，先读 `CONTEXT.md` 了解领域术语。
2. 如果 `docs/adr/` 存在，读相关 ADR 了解过去的架构决策。
3. 术语使用必须与 `CONTEXT.md` 一致——如果用户用了与术语表冲突的词，立即指出。
4. `CONTEXT.md` 只记领域术语和规则，不放实现细节。