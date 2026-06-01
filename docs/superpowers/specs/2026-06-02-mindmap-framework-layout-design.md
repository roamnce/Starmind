# 思维导图框架式布局优化设计

## 概述

优化思维导图的布局算法和连线渲染，新增 MarginNote 风格的框架式布局模式，支持节点级控制、框架嵌套树形布局，以及后期可拖动调整子节点位置。

## 目标

1. **修复连线问题** - 解决当前连线锚点计算错误，确保连线正确连接到节点边缘
2. **优化布局算法** - 引入更紧凑的布局算法，减少空白区域
3. **新增框架式布局** - 支持 MarginNote 风格的框架容器布局，可嵌套树形布局
4. **支持拖动调整** - 框架内子节点可拖动调整位置，实现手动排列

## 核心概念

### 框架式布局定义

框架式布局是一种节点容器布局模式：
- 节点本身是一个带边框的容器
- 子节点在容器内自动紧凑排列（网格布局）
- 子节点如果也是框架式，则递归嵌套
- 连线在框架内部，从父节点边缘连到子节点边缘

### 嵌套结构示例

```
┌─────────────────────────────────────────┐
│  [A] 根节点（框架式）                     │
│  ┌─────────────────────────────────────┐│
│  │ 悬挂标题栏                           ││
│  ├─────────────────────────────────────┤│
│  │ ┌──────────┐ ┌──────────┐           ││
│  │ │ [B]      │ │ [C]      │           ││
│  │ │ ┌───┬───┐│ │ ┌───┬───┐│           ││
│  │ │ │B1 │B2 ││ │ │C1 │C2 ││           ││
│  │ │ └───┴───┘│ │ └───┴───┘│           ││
│  │ └──────────┘ └──────────┘           ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### 排列规则（自动判断）

- 子节点数量 ≤ 2：水平排列（一行）
- 子节点数量 > 2：网格排列，优先填充行
  - 例如 3 个子节点：第一排 2 个，第二排 1 个
  - 例如 4 个子节点：第一排 2 个，第二排 2 个

用户可拖动调整位置，打破自动排列规则。

## 技术设计

### 1. 数据模型扩展

#### Note 模型新增字段

```dart
class Note {
  // ... existing fields ...

  /// 布局样式：normal（普通节点）或 framework（框架容器）
  String layoutStyle; // 'normal' | 'framework'

  /// 框架内子节点自定义位置（仅 framework 模式有效）
  /// key: 子节点 id, value: 位置索引 (row, col)
  Map<String, FrameworkChildPosition>? childPositions;
}

class FrameworkChildPosition {
  int row;
  int col;
}
```

#### TreeLayout 扩展

```dart
/// 布局样式枚举
enum NodeLayoutStyle {
  normal,      // 普通节点
  framework,   // 框架容器
}

/// 框架式布局方向（内部排列）
enum FrameworkArrangement {
  horizontal,  // 水平排列
  vertical,    // 垂直排列
  grid,        // 网格排列（自动判断）
}
```

### 2. 布局算法设计

#### FrameworkLayout 类

新增 `FrameworkLayout` 类，专门处理框架式布局：

```dart
class FrameworkLayout {
  /// 框架容器 padding
  final double containerPadding; // 16px

  /// 框架内节点间距
  final double nodeSpacing; // 12px

  /// 悬挂标题栏高度
  final double headerHeight; // 32px

  /// 计算框架式节点的布局
  Map<String, Offset> calculate(NoteTreeNode node);

  /// 计算框架尺寸（包含所有子节点）
  Size calculateFrameworkSize(NoteTreeNode node);

  /// 自动计算网格排列
  List<List<NoteTreeNode>> arrangeGrid(List<NoteTreeNode> children);

  /// 应用用户自定义位置
  List<List<NoteTreeNode>> applyCustomPositions(
    List<NoteTreeNode> children,
    Map<String, FrameworkChildPosition>? customPositions,
  );
}
```

#### 网格排列算法

```dart
List<List<NoteTreeNode>> arrangeGrid(List<NoteTreeNode> children) {
  final count = children.length;
  if (count <= 2) {
    // 水平排列：一行
    return [children];
  }

  // 网格排列：每行最多 2 个
  final rows = <List<NoteTreeNode>>[];
  for (int i = 0; i < count; i += 2) {
    final row = children.sublist(i, min(i + 2, count));
    rows.add(row);
  }
  return rows;
}
```

#### 框架尺寸计算

```dart
Size calculateFrameworkSize(NoteTreeNode node) {
  if (node.children.isEmpty || node.note.isCollapsed) {
    // 无子节点：最小框架尺寸
    return Size(nodeWidth + containerPadding * 2,
                headerHeight + nodeHeight + containerPadding);
  }

  // 获取排列后的子节点网格
  final grid = arrangeGrid(node.children);

  // 计算最大行宽和总行高
  double maxRowWidth = 0;
  double totalHeight = 0;

  for (final row in grid) {
    final rowWidth = row.fold(0.0, (sum, child) =>
      sum + (nodeSizes[child.note.id]?.width ?? nodeWidth)) +
      (row.length - 1) * nodeSpacing;
    maxRowWidth = max(maxRowWidth, rowWidth);

    final rowHeight = row.fold(0.0, (sum, child) =>
      max(sum, nodeSizes[child.note.id]?.height ?? nodeHeight));
    totalHeight += rowHeight + nodeSpacing;
  }
  totalHeight -= nodeSpacing; // 移除最后一行的多余间距

  return Size(
    maxRowWidth + containerPadding * 2,
    headerHeight + nodeHeight + totalHeight + containerPadding,
  );
}
```

### 3. 连线修复设计

#### 锚点计算修复

当前问题：连线锚点使用 `parentSize.height / 2` 作为 Y 偏移，但这假设节点是矩形且锚点在中心。实际上需要：

1. 正确计算节点边缘位置
2. 框架式节点连线从容器内部边缘出发
3. 普通节点连线从节点边缘中心出发

修复方案：

```dart
Offset calculateAnchorPoint(
  Offset nodeCenter,
  Size nodeSize,
  bool isFramework,
  AnchorPosition anchorPos, // left, right, top, bottom
) {
  if (isFramework) {
    // 框架式节点：锚点在容器内部边缘
    final innerTop = nodeCenter.dy - nodeSize.height / 2 + headerHeight;
    switch (anchorPos) {
      case AnchorPosition.left:
        return Offset(nodeCenter.dx - nodeSize.width / 2 + containerPadding,
                      innerTop + nodeHeight / 2);
      case AnchorPosition.right:
        return Offset(nodeCenter.dx + nodeSize.width / 2 - containerPadding,
                      innerTop + nodeHeight / 2);
      // ...
    }
  } else {
    // 普通节点：锚点在节点边缘中心
    switch (anchorPos) {
      case AnchorPosition.left:
        return Offset(nodeCenter.dx - nodeSize.width / 2,
                      nodeCenter.dy + nodeSize.height / 2);
      case AnchorPosition.right:
        return Offset(nodeCenter.dx + nodeSize.width / 2,
                      nodeCenter.dy + nodeSize.height / 2);
      // ...
    }
  }
}
```

#### 贝塞尔曲线改进

借鉴 wanglin-mindmap 的三次贝塞尔曲线实现：

```dart
Path _createCubicBezierPath(Connection conn, bool isHorizontal) {
  final path = Path();
  path.moveTo(conn.start.dx, conn.start.dy);

  if (isHorizontal) {
    // 水平方向：控制点在水平线上
    final midX = (conn.start.dx + conn.end.dx) / 2;
    path.cubicTo(midX, conn.start.dy, midX, conn.end.dy, conn.end.dx, conn.end.dy);
  } else {
    // 垂直方向：控制点在垂直线上
    final midY = (conn.start.dy + conn.end.dy) / 2;
    path.cubicTo(conn.start.dx, midY, conn.end.dx, midY, conn.end.dx, conn.end.dy);
  }

  return path;
}
```

### 4. 拖动调整设计

#### 拖动交互流程

1. 用户长按/拖动框架内的子节点
2. 节点高亮显示可放置位置（网格槽位）
3. 用户释放节点，节点移动到新位置
4. 更新 `childPositions` 字段，持久化位置信息
5. 重新计算布局和连线

#### 槽位计算

```dart
class FrameworkSlot {
  int row;
  int col;
  Rect dropZone; // 可放置区域
}

List<FrameworkSlot> calculateDropSlots(NoteTreeNode frameworkNode) {
  final grid = arrangeGrid(frameworkNode.children);
  final slots = <FrameworkSlot>[];

  for (int r = 0; r < grid.length; r++) {
    for (int c = 0; c < maxRowColumns; c++) {
      // 计算每个槽位的 dropZone
      final slotRect = Rect.fromLTWH(
        xOffset + c * (nodeWidth + nodeSpacing),
        yOffset + r * (nodeHeight + nodeSpacing),
        nodeWidth,
        nodeHeight,
      );
      slots.add(FrameworkSlot(row: r, col: c, dropZone: slotRect));
    }
  }

  // 动态增加一行（用于添加新位置）
  slots.addAll(calculateExtraRowSlots(grid.length));

  return slots;
}
```

### 5. 渲染设计

#### NodeWidget 扩展

```dart
class NodeWidget extends StatelessWidget {
  final Note note;
  final NodeLayoutStyle layoutStyle;
  final Size? customSize;
  final List<Widget>? childrenWidgets; // 框架内子节点

  @override
  Widget build(BuildContext context) {
    if (layoutStyle == NodeLayoutStyle.framework) {
      return _buildFrameworkNode();
    } else {
      return _buildNormalNode();
    }
  }

  Widget _buildFrameworkNode() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 悬挂标题栏
          _buildHeader(),
          // 子节点网格
          Expanded(child: _buildChildrenGrid()),
        ],
      ),
    );
  }
}
```

## 实现计划

### Phase 1: 连线修复（优先级最高）

1. 分析当前连线锚点计算问题
2. 修复 `calculateConnections` 方法
3. 验证连线正确连接到节点边缘
4. 单元测试覆盖

### Phase 2: 框架式布局基础

1. 扩展 Note 模型，新增 `layoutStyle` 字段
2. 实现 `FrameworkLayout` 类
3. 实现网格排列算法
4. 实现框架尺寸计算
5. 修改 `TreeLayout` 支持框架式布局

### Phase 3: 渲染适配

1. 扩展 `NodeWidget` 支持框架式样式
2. 修改 `MindMapPage` 渲染逻辑
3. 适配 `CanvasPainter` 连线绘制
4. 视觉效果调优

### Phase 4: 拖动调整

1. 实现框架内节点拖动交互
2. 计算可放置槽位
3. 更新 `childPositions` 字段
4. 持久化位置信息

### Phase 5: 布局算法优化

1. 引入 non-layered-tidy 算法改进普通布局
2. 优化两侧布局的智能分配
3. 减少空白区域

## 测试策略

### 单元测试

- 框架式布局计算测试
- 网格排列算法测试
- 连线锚点计算测试
- 拖动位置更新测试

### 集成测试

- 框架嵌套树形布局渲染测试
- 拖动交互流程测试
- 布局切换测试

### 视觉验证

- 对比原型 `card_layout_dark.html` 效果
- 不同节点数量的排列效果
- 深层嵌套的渲染效果

## 风险与考量

### 向后兼容

- 现有布局不受影响，`layoutStyle` 默认为 `normal`
- 可通过配置切换布局模式

### 性能考虑

- 框架式布局计算复杂度较高
- 需要缓存布局结果，避免重复计算
- 深层嵌套可能导致渲染性能下降，需设置最大嵌套深度

### 用户体验

- 框架式布局与普通布局的切换需要平滑过渡
- 拖动调整需要明确的视觉反馈
- 需要提供"重置为自动排列"功能

## 参考代码

- `D:/package/hierarchy/src/layout/non-layered-tidy.ts` - 紧凑布局算法
- `E:/app/wanglin-mindmap/simple-mind-map/src/layouts/MindMap.js` - 贝塞尔连线实现
- `D:/starmind/prototype/card_layout_dark.html` - MarginNote 风格原型