# 阶段1：布局引擎重构设计文档

> 版本：1.0
> 日期：2026-06-03
> 状态：设计中

---

## 1. 目标与范围

### 1.1 核心目标

重构现有的 `TreeLayout` 布局引擎，解决连线锚点偏移问题，并引入成熟的连线算法，为后续的手写层和 GuruMind 导入奠定坚实基础。

### 1.2 具体问题

当前实现存在以下问题：

1. **连线锚点偏移**：贝塞尔曲线起点/终点未正确连接到节点边缘
2. **布局算法脆弱**：两侧布局时节点位置计算不够健壮
3. **扩展性不足**：难以支持多种连线样式和自定义布局

### 1.3 成功标准

- ✅ 连线正确连接到节点边缘中心
- ✅ 支持贝塞尔、直线、正交三种连线样式
- ✅ 两侧布局时节点分布均匀对称
- ✅ 单元测试覆盖率 > 80%
- ✅ 性能：1000 节点布局计算 < 100ms

---

## 2. 参考项目分析

### 2.1 flutter_mind_map 连线算法

**核心设计模式**：

```dart
// ILink 接口 - 策略模式
abstract class ILink {
  String getName();
  CustomPainter getPainter(IMindMapNode node);
}
```

**贝塞尔连线实现** (`beerse_line_link.dart`)：

```dart
// 关键：使用 cubicTo 绘制平滑贝塞尔曲线
path.cubicTo(
  itemOffset.dx + itemSize.width + (node.getHSpace() + p) / 2,  // 控制点1 X
  itemOffset.dy + itemSize.height / 2 + item.getLinkInOffset(),  // 控制点1 Y
  offset.dx + p - (node.getHSpace() + p) / 2,                    // 控制点2 X
  offset.dy + s.height / 2 + node.getLinkOutOffset(),           // 控制点2 Y
  offset.dx + p,                                                  // 终点 X
  offset.dy + s.height / 2 + node.getLinkOutOffset(),           // 终点 Y
);
```

**优点**：
- 策略模式支持多种连线样式
- 控制点基于节点间距动态计算
- 支持左右两侧独立渲染

**缺点**：
- 节点位置由 Widget 布局决定，Painter 只负责绘制
- 没有独立的布局计算层

### 2.2 flutter_graph_view 图布局

**核心设计**：

```dart
class Vertex<I> {
  Vector2 position;       // 节点位置
  double radius;          // 节点半径
  Set<Vertex<I>> nextVertexes;   // 下游节点
  Set<Vertex<I>> prevVertexes;   // 上游节点
  int deep;               // 深度层级
}
```

**力导向算法** (`force_directed.dart`)：

```dart
// 子节点围绕父节点分布
if (v.prevVertex != null && !v.isHovered) {
  if (Util.distance(v.position, v.prevVertex!.position) < 5 * v.prevVertex!.radius) {
    v.position += (v.position - v.prevVertex!.position) / 100;
  } else if (Util.distance(v.position, v.prevVertex!.position) > 20 * v.prevVertex!.radius) {
    v.position -= (v.position - v.prevVertex!.position) / 100;
  }
}
```

**优点**：
- 通用图布局框架
- 支持力导向、圆形等多种算法
- 节点位置与渲染分离

**缺点**：
- 过于通用，不适合严格的树形布局
- 力导向算法不稳定，节点位置会变化

### 2.3 wanglin-mindmap (simple-mind-map)

**技术栈**：JavaScript + Canvas

**核心特点**：
- 基于 JSON 的节点数据结构
- 内置多种主题
- 导出为图片功能

**可借鉴点**：
- 连线路径算法
- 节点样式系统

---

## 3. 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    MindMapPage (UI Layer)                   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  MindMapCanvas   │  │   NodeWidgets    │                │
│  │  (CustomPainter) │  │   (Widgets)      │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                     │                           │
│           └──────────┬──────────┘                           │
│                      ▼                                      │
│           ┌─────────────────────┐                           │
│           │   LayoutEngine      │  ← 新增核心组件           │
│           │   (布局计算引擎)    │                           │
│           └─────────┬───────────┘                           │
│                     │                                       │
├─────────────────────┼───────────────────────────────────────┤
│  ┌──────────────────▼──────────────────┐                    │
│  │         ConnectionRenderer           │  ← 新增连线渲染器  │
│  │  ┌─────────┬─────────┬─────────┐    │                    │
│  │  │Bezier   │Straight │Ortho    │    │                    │
│  │  │Renderer │Renderer │Renderer │    │                    │
│  │  └─────────┴─────────┴─────────┘    │                    │
│  └──────────────────────────────────────┘                    │
├─────────────────────────────────────────────────────────────┤
│                   MindMapController                         │
│                   (状态管理)                                 │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 核心组件

#### 3.2.1 LayoutEngine（布局引擎）

**职责**：
- 计算节点位置坐标
- 支持多种布局策略（两侧、右侧、左侧、鱼骨图）
- 计算连线锚点

**接口设计**：

```dart
/// 布局策略
enum LayoutStrategy {
  bothSides,   // 两侧布局
  rightOnly,   // 右侧布局
  leftOnly,    // 左侧布局
  fishbone,    // 鱼骨图
}

/// 布局结果
class LayoutResult {
  /// 节点 ID -> 中心坐标
  final Map<String, Offset> nodePositions;

  /// 节点 ID -> 尺寸
  final Map<String, Size> nodeSizes;

  /// 连线列表
  final List<ConnectionData> connections;

  /// 内容边界框
  final Rect contentBounds;
}

/// 连线数据
class ConnectionData {
  final String fromId;
  final String toId;
  final Offset startPoint;   // 起点（锚点）
  final Offset endPoint;     // 终点（锚点）
  final Offset fromCenter;   // 父节点中心
  final Offset toCenter;     // 子节点中心
}

/// 布局引擎
abstract class LayoutEngine {
  /// 计算布局
  LayoutResult layout(NoteTreeNode root, LayoutConfig config);
}

/// 布局配置
class LayoutConfig {
  final LayoutStrategy strategy;
  final double nodeWidth;
  final double nodeHeight;
  final double horizontalSpacing;
  final double verticalSpacing;
  final Map<String, Size>? customNodeSizes;  // 自定义节点尺寸
}
```

#### 3.2.2 ConnectionRenderer（连线渲染器）

**职责**：
- 根据连线数据绘制路径
- 支持多种连线样式
- 支持自定义颜色、粗细

**接口设计**：

```dart
/// 连线样式
enum ConnectionStyle {
  bezier,    // 贝塞尔曲线
  straight,  // 直线
  ortho,     // 正交线
  curve,     // 弧线
}

/// 连线渲染器接口
abstract class ConnectionRenderer {
  /// 渲染连线
  void render(Canvas canvas, ConnectionData conn, ConnectionPaintConfig config);

  /// 创建路径（用于测试和调试）
  Path createPath(ConnectionData conn);
}

/// 连线绘制配置
class ConnectionPaintConfig {
  final Color color;
  final double width;
  final bool isRainbow;  // 彩虹色
  final List<Color>? gradientColors;
}
```

#### 3.2.3 具体渲染器实现

**BezierConnectionRenderer**（贝塞尔连线）：

```dart
class BezierConnectionRenderer implements ConnectionRenderer {
  @override
  Path createPath(ConnectionData conn) {
    final path = Path();

    // 计算控制点
    final dx = (conn.endPoint.dx - conn.startPoint.dx).abs();
    final controlOffset = dx * 0.5;  // 控制点偏移量

    // 确定连线方向
    final isRightward = conn.endPoint.dx > conn.startPoint.dx;

    path.moveTo(conn.startPoint.dx, conn.startPoint.dy);

    if (isRightward) {
      // 向右连线
      path.cubicTo(
        conn.startPoint.dx + controlOffset, conn.startPoint.dy,
        conn.endPoint.dx - controlOffset, conn.endPoint.dy,
        conn.endPoint.dx, conn.endPoint.dy,
      );
    } else {
      // 向左连线
      path.cubicTo(
        conn.startPoint.dx - controlOffset, conn.startPoint.dy,
        conn.endPoint.dx + controlOffset, conn.endPoint.dy,
        conn.endPoint.dx, conn.endPoint.dy,
      );
    }

    return path;
  }
}
```

**OrthoConnectionRenderer**（正交连线）：

```dart
class OrthoConnectionRenderer implements ConnectionRenderer {
  @override
  Path createPath(ConnectionData conn) {
    final path = Path();
    path.moveTo(conn.startPoint.dx, conn.startPoint.dy);

    // 正交折线：起点 -> 中间折点 -> 终点
    final midX = (conn.startPoint.dx + conn.endPoint.dx) / 2;

    path.lineTo(midX, conn.startPoint.dy);
    path.lineTo(midX, conn.endPoint.dy);
    path.lineTo(conn.endPoint.dx, conn.endPoint.dy);

    return path;
  }
}
```

### 3.3 锚点计算算法

**核心问题**：连线锚点必须精确连接到节点边缘中心

**解决方案**：

```dart
/// 计算连线锚点
Offset calculateAnchorPoint({
  required Offset nodeCenter,     // 节点中心坐标
  required Size nodeSize,         // 节点尺寸
  required Offset targetCenter,   // 目标节点中心
}) {
  // 确定连线方向
  final isRightward = targetCenter.dx > nodeCenter.dx;

  // 锚点在节点边缘的水平中心
  final anchorX = isRightward
      ? nodeCenter.dx + nodeSize.width / 2   // 右边缘
      : nodeCenter.dx - nodeSize.width / 2;  // 左边缘

  // 锚点 Y 坐标为节点垂直中心
  final anchorY = nodeCenter.dy;

  return Offset(anchorX, anchorY);
}
```

**关键点**：
1. 节点坐标统一使用**中心点**表示
2. 锚点在节点**边缘的水平中心**，而非节点中心
3. 锚点方向由父子节点的相对位置决定

---

## 4. 重构计划

### 4.1 Phase 1.1：布局引擎核心（3-4天）

**任务**：
1. 创建 `LayoutEngine` 接口和 `LayoutResult` 数据结构
2. 实现 `TreeLayoutEngine`（基于现有 TreeLayout 重构）
3. 添加锚点计算逻辑

**验收标准**：
- 单元测试通过
- 布局结果包含正确的锚点坐标

### 4.2 Phase 1.2：连线渲染器（2-3天）

**任务**：
1. 创建 `ConnectionRenderer` 接口
2. 实现 `BezierConnectionRenderer`
3. 实现 `OrthoConnectionRenderer`
4. 实现 `StraightConnectionRenderer`

**验收标准**：
- 三种连线样式正确渲染
- 连线精确连接到节点边缘

### 4.3 Phase 1.3：集成与优化（2-3天）

**任务**：
1. 重构 `MindMapCanvasPainter` 使用新渲染器
2. 更新 `MindMapController` 集成新布局引擎
3. 性能优化与测试

**验收标准**：
- 现有功能正常
- 性能达标

### 4.4 Phase 1.4：文档与清理（1天）

**任务**：
1. 更新技术文档
2. 清理废弃代码
3. 编写使用示例

---

## 5. 文件结构

```
lib/src/mindmap/
├── layout/
│   ├── layout_engine.dart          # 布局引擎接口
│   ├── layout_result.dart          # 布局结果数据结构
│   ├── layout_config.dart          # 布局配置
│   ├── tree_layout_engine.dart     # 树形布局实现
│   └── anchor_calculator.dart      # 锚点计算器
├── rendering/
│   ├── connection_renderer.dart    # 连线渲染器接口
│   ├── bezier_renderer.dart        # 贝塞尔连线渲染
│   ├── ortho_renderer.dart         # 正交连线渲染
│   └── straight_renderer.dart      # 直线连线渲染
├── ui/
│   ├── mindmap_page.dart           # 主页面（更新）
│   ├── canvas_painter.dart         # 画布绘制器（重构）
│   └── node_widget.dart            # 节点组件（保持）
└── test/
    ├── layout/
    │   ├── tree_layout_engine_test.dart
    │   └── anchor_calculator_test.dart
    └── rendering/
        ├── bezier_renderer_test.dart
        └── ortho_renderer_test.dart
```

---

## 6. 测试策略

### 6.1 单元测试

**布局引擎测试**：
```dart
test('TreeLayoutEngine calculates correct positions', () {
  final engine = TreeLayoutEngine();
  final root = createTestTree();
  final result = engine.layout(root, LayoutConfig.defaultConfig);

  // 根节点在原点
  expect(result.nodePositions[root.note.id], Offset.zero);

  // 子节点在右侧
  for (final child in root.children) {
    expect(result.nodePositions[child.note.id]!.dx, greaterThan(0));
  }
});

test('Anchor points connect to node edges', () {
  final engine = TreeLayoutEngine();
  final result = engine.layout(simpleTree, LayoutConfig.defaultConfig);

  for (final conn in result.connections) {
    // 锚点 X 坐标应该在节点边缘
    final fromSize = result.nodeSizes[conn.fromId]!;
    final fromCenter = result.nodePositions[conn.fromId]!;

    // 锚点应该在右边缘
    expect(
      conn.startPoint.dx,
      equals(fromCenter.dx + fromSize.width / 2),
    );
  }
});
```

**连线渲染器测试**：
```dart
test('BezierRenderer creates smooth curve', () {
  final renderer = BezierConnectionRenderer();
  final conn = ConnectionData(
    startPoint: Offset(0, 0),
    endPoint: Offset(100, 50),
    // ...
  );

  final path = renderer.createPath(conn);

  // 路径起点正确
  expect(path.getBounds().left, equals(0));
  // 路径终点正确
  expect(path.getBounds().right, equals(100));
});
```

### 6.2 视觉回归测试

使用 golden 测试验证连线渲染效果：

```dart
testWidgets('Connection golden test', (tester) async {
  await tester.pumpWidget(TestMindMapApp());

  await expectLater(
    find.byType(MindMapCanvas),
    matchesGoldenFile('goldens/connections/bezier.png'),
  );
});
```

---

## 7. 风险与缓解

### 7.1 风险列表

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 现有功能回归 | 高 | 中 | 完善测试覆盖，分步重构 |
| 性能下降 | 中 | 低 | 性能基准测试，优化算法 |
| 与手写层冲突 | 中 | 低 | 预留扩展接口 |

### 7.2 回滚策略

保留现有 `TreeLayout` 实现，新增 `TreeLayoutEngine`，通过开关切换：

```dart
class MindMapController {
  bool useNewLayoutEngine = true;

  LayoutResult _calculateLayout() {
    if (useNewLayoutEngine) {
      return TreeLayoutEngine().layout(root, config);
    } else {
      // 使用旧实现
      return LegacyTreeLayout().layout(root, config);
    }
  }
}
```

---

## 8. 依赖与资源

### 8.1 外部依赖

无新增外部依赖，使用 Flutter 内置 `dart:ui` 和 `dart:math`

### 8.2 参考资料

- flutter_mind_map: `E:/app/flutter_mind_map/`
- flutter_graph_view: `E:/app/flutter_graph_view/`
- 现有实现: `lib/src/mindmap/ui/tree_layout.dart`

---

## 9. 验收标准

### 9.1 功能验收

- [ ] 连线正确连接到节点边缘
- [ ] 支持贝塞尔、直线、正交三种样式
- [ ] 两侧布局对称分布
- [ ] 折叠/展开时连线正确更新

### 9.2 质量验收

- [ ] 单元测试覆盖率 > 80%
- [ ] 无 lint 警告
- [ ] 代码通过 review

### 9.3 性能验收

- [ ] 1000 节点布局 < 100ms
- [ ] 拖动流畅度 > 60 FPS

---

## 10. 下一步

完成阶段 1 后，进入**阶段 2：手写层实现**。

---

*设计者：Claude Code*
*审核者：待定*
