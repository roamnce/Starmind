# 特殊问题：思维导图右侧连线未贴边

## 背景

2026-06-07 用户反馈：思维导图左侧连线视觉上已经连到节点，但右侧连线仍然没有连上。

此前分析主要聚焦在“旧布局顶部中心坐标”与“新布局中心坐标”的差异，并推动了坐标语义统一。但用户反馈说明问题没有完全闭环：右侧仍存在视觉空隙。

## 关键代码路径

- `lib/src/mindmap/ui/mindmap_page.dart`：计算 `positions`、`connections`，并把节点放在 `Positioned(left: pos.dx - size.width / 2 + 500, top: pos.dy - size.height / 2 + 500)`。
- `lib/src/mindmap/layout/tree_layout_engine.dart`：新布局引擎，使用固定 `LayoutConfig(nodeWidth: 120, nodeHeight: 40)` 计算普通节点尺寸和锚点。
- `lib/src/mindmap/ui/tree_layout.dart`：旧兼容布局，目前也已声明普通节点位置为中心坐标。
- `lib/src/mindmap/ui/node_widget.dart`：普通节点实际渲染为 `AnimatedContainer + Row(mainAxisSize: MainAxisSize.min)`，未用 `customSize` 固定外层宽高。

## 特殊性

这个问题不是单纯的“右侧公式写反”或“贝塞尔控制点方向错误”。当前证据更指向一个特殊但容易复发的 UI 布局问题：

> 连线锚点基于逻辑 Rect 计算，但节点 Widget 的真实视觉 Rect 由内容自适应决定。

因此同一套锚点公式在不同标题长度、图标数量、子节点计数、选中边框宽度下，会表现为有的节点贴边、有的节点留缝。左侧和右侧的视觉差异可能来自样本内容宽度不同，而不是方向公式本身不同。

## 当前最可能原因

布局认为普通节点宽度是 `120`，所以右侧子节点左边缘锚点为：

```text
endX = childCenterX - 120 / 2
```

但普通 `NodeWidget` 没有固定为 `120` 宽。如果真实节点宽度只有 `80`，真实左边缘应为：

```text
actualLeft = childCenterX - 80 / 2
```

此时 `endX` 会比真实左边缘更靠左 `20px`，视觉上就是右侧连线没碰到节点。

## 为什么上次没有发现

1. 只追踪了坐标类型，没有追踪真实渲染边界。
2. 只验证了“位置是中心坐标”这个数学条件，没有验证“中心坐标 + 尺寸”是否等于屏幕上的节点边界。
3. 没有把左右短标题/长标题节点放在同一个回归样本里比较。
4. 没有检查普通 `NodeWidget` 是否实际消费 `customSize`。
5. 看到左侧视觉正常后过早停止，没有要求右侧独立验收截图或调试覆盖层证据。

## 复查清单

修复或分析类似问题时必须同时检查：

- 逻辑节点 Rect：`Rect.fromCenter(center: pos, width: nodeSizes[id].width, height: nodeSizes[id].height)`。
- 真实 Widget Rect：普通节点是否被固定到 `customSize`；如果没有，内容自适应宽度是多少。
- 左右方向样本：至少包含左短、左长、右短、右长四类节点。
- 锚点可视化：绘制 start/end 小圆点，确认点是否落在真实边界上。
- 渲染层级：确认连线层在节点层下方时，进入节点内部的线段可能被遮盖，不能用“看起来贴边”替代坐标验证。

## 推荐修复方向

首选修复是让普通节点视觉尺寸消费布局尺寸：

- 在普通 `NodeWidget` 外层使用 `SizedBox(width: customSize.width, height: customSize.height)` 或等价约束。
- 文本区域使用 `Expanded/Flexible`，避免内容突破约束。
- 如果产品需要内容自适应宽度，则反过来让布局引擎使用真实测量尺寸，而不是固定 `120x40`。

## 验收标准

- 右侧短标题节点连线终点贴到真实左边缘。
- 右侧长标题节点连线终点贴到真实左边缘。
- 左侧短标题节点连线终点贴到真实右边缘。
- 左侧长标题节点连线终点贴到真实右边缘。
- 放大、缩小、平移后锚点与节点边界仍保持一致。
