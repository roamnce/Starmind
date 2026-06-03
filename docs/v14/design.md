# Phase 1 设计文档 (v14)

> 版本：1.0
> 日期：2026-06-04

## 概述

阶段 1 实现了布局引擎重构，修复了连线锚点偏移问题，并引入了可扩展的渲染器架构。

## 架构变更

### 新增模块

1. **layout/** - 布局计算引擎
   - `LayoutEngine` - 抽象接口
   - `TreeLayoutEngine` - 树形布局实现
   - `LayoutConfig` - 布局配置
   - `LayoutResult` - 布局结果
   - `AnchorCalculator` - 锚点计算器

2. **rendering/** - 连线渲染器
   - `ConnectionRenderer` - 抽象接口
   - `BezierConnectionRenderer` - 贝塞尔曲线
   - `StraightConnectionRenderer` - 直线
   - `OrthoConnectionRenderer` - 正交折线

### 弃用模块

- `TreeLayout` (tree_layout.dart) - 保留但标记为 deprecated

## 关键改进

1. **锚点计算正确** - 连线精确连接到节点边缘中心
2. **可扩展架构** - 支持添加新的布局策略和连线样式
3. **分离关注点** - 布局计算与渲染分离

## 使用方式

```dart
final engine = TreeLayoutEngine();
final result = engine.layout(rootNode, LayoutConfig.defaultConfig);

final position = result.nodePositions['node-id'];

final renderer = BezierConnectionRenderer();
renderer.render(canvas, connection, paintConfig);
```
