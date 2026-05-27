---
name: build-strategy
description: Flutter/Rust 构建策略 - 使用云端 CI 构建，不在本地执行构建命令
metadata:
  type: feedback
---

## 构建策略规则

**规则**: 不在本地执行 `flutter build` 命令

**Why**: 
- 本地 Windows 环境缺少完整的 Visual Studio 工具链
- 用户已配置云端 CI 进行构建
- 本地构建耗时且可能因环境问题失败

**How to apply**:
- 只执行 Rust 编译 (`cargo build`)
- 只执行 Flutter pub 操作 (`flutter pub get`)
- 只执行代码生成 (`flutter_rust_bridge_codegen`)
- **不执行** `flutter build windows/android`
- 构建验证留给用户自行测试或云端 CI