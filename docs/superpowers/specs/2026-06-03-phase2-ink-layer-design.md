# 阶段2：手写层实现设计文档

> 版本：1.0
> 日期：2026-06-03
> 状态：设计中

---

## 1. 目标与范围

### 1.1 核心目标

在思维导图画布上实现双层手写功能：
1. **画布级手写层** - 在整个导图画布上自由绘制，与节点解耦
2. **节点级手写层** - 每个节点独立的笔记手写区域

### 1.2 用户需求

用户的核心使用场景：
- 在导图画布上自由批注、绘制想法
- 在节点笔记中放置题目图片，通过手写进行刷题练习
- 跨平台支持桌面键鼠和平板触控/手写笔

### 1.3 成功标准

- ✅ 支持钢笔、荧光笔、橡皮擦、套索选择四种工具
- ✅ 手写笔迹正确存储和渲染
- ✅ 画布缩放/平移时手写层同步变换
- ✅ 支持压感（触控笔）和鼠标绘制
- ✅ 节点笔记支持图片嵌入 + 手写叠加

---

## 2. 参考实现分析

### 2.1 现有 PDF 手写实现

**关键组件**：

| 组件 | 文件 | 职责 |
|------|------|------|
| `InkCanvasLayer` | `lib/src/pdf/widgets/ink_canvas_layer.dart` | 手写画布层 |
| `InkStroke` | `lib/src/domain/ink_stroke.dart` | 笔迹数据模型 |
| `PenConfig` | `lib/src/pdf/pen_config.dart` | 笔配置（钢笔、荧光笔等） |
| `StrokeStabilizer` | `lib/src/pdf/stroke_stabilizer.dart` | 笔迹平滑算法 |
| `GestureDispatcher` | `lib/src/pdf/gesture_dispatcher.dart` | 手势分发器 |

**现有工具类型**：
```dart
enum PenType {
  fountainPen,    // 钢笔（压感）
  ballpointPen,   // 圆珠笔（固定宽度）
  pencil,         // 铅笔（压感+半透明）
  highlighter,    // 荧光笔（半透明固定宽度）
  eraser;         // 橡皮擦
}
```

**可复用程度**：高。核心手写逻辑可直接复用，仅需适配到思维导图画布。

### 2.2 Saber 手写实现

**Stroke 类设计**：
```dart
class Stroke {
  List<PointVector> points;   // 笔迹点
  Color color;
  bool pressureEnabled;
  StrokeOptions options;      // 宽度、平滑度等
  ToolId toolId;              // 工具类型

  // 高质量/低质量渲染路径
  Path get highQualityPath;
  Path get lowQualityPath;
}
```

**手势检测**：
- 区分绘制手势和缩放/平移手势
- 触控笔（stylus）自动进入绘制模式
- 手指触摸默认为缩放/平移

**可借鉴点**：
- `perfect_freehand` 库用于高质量笔迹渲染
- 高质量/低质量双模式渲染（性能优化）
- 触控笔压感处理

### 2.3 关键差异：PDF vs 思维导图

| 特性 | PDF 手写 | 思维导图手写 |
|------|----------|--------------|
| **坐标系** | 固定页面坐标 | 动态画布坐标（需同步变换） |
| **缩放** | 页面固定缩放 | 画布自由缩放/平移 |
| **层级** | 页面级 | 画布级 + 节点级双层 |
| **存储** | Annotation 表 | 新增 InkLayer 表 |

---

## 3. 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MindMapPage (UI Layer)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 MindMapCanvas (Viewport)                     │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │         CanvasInkLayer (画布级手写)                  │    │   │
│  │  │  ┌─────────────────────────────────────────────┐    │    │   │
│  │  │  │           NodeWidgets + Connections         │    │    │   │
│  │  │  │  ┌─────────────────────────────────────┐   │    │    │   │
│  │  │  │  │   NodeInkOverlay (节点级手写)       │   │    │    │   │
│  │  │  │  │   ┌─────────────────────────────┐  │   │    │    │   │
│  │  │  │  │   │   NodeNoteContent           │  │   │    │    │   │
│  │  │  │  │   │   (图片 + 文本 + 手写)      │  │   │    │    │   │
│  │  │  │  │   └─────────────────────────────┘  │   │    │    │   │
│  │  │  │   └─────────────────────────────────────┘   │    │    │   │
│  │  │  └─────────────────────────────────────────────┘    │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                    InkLayerController                               │
│                    (手写状态管理)                                    │
├─────────────────────────────────────────────────────────────────────┤
│                    InkLayerRepository                               │
│                    (手写数据持久化)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 核心组件

#### 3.2.1 InkLayer（手写层数据模型）

```dart
/// 手写层类型
enum InkLayerType {
  canvas,   // 画布级
  node,     // 节点级
}

/// 手写层数据模型
class InkLayer {
  /// 层 ID
  final String id;

  /// 所属类型
  final InkLayerType type;

  /// 关联 ID（节点级时为节点 ID，画布级时为导图 ID）
  final String ownerId;

  /// 笔迹列表
  final List<InkStroke> strokes;

  /// 层的 Z 序索引
  final int zIndex;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  const InkLayer({
    required this.id,
    required this.type,
    required this.ownerId,
    this.strokes = const [],
    this.zIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 转为数据库 Map
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'owner_id': ownerId,
    'strokes_json': jsonEncode(strokes.map((s) => s.toJson()).toList()),
    'z_index': zIndex,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// 从数据库 Map 创建
  factory InkLayer.fromMap(Map<String, dynamic> map) {
    final strokesJson = jsonDecode(map['strokes_json'] as String) as List;
    return InkLayer(
      id: map['id'] as String,
      type: InkLayerType.values.byName(map['type'] as String),
      ownerId: map['owner_id'] as String,
      strokes: strokesJson.map((s) => InkStroke.fromJson(s)).toList(),
      zIndex: map['z_index'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
```

#### 3.2.2 InkLayerController（手写状态管理）

```dart
/// 手写层控制器
class InkLayerController extends ChangeNotifier {
  /// 当前活跃的手写层
  InkLayer? _activeLayer;
  InkLayer? get activeLayer => _activeLayer;

  /// 所有画布级手写层（每个导图一个）
  final Map<String, InkLayer> _canvasLayers = {};

  /// 所有节点级手写层（每个节点一个）
  final Map<String, InkLayer> _nodeLayers = {};

  /// 当前绘制的笔迹（临时）
  InkStroke? _currentStroke;

  /// 当前工具
  InkTool _currentTool = InkTool.pen;
  InkTool get currentTool => _currentTool;

  /// 当前颜色
  Color _currentColor = Colors.black;
  Color get currentColor => _currentColor;

  /// 当前笔宽度
  double _currentWidth = 2.0;
  double get currentWidth => _currentWidth;

  /// 是否在手写模式
  bool _isInkMode = false;
  bool get isInkMode => _isInkMode;

  /// 历史记录（撤销/重做）
  final UndoRedoStack<InkAction> _undoStack = UndoRedoStack();

  /// 选择的手迹集合（套索选择后）
  final Set<String> _selectedStrokeIds = {};
  Set<String> get selectedStrokeIds => _selectedStrokeIds;

  /// 设置活跃层
  void setActiveLayer(InkLayer? layer) {
    _activeLayer = layer;
    notifyListeners();
  }

  /// 获取或创建画布级层
  InkLayer getOrCreateCanvasLayer(String topicId) {
    if (!_canvasLayers.containsKey(topicId)) {
      _canvasLayers[topicId] = InkLayer(
        id: 'ink-canvas-$topicId',
        type: InkLayerType.canvas,
        ownerId: topicId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return _canvasLayers[topicId]!;
  }

  /// 获取或创建节点级层
  InkLayer getOrCreateNodeLayer(String noteId) {
    if (!_nodeLayers.containsKey(noteId)) {
      _nodeLayers[noteId] = InkLayer(
        id: 'ink-node-$noteId',
        type: InkLayerType.node,
        ownerId: noteId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return _nodeLayers[noteId]!;
  }

  /// 开始绘制笔迹
  void startStroke(Offset point, double? pressure) {
    if (_activeLayer == null) return;

    _currentStroke = InkStroke(
      points: [],
      color: _currentColor.toARGB32(),
      strokeWidth: _currentWidth,
      isHighlighter: _currentTool == InkTool.highlighter,
    );

    addStrokePoint(point, pressure);
    notifyListeners();
  }

  /// 添加笔迹点
  void addStrokePoint(Offset point, double? pressure) {
    if (_currentStroke == null) return;

    final inkPoint = InkPoint(
      x: point.dx,
      y: point.dy,
      pressure: _currentTool == InkTool.pen ? pressure : null,
    );

    _currentStroke!.points.add(inkPoint);
    notifyListeners();
  }

  /// 结束绘制笔迹
  void endStroke() {
    if (_currentStroke == null || _activeLayer == null) return;

    // 添加到历史记录
    _undoStack.push(InkAction.addStroke(
      layerId: _activeLayer!.id,
      stroke: _currentStroke!,
    ));

    // 添加到层
    _activeLayer!.strokes.add(_currentStroke!);
    _currentStroke = null;

    notifyListeners();
  }

  /// 撤销
  void undo() {
    final action = _undoStack.undo();
    if (action == null) return;

    _applyActionReverse(action);
    notifyListeners();
  }

  /// 重做
  void redo() {
    final action = _undoStack.redo();
    if (action == null) return;

    _applyAction(action);
    notifyListeners();
  }

  /// 橡皮擦：删除选中区域的笔迹
  void eraseStrokes(Rect eraserBounds) {
    if (_activeLayer == null) return;

    final erasedIds = <String>[];
    for (final stroke in _activeLayer!.strokes) {
      if (stroke.bounds?.overlaps(eraserBounds) ?? false) {
        erasedIds.add('${stroke.hashCode}');
      }
    }

    // 添加到历史记录
    _undoStack.push(InkAction.eraseStrokes(
      layerId: _activeLayer!.id,
      strokeIds: erasedIds,
    ));

    // 删除笔迹
    _activeLayer!.strokes.removeWhere(
      (s) => s.bounds?.overlaps(eraserBounds) ?? false
    );

    notifyListeners();
  }

  /// 套索选择
  void lassoSelect(Path lassoPath) {
    if (_activeLayer == null) return;

    _selectedStrokeIds.clear();
    for (final stroke in _activeLayer!.strokes) {
      // 检查笔迹是否在套索区域内
      if (stroke.points.any((p) => lassoPath.contains(Offset(p.x, p.y)))) {
        _selectedStrokeIds.add('${stroke.hashCode}');
      }
    }

    notifyListeners();
  }

  /// 移动选中的笔迹
  void moveSelectedStrokes(Offset delta) {
    if (_activeLayer == null) return;

    for (final stroke in _activeLayer!.strokes) {
      if (_selectedStrokeIds.contains('${stroke.hashCode}')) {
        for (final point in stroke.points) {
          point.x += delta.dx;
          point.y += delta.dy;
        }
      }
    }

    notifyListeners();
  }
}

/// 手写动作（用于撤销/重做）
class InkAction {
  final String type;
  final String layerId;
  final InkStroke? stroke;
  final List<String>? strokeIds;
  final Offset? delta;

  InkAction.addStroke({required this.layerId, required this.stroke})
      : type = 'add', strokeIds = null, delta = null;

  InkAction.eraseStrokes({required this.layerId, required this.strokeIds})
      : type = 'erase', stroke = null, delta = null;

  InkAction.moveStrokes({required this.layerId, required this.delta, required this.strokeIds})
      : type = 'move', stroke = null;
}
```

#### 3.2.3 CanvasInkLayer（画布级手写组件）

```dart
/// 画布级手写层组件
class CanvasInkLayer extends StatefulWidget {
  final MindMapController mindMapController;
  final InkLayerController inkController;
  final InkLayer layer;

  const CanvasInkLayer({
    super.key,
    required this.mindMapController,
    required this.inkController,
    required this.layer,
  });

  @override
  State<CanvasInkLayer> createState() => _CanvasInkLayerState();
}

class _CanvasInkLayerState extends State<CanvasInkLayer> {
  /// 视口变换（缩放、平移）
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  /// 笔迹稳定器
  late StrokeStabilizer _stabilizer;

  /// 当前活跃笔迹的点列表
  List<InkPoint> _currentPoints = [];

  @override
  void initState() {
    super.initState();
    _stabilizer = StrokeStabilizer(level: 3);
    _syncViewport();
  }

  void _syncViewport() {
    _scale = widget.mindMapController.viewportScale;
    _offset = widget.mindMapController.viewportOffset;
  }

  @override
  Widget build(BuildContext context) {
    // 监听视口变换
    _syncViewport();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: CanvasInkPainter(
          strokes: widget.layer.strokes,
          currentPoints: _currentPoints,
          currentColor: widget.inkController.currentColor,
          currentWidth: widget.inkController.currentWidth,
          isHighlighter: widget.inkController.currentTool == InkTool.highlighter,
          scale: _scale,
          offset: _offset,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.inkController.isInkMode) return;

    // 将屏幕坐标转换为画布坐标
    final canvasPoint = _screenToCanvas(event.localPosition);

    // 根据工具类型处理
    switch (widget.inkController.currentTool) {
      case InkTool.pen:
        widget.inkController.startStroke(canvasPoint, event.pressure);
        break;
      case InkTool.highlighter:
        widget.inkController.startStroke(canvasPoint, null);
        break;
      case InkTool.eraser:
        _startErase(canvasPoint, event.pressure);
        break;
      case InkTool.lasso:
        _startLasso(canvasPoint);
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.inkController.isInkMode) return;

    final canvasPoint = _screenToCanvas(event.localPosition);

    switch (widget.inkController.currentTool) {
      case InkTool.pen:
        widget.inkController.addStrokePoint(canvasPoint, event.pressure);
        break;
      case InkTool.highlighter:
        widget.inkController.addStrokePoint(canvasPoint, null);
        break;
      case InkTool.eraser:
        _updateErase(canvasPoint);
        break;
      case InkTool.lasso:
        _updateLasso(canvasPoint);
        break;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!widget.inkController.isInkMode) return;

    switch (widget.inkController.currentTool) {
      case InkTool.pen:
      case InkTool.highlighter:
        widget.inkController.endStroke();
        break;
      case InkTool.eraser:
        _endErase();
        break;
      case InkTool.lasso:
        _endLasso();
        break;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _currentPoints.clear();
  }

  /// 屏幕坐标转画布坐标
  Offset _screenToCanvas(Offset screenPoint) {
    return (screenPoint - _offset) / _scale;
  }

  /// 画布坐标转屏幕坐标
  Offset _canvasToScreen(Offset canvasPoint) {
    return canvasPoint * _scale + _offset;
  }

  // ... 橡皮擦和套索实现省略
}
```

#### 3.2.4 CanvasInkPainter（画布手写渲染器）

```dart
/// 画布手写绘制器
class CanvasInkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<InkPoint> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isHighlighter;
  final double scale;
  final Offset offset;

  CanvasInkPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isHighlighter,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 应用视口变换
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // 渲染已保存的笔迹
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 渲染当前正在绘制的笔迹
    if (currentPoints.isNotEmpty) {
      _drawCurrentStroke(canvas);
    }
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = Color(stroke.color).withOpacity(stroke.isHighlighter ? 0.3 : 1.0)
      ..strokeWidth = stroke.strokeWidth / scale  // 补偿缩放
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);

    // 使用贝塞尔曲线平滑连接点
    for (int i = 1; i < stroke.points.length; i++) {
      final prev = stroke.points[i - 1];
      final curr = stroke.points[i];

      // 压感影响宽度
      if (stroke.points[i].pressure != null) {
        paint.strokeWidth = stroke.strokeWidth * stroke.points[i].pressure! / scale;
      }

      final midX = (prev.x + curr.x) / 2;
      final midY = (prev.y + curr.y) / 2;
      path.quadraticBezierTo(prev.x, prev.y, midX, midY);
    }

    canvas.drawPath(path, paint);
  }

  void _drawCurrentStroke(Canvas canvas) {
    final paint = Paint()
      ..color = currentColor.withOpacity(isHighlighter ? 0.3 : 1.0)
      ..strokeWidth = currentWidth / scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(currentPoints.first.x, currentPoints.first.y);

    for (int i = 1; i < currentPoints.length; i++) {
      final prev = currentPoints[i - 1];
      final curr = currentPoints[i];
      final midX = (prev.x + curr.x) / 2;
      final midY = (prev.y + curr.y) / 2;
      path.quadraticBezierTo(prev.x, prev.y, midX, midY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CanvasInkPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentPoints != oldDelegate.currentPoints ||
        currentColor != oldDelegate.currentColor ||
        currentWidth != oldDelegate.currentWidth ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset;
  }
}
```

### 3.3 节点级手写实现

#### 3.3.1 NodeNoteContent（节点笔记内容组件）

```dart
/// 节点笔记内容组件
///
/// 支持：文本、图片、手写叠加
class NodeNoteContent extends StatefulWidget {
  final Note note;
  final InkLayerController inkController;
  final bool isInkMode;

  const NodeNoteContent({
    super.key,
    required this.note,
    required this.inkController,
    this.isInkMode = false,
  });

  @override
  State<NodeNoteContent> createState() => _NodeNoteContentState();
}

class _NodeNoteContentState extends State<NodeNoteContent> {
  InkLayer? _nodeInkLayer;

  @override
  void initState() {
    super.initState();
    _loadInkLayer();
  }

  void _loadInkLayer() {
    _nodeInkLayer = widget.inkController.getOrCreateNodeLayer(widget.note.id);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.note.content;

    return Stack(
      children: [
        // 基础内容层（文本 + 图片）
        _buildContentLayer(content),

        // 手写层叠加
        if (_nodeInkLayer != null)
          Positioned.fill(
            child: NodeInkOverlay(
              layer: _nodeInkLayer!,
              inkController: widget.inkController,
              isInkMode: widget.isInkMode,
            ),
          ),
      ],
    );
  }

  Widget _buildContentLayer(NoteContent? content) {
    if (content == null || content.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content.segments.map((segment) {
        switch (segment.type) {
          case SegmentType.text:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                segment.text ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            );
          case SegmentType.image:
            return _buildImageSegment(segment);
          default:
            return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Widget _buildImageSegment(Segment segment) {
    final imagePath = segment.path;
    final width = segment.width ?? 400.0;
    final height = segment.height ?? 200.0;

    if (imagePath == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
```

#### 3.3.2 NodeInkOverlay（节点手写叠加层）

```dart
/// 节点手写叠加层
class NodeInkOverlay extends StatefulWidget {
  final InkLayer layer;
  final InkLayerController inkController;
  final bool isInkMode;

  const NodeInkOverlay({
    super.key,
    required this.layer,
    required this.inkController,
    this.isInkMode = false,
  });

  @override
  State<NodeInkOverlay> createState() => _NodeInkOverlayState();
}

class _NodeInkOverlayState extends State<NodeInkOverlay> {
  List<InkPoint> _currentPoints = [];

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: CustomPaint(
        painter: NodeInkPainter(
          strokes: widget.layer.strokes,
          currentPoints: _currentPoints,
          currentColor: widget.inkController.currentColor,
          currentWidth: widget.inkController.currentWidth,
          isHighlighter: widget.inkController.currentTool == InkTool.highlighter,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isInkMode) return;

    widget.inkController.setActiveLayer(widget.layer);
    widget.inkController.startStroke(event.localPosition, event.pressure);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isInkMode) return;
    widget.inkController.addStrokePoint(event.localPosition, event.pressure);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!widget.isInkMode) return;
    widget.inkController.endStroke();
  }
}
```

### 3.4 工具栏 UI

```dart
/// 手写工具栏
class InkToolbar extends StatelessWidget {
  final InkLayerController controller;
  final VoidCallback? onClose;

  const InkToolbar({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x80242930),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // 工具按钮
          _ToolButton(
            icon: Icons.edit,
            isSelected: controller.currentTool == InkTool.pen,
            onTap: () => controller.setTool(InkTool.pen),
          ),
          _ToolButton(
            icon: Icons.highlight,
            isSelected: controller.currentTool == InkTool.highlighter,
            onTap: () => controller.setTool(InkTool.highlighter),
          ),
          _ToolButton(
            icon: Icons.cleaning_services,
            isSelected: controller.currentTool == InkTool.eraser,
            onTap: () => controller.setTool(InkTool.eraser),
          ),
          _ToolButton(
            icon: Icons.lasso_select,
            isSelected: controller.currentTool == InkTool.lasso,
            onTap: () => controller.setTool(InkTool.lasso),
          ),

          const SizedBox(width: 16),

          // 颜色选择
          _ColorPicker(
            currentColor: controller.currentColor,
            onColorChanged: (color) => controller.setColor(color),
          ),

          const SizedBox(width: 16),

          // 宽度调节
          _WidthSlider(
            currentWidth: controller.currentWidth,
            onWidthChanged: (width) => controller.setWidth(width),
          ),

          const Spacer(),

          // 撤销/重做
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: controller.canUndo ? controller.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: controller.canRedo ? controller.redo : null,
          ),

          // 关闭
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// 工具类型
enum InkTool {
  pen,
  highlighter,
  eraser,
  lasso,
}
```

---

## 4. 数据存储设计

### 4.1 数据库表结构

```sql
-- 手写层表
CREATE TABLE ink_layers (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,           -- 'canvas' 或 'node'
  owner_id TEXT NOT NULL,       -- 导图 ID 或节点 ID
  strokes_json TEXT,            -- JSON 序列化的笔迹
  z_index INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,

  -- 外键关联
  FOREIGN KEY (owner_id) REFERENCES topics(id) ON DELETE CASCADE,
  FOREIGN KEY (owner_id) REFERENCES notes(id) ON DELETE CASCADE
);

-- 创建索引
CREATE INDEX idx_ink_layers_type ON ink_layers(type);
CREATE INDEX idx_ink_layers_owner ON ink_layers(owner_id);
```

### 4.2 Rust FFI 存储

在 `rust/src/storage/ink.rs` 中新增：

```rust
use flutter_rust_bridge::frb;

#[frb]
pub struct InkLayer {
    pub id: String,
    pub type: String,
    pub owner_id: String,
    pub strokes_json: String,
    pub z_index: i32,
    pub created_at: String,
    pub updated_at: String,
}

#[frb]
pub fn save_ink_layer(layer: InkLayer) -> Result<(), String> {
    // SQLite 存储
    let conn = get_connection()?;
    conn.execute(
        "INSERT OR REPLACE INTO ink_layers (id, type, owner_id, strokes_json, z_index, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![
            layer.id,
            layer.type,
            layer.owner_id,
            layer.strokes_json,
            layer.z_index,
            layer.created_at,
            layer.updated_at,
        ],
    )?;
    Ok(())
}

#[frb]
pub fn get_ink_layer_by_owner(owner_id: String, type: String) -> Result<Option<InkLayer>, String> {
    // 查询
    let conn = get_connection()?;
    let mut stmt = conn.prepare(
        "SELECT id, type, owner_id, strokes_json, z_index, created_at, updated_at
         FROM ink_layers WHERE owner_id = ?1 AND type = ?2"
    )?;

    let layer = stmt.query_row(params![owner_id, type], |row| {
        Ok(InkLayer {
            id: row.get(0)?,
            type: row.get(1)?,
            owner_id: row.get(2)?,
            strokes_json: row.get(3)?,
            z_index: row.get(4)?,
            created_at: row.get(5)?,
            updated_at: row.get(6)?,
        })
    }).optional()?;

    Ok(layer)
}
```

---

## 5. 重构计划

### 5.1 Phase 2.1：核心手写层（4-5天）

**任务**：
1. 创建 `InkLayer` 数据模型
2. 实现 `InkLayerController`
3. 实现画布级手写层基础功能（笔迹绘制）

**验收**：
- 可在画布上绘制笔迹
- 笔迹随缩放/平移同步变换

### 5.2 Phase 2.2：工具完善（3-4天）

**任务**：
1. 实现荧光笔工具
2. 实现橡皮擦工具
3. 实现套索选择与移动

**验收**：
- 四种工具正常工作
- 套索选择后可移动笔迹

### 5.3 Phase 2.3：节点级手写（2-3天）

**任务**：
1. 实现 `NodeNoteContent` 组件
2. 实现节点手写叠加层
3. 图片嵌入支持

**验收**：
- 节点笔记可嵌入图片
- 可在图片上手写

### 5.4 Phase 2.4：数据持久化（2-3天）

**任务**：
1. 新增 `ink_layers` 数据库表
2. Rust FFI 存储 API
3. 加载/保存手写层

**验收**：
- 手写数据正确保存
- 重开后手写恢复

---

## 6. 文件结构

```
lib/src/mindmap/
├── ink/
│   ├── ink_layer.dart              # 手写层数据模型
│   ├── ink_layer_controller.dart   # 手写状态管理
│   ├── ink_tool.dart               # 工具类型枚举
│   ├── ink_action.dart             # 撤销/重做动作
│   └── ink_layer_repository.dart   # 数据持久化
├── ui/
│   ├── canvas_ink_layer.dart       # 画布级手写组件
│   ├── canvas_ink_painter.dart     # 画布手写绘制器
│   ├── node_note_content.dart      # 节点笔记内容
│   ├── node_ink_overlay.dart       # 节点手写叠加层
│   └── ink_toolbar.dart            # 手写工具栏
└── test/
    └── ink/
        ├── ink_layer_controller_test.dart
        └── ink_painter_test.dart
```

---

## 7. 测试策略

### 7.1 单元测试

```dart
test('InkLayerController manages strokes correctly', () {
  final controller = InkLayerController();
  final layer = controller.getOrCreateCanvasLayer('topic-1');

  controller.setActiveLayer(layer);
  controller.startStroke(Offset(0, 0), null);
  controller.addStrokePoint(Offset(10, 10), null);
  controller.endStroke();

  expect(layer.strokes.length, 1);
  expect(layer.strokes.first.points.length, 2);
});

test('Canvas coordinates transform correctly', () {
  final scale = 2.0;
  final offset = Offset(100, 50);

  // 屏幕点 (200, 100) -> 画布点 (50, 25)
  final screenPoint = Offset(200, 100);
  final canvasPoint = (screenPoint - offset) / scale;

  expect(canvasPoint.dx, 50);
  expect(canvasPoint.dy, 25);
});
```

### 7.2 集成测试

```dart
testWidgets('Canvas ink layer draws and scales', (tester) async {
  await tester.pumpWidget(TestMindMapApp());

  // 进入手写模式
  await tester.tap(find.byIcon(Icons.edit));

  // 模拟绘制
  await tester.drag(
    find.byType(CanvasInkLayer),
    Offset(100, 100),
  );

  // 验证笔迹存在
  final controller = tester.state<InkLayerControllerState>(find.byType(CanvasInkLayer));
  expect(controller.activeLayer?.strokes.length, greaterThan(0));
});
```

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 性能问题（大量笔迹） | 中 | 分层渲染、缓存优化 |
| 触控笔兼容性 | 中 | 参考 Saber 的触控笔处理 |
| 与节点拖拽冲突 | 高 | 手写模式与编辑模式分离 |

---

## 9. 验收标准

### 9.1 功能验收

- [ ] 画布级手写支持四种工具
- [ ] 笔迹随视口变换同步
- [ ] 节点级手写支持图片嵌入
- [ ] 撤销/重做正常工作

### 9.2 质量验收

- [ ] 单元测试覆盖率 > 70%
- [ ] 无内存泄漏
- [ ] 性能：绘制流畅 > 60 FPS

---

## 10. 下一步

完成阶段 2 后，进入**阶段 3：GuruMind 导入**。

---

*设计者：Claude Code*