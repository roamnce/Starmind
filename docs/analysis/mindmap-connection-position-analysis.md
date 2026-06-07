# 思维导图连线位置问题分析

## 问题现象

思维导图的连线位置不正确，连线没有正确连接到节点的边缘，导致视觉上连线位置偏移或错位。

---

## 根本原因

经过代码分析，发现问题的核心在于**坐标系定义不一致**：

### 1. 坐标系定义混乱

项目中存在两种不同的坐标定义：

#### 新架构 (TreeLayoutEngine + AnchorCalculator)
- **位置坐标**：
odePositions 存储的是**节点中心坐标**
- 代码位置：lib/src/mindmap/layout/tree_layout_engine.dart
- 锚点计算基于节点中心：

`dart
// anchor_calculator.dart:28-32
final anchorX = isRightward
    ? nodeCenter.dx + nodeSize.width / 2   // 右边缘
    : nodeCenter.dx - nodeSize.width / 2;  // 左边缘
final anchorY = nodeCenter.dy;
`

#### 旧架构 (TreeLayout)
- **位置坐标**：positions 存储的是**节点顶部中心坐标**
- 代码位置：lib/src/mindmap/ui/tree_layout.dart
- 连线计算需要先转换为中心坐标：

`dart
// tree_layout.dart:259-264
// 节点中心 Y = top + height / 2
final parentCenterY = parentPos.dy + parentSize.height / 2;
final childCenterY = childPos.dy + childSize.height / 2;
`

### 2. 关键代码对比

#### TreeLayoutEngine (新架构)

`dart
// tree_layout_engine.dart:134-136
final childCenterX = isRight
    ? origin.dx + childSize.width / 2
    : origin.dx - childSize.width / 2;
nodePositions[child.note.id] = Offset(childCenterX, childCenterY);
`

这里存储的是**节点中心坐标**。

#### TreeLayout (旧架构)

`dart
// tree_layout.dart:200-202
final childY = currentY + (childLayoutHeight - childHeight) / 2;
final childX = isRight
    ? origin.dx + parentSize.width / 2 + horizontalSpacing + childWidth / 2
    : origin.dx - parentSize.width / 2 - horizontalSpacing - childWidth / 2;
`

这里计算的 childY 是**节点顶部 Y 坐标**，不是中心。

### 3. AnchorCalculator 的假设

AnchorCalculator 假设传入的坐标是**节点中心**：

`dart
// anchor_calculator.dart:20-23
static Offset calculateAnchorPoint({
  required Offset nodeCenter,  // 参数名明确表示是节点中心
  required Size nodeSize,
  required Offset targetCenter,
})
`

但如果传入的是**顶部坐标**，计算结果就会偏移半个节点高度。

---

## 问题影响范围

### 1. 新旧架构混用

- MindMapCanvasPainter 同时支持新旧两种输入：
  - layoutResult (新架构，中心坐标)
  - connections (旧架构，顶部坐标)

- 旧架构的 Connection 在转换时存在问题：

`dart
// canvas_painter.dart:90-96
final connData = ConnectionData(
  fromId: conn.fromId,
  toId: conn.toId,
  startPoint: conn.start,
  endPoint: conn.end,
  fromCenter: conn.start,  // ❌ 错误：start 是顶部坐标，不是中心
  toCenter: conn.end,      // ❌ 错误：end 是顶部坐标，不是中心
);
`

### 2. FrameworkLayout 的坐标系统

FrameworkLayout 也使用**顶部中心坐标**：

`dart
// framework_layout.dart:139-141
// 返回节点顶部中心坐标（与 TreeLayout 一致）
final childTopX = currentX + childSize.width / 2;
final childTopY = currentY;
positions[child.note.id] = Offset(childTopX, childTopY);
`

但连线计算时，锚点计算却假设是中心坐标：

`dart
// framework_layout.dart:185
end: Offset(childPos.dx, childPos.dy + childSize.height / 2),
`

这里 childPos.dy 是顶部 Y，加 height/2 得到中心 Y，这部分是正确的。但问题在于：

`dart
// framework_layout.dart:182
final anchorY = parentPos.dy + headerHeight + nodeHeight;
`

这里的计算假设 parentPos.dy 是框架顶部，然后加上 header 和高度得到锚点 Y。这个计算是正确的，但与 AnchorCalculator 的通用逻辑不一致。

---

## 具体错误场景

### 场景 1：使用旧 TreeLayout 连线

当使用 TreeLayout.calculateConnections() 时：

1. positions 存储的是**顶部坐标**
2. 连线计算正确处理了坐标转换：
   `dart
   final parentCenterY = parentPos.dy + parentSize.height / 2;
   `
3. 但如果这些 Connection 被传给 MindMapCanvasPainter 并转换为 ConnectionData，会发生错误：
   `dart
   fromCenter: conn.start,  // start 已经是边缘锚点，不是中心
   `

### 场景 2：TreeLayoutEngine 锚点计算

TreeLayoutEngine 使用 AnchorCalculator：

`dart
// tree_layout_engine.dart:244-250
final (startAnchor, endAnchor) = AnchorCalculator.calculateAnchorPair(
  fromCenter: parentCenter,  // 这里传入的是中心坐标
  fromSize: parentSize,
  toCenter: childCenter,
  toSize: childSize,
);
`

这部分是正确的，因为 
odePositions 存储的就是中心坐标。

### 场景 3：嵌套卡片布局

TreeLayout 对嵌套卡片有特殊处理：

`dart
// tree_layout.dart:225-235
void _layoutNestedCardChildren(...) {
  final childY = currentY + childHeight / 2;  // 计算中心 Y
  _layoutSubtreeSingle(child, Offset(childX, childY), positions, isRight);
}
`

但 _layoutSubtreeSingle 内部又会对位置进行处理：

`dart
// tree_layout.dart:209
positions[node.note.id] = position;
`

这导致坐标系统的混淆。

---

## 修复建议

### 方案 1：统一坐标系统 (推荐)

**统一使用节点中心坐标**：

1. 修改 TreeLayout 让 positions 存储节点中心坐标
2. 修改 FrameworkLayout 同样使用中心坐标
3. 所有连线计算基于中心坐标

**优点**：
- 坐标语义清晰
- 与 AnchorCalculator 一致
- 便于扩展和维护

**缺点**：
- 需要修改较多代码
- 可能影响其他依赖这些坐标的代码

### 方案 2：为 Connection 添加坐标类型标记

在 ConnectionData 和 Connection 中添加字段说明坐标类型：

`dart
enum PositionType {
  center,  // 节点中心
  topLeft, // 左上角
  topCenter, // 顶部中心
}

class ConnectionData {
  final PositionType positionType;
  // ...
}
`

**优点**：
- 不需要大规模重构
- 明确坐标语义

**缺点**：
- 增加复杂度
- 容易遗漏转换

### 方案 3：添加坐标转换工具

创建统一的坐标转换工具类：

`dart
class NodeCoordinate {
  /// 顶部中心转为中心
  static Offset topCenterToCenter(Offset topCenter, Size size) {
    return Offset(topCenter.dx, topCenter.dy + size.height / 2);
  }
  
  /// 中心转为顶部中心
  static Offset centerToTopCenter(Offset center, Size size) {
    return Offset(center.dx, center.dy - size.height / 2);
  }
  
  /// 计算边缘锚点
  static Offset calculateEdgeAnchor(
    Offset position,
    Size size,
    PositionType positionType,
    Offset targetPosition,
  ) {
    // 根据 positionType 进行相应转换后计算锚点
  }
}
`

---

## 建议实施步骤

### 第一阶段：问题修复 (紧急)

1. **修复 MindMapCanvasPainter 的坐标转换**：
   `dart
   // canvas_painter.dart
   final connData = ConnectionData(
     fromId: conn.fromId,
     toId: conn.toId,
     startPoint: conn.start,
     endPoint: conn.end,
     fromCenter: Offset(conn.start.dx, conn.start.dy), // 需要从 positions 和 sizes 计算
     toCenter: Offset(conn.end.dx, conn.end.dy),
   );
   `

   需要传入 
odePositions 和 
odeSizes 才能正确计算中心坐标。

2. **或者让旧架构继续使用旧渲染逻辑**：
   - 新架构使用 ConnectionData + AnchorCalculator
   - 旧架构直接使用 Connection 的 start/end 作为锚点

### 第二阶段：架构统一 (长期)

1. 逐步迁移到 TreeLayoutEngine 新架构
2. 弃用旧的 TreeLayout 类
3. 统一所有布局引擎使用中心坐标

### 第三阶段：文档和测试

1. 在代码注释中明确坐标系统定义
2. 添加单元测试验证连线锚点计算
3. 添加可视化调试工具显示节点边界和锚点

---

## 附录：关键文件列表

| 文件 | 坐标系统 | 说明 |
|------|---------|------|
| layout/tree_layout_engine.dart | 中心坐标 | 新架构，使用 AnchorCalculator |
| layout/anchor_calculator.dart | 中心坐标 | 假设传入中心坐标 |
| ui/tree_layout.dart | 顶部中心坐标 | 旧架构，已标记 DEPRECATED |
| ui/framework_layout.dart | 顶部中心坐标 | MarginNote 风格框架布局 |
| endering/bezier_renderer.dart | 不关心 | 直接使用 startPoint/endPoint |
| ui/canvas_painter.dart | 混合 | 同时支持新旧两种输入 |

---

## 总结

问题的核心是**新旧架构使用了不同的坐标系统**：

- **新架构**：节点位置 = 节点中心坐标
- **旧架构**：节点位置 = 节点顶部中心坐标

当两种架构混用时，坐标转换不正确导致连线位置偏移。

**最彻底的解决方案**是统一使用节点中心坐标系统，但这需要对旧架构进行重构。短期内可以先修复 MindMapCanvasPainter 中的坐标转换逻辑。
`
┌─────────────────────────────────────────────────────────────┐
│                    坐标系统对比图                            │
└─────────────────────────────────────────────────────────────┘

                    新架构 (TreeLayoutEngine)
                    ────────────────────────────
                    
         (centerX, centerY) ← 节点中心坐标
              ┌─────────────────┐
              │                 │
              │     节点        │ 
              │                 │
              └─────────────────┘
         ●───────────────────────● 锚点在边缘中心
    (centerX - w/2, centerY)   (centerX + w/2, centerY)


                    旧架构 (TreeLayout)
                    ────────────────────────
                    
              ┌─────────────────┐
              │                 │
         (topX, topY) ───→ 节点 │  ← topY 是顶部中心 Y
              │                 │
              └─────────────────┘
         ●───────────────────────● 锚点需要 + height/2 计算
`


---

## 2026-06-07 追踪补充：右侧连线仍未贴边

### 用户反馈

左侧思维导图连线已经视觉上连上，但右侧连线仍然没有连到节点边缘。

### 新证据

本次重新检查后，当前主路径已经不是旧文档中描述的“顶部中心坐标 vs 节点中心坐标”单一问题：

- `lib/src/mindmap/ui/tree_layout.dart` 现在明确声明并实现为中心坐标，`calculateConnections()` 也按中心坐标计算左右边缘锚点。
- `lib/src/mindmap/layout/tree_layout_engine.dart` 的 `nodePositions` 也是中心坐标，并通过 `AnchorCalculator` 计算左右边缘锚点。
- `lib/src/mindmap/ui/mindmap_page.dart` 的 `_offsetLayoutResult()` 会同时偏移 `nodePositions`、`startPoint`、`endPoint`、`fromCenter`、`toCenter`，因此新布局的 `+500` Stack 偏移不是右侧单独断开的直接原因。
- 但 `lib/src/mindmap/ui/node_widget.dart` 的普通节点渲染没有使用 `customSize` 的 `width/height` 固定实际尺寸；普通节点是 `AnimatedContainer + Row(mainAxisSize: MainAxisSize.min)`，真实视觉宽度随文本、图标、子节点计数和 padding 变化。

### 更可能的根因

右侧未贴边的根因更可能是：**布局引擎用于计算锚点的逻辑尺寸，与普通节点实际渲染出来的视觉尺寸不一致**。

当前布局/连线计算默认普通节点大小为 `120x40`：

- `MindMapController.recalculateLayout()` 创建 `LayoutConfig(nodeWidth: 120.0, nodeHeight: 40.0)`。
- `TreeLayoutEngine._calculateNodeSizes()` 和旧 `TreeLayout` 对普通节点也以固定尺寸计算。
- `MindMapPage` 用 `nodeSizes[noteId]` 计算 `Positioned(left/top)`，但普通 `NodeWidget` 本身没有被包进固定 `SizedBox`，实际宽度可能小于或大于 120。

当实际节点宽度小于逻辑宽度时：

- 右侧子节点的终点按 `childCenter.dx - 60` 计算，会落在真实左边缘更左侧，视觉上出现“线差一点才碰到节点”的空隙。
- 左侧子节点的终点按 `childCenter.dx + 60` 计算，也理论上可能有同类空隙；如果左侧节点标题更长、宽度接近或超过 120，或线段被节点覆盖得更明显，就会表现为“左侧连上了，右侧没连上”。

因此，“左侧已连、右侧未连”不应被解释成右侧贝塞尔控制点公式单独错误，而应优先检查 **左右两侧样本节点的真实 Rect 与逻辑 Rect 是否一致**。

### 为什么上次没有发现并修复右侧问题

1. **只验证了坐标语义，没有验证视觉边界**：上次把注意力集中在 `top-center` 与 `center` 的转换上，确认左侧修复后就过早认为连线问题已经闭环。
2. **没有做左右对称用例**：缺少同时包含左侧短标题节点、左侧长标题节点、右侧短标题节点、右侧长标题节点的测试或截图标注，导致右侧差异没有暴露。
3. **把 `nodeSizes` 当作真实 Widget 尺寸**：没有追到 `NodeWidget` 普通节点实际没有消费 `customSize` 固定宽高，导致逻辑锚点和真实视觉边界仍可能错位。
4. **被 `.bak` 与历史注释干扰**：旧备份文件仍在强调“顶部中心坐标”，容易让分析停留在历史 bug，而忽略当前代码已经变化后的新根因。

### 后续修复建议

优先级从高到低：

1. **统一视觉尺寸与逻辑尺寸**：普通 `NodeWidget` 外层使用布局给定的 `customSize` 固定宽高，或至少约束最小/最大宽度，保证布局计算的 Rect 等于绘制 Rect。
2. **改为测量驱动布局**：用真实文本与样式估算/测量节点尺寸，再把真实尺寸传给布局引擎和锚点计算。
3. **增加左右对称回归用例**：同一棵树中同时验证左右短标题、长标题、带图标、带子节点计数的锚点都落在真实节点边界。
4. **增加调试覆盖层**：临时绘制逻辑 Rect、真实 Rect、start/end 锚点，截图确认左右两侧是否一致。

### 关联特殊问题档案

见 `docs/analysis/mindmap-right-connection-gap-special-case.md`。
