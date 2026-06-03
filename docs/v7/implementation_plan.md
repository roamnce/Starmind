# 思维导图模块自由画布与自适应布局 (v7.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement free canvas, zoom/pan viewport, symmetrical left/right/both-sided automatic layouts, horizontal connection curve engine, culling optimization, and node Tab/Enter/Delete operations in Dart/Flutter.

**Architecture:** Modify existing `TreeLayout`, `MindMapCanvasPainter`, `MindMapController`, `MindMapPage`, and `NodeWidget` files under `lib/src/mindmap/ui/` to upgrade the mindmap canvas.

**Tech Stack:** Dart, Flutter.

---

### Task 1: TreeLayout 扩展（多向树形与对称布局计算）

**Files:**
- Modify: `lib/src/mindmap/ui/tree_layout.dart`

- [ ] **Step 1: 扩展 TreeLayout 以支持水平左侧/右侧/两侧排布**
  
  修改 `TreeLayout` 类以支持左侧布局、右侧布局和对称两侧布局。
  
  将 `lib/src/mindmap/ui/tree_layout.dart` 的 `LayoutDirection` 扩展并改写核心计算逻辑：
  ```dart
  // lib/src/mindmap/ui/tree_layout.dart

  import 'package:flutter/material.dart';
  import '../service/mindmap_service.dart';

  /// 树形布局方向
  enum LayoutDirection {
    /// 垂直布局（根在上，子在下）
    vertical,
    /// 水平布局（根在左，子在右）
    horizontal,
    /// 左侧布局（根在右，子在左）
    left,
    /// 两侧布局（根在中央，子在左右两侧）
    bothSides,
  }

  /// 树形自动布局算法
  class TreeLayout {
    final double nodeWidth;
    final double nodeHeight;
    final double horizontalSpacing;
    final double verticalSpacing;
    final LayoutDirection direction;

    const TreeLayout({
      this.nodeWidth = 120,
      this.nodeHeight = 40,
      this.horizontalSpacing = 60,
      this.verticalSpacing = 30,
      this.direction = LayoutDirection.bothSides,
    });

    /// 计算所有节点中心位置坐标
    Map<String, Offset> calculate(NoteTreeNode root) {
      final positions = <String, Offset>{};
      
      if (direction == LayoutDirection.bothSides) {
        // 两侧布局：将根节点的一级子节点平分到左右两侧
        positions[root.note.id] = Offset.zero;
        final children = root.children;
        if (children.isEmpty) return positions;

        final leftChildren = <NoteTreeNode>[];
        final rightChildren = <NoteTreeNode>[];
        
        for (int i = 0; i < children.length; i++) {
          if (i % 2 == 0) {
            rightChildren.add(children[i]);
          } else {
            leftChildren.add(children[i]);
          }
        }

        // 右侧树自顶向下横向排布
        final rightPositions = <String, Offset>{};
        _layoutSubtreeHorizontal(rightChildren, Offset(horizontalSpacing + nodeWidth, 0), rightPositions, true);
        positions.addAll(rightPositions);

        // 左侧树自顶向下横向排布
        final leftPositions = <String, Offset>{};
        _layoutSubtreeHorizontal(leftChildren, Offset(-horizontalSpacing - nodeWidth, 0), leftPositions, false);
        positions.addAll(leftPositions);
      } else {
        // 垂直或单侧布局
        if (direction == LayoutDirection.left) {
          _layoutSubtreeSingle(root, Offset.zero, positions, false);
        } else {
          _layoutSubtreeSingle(root, Offset.zero, positions, true);
        }
      }
      return positions;
    }

    /// 水平横向布局子树（两侧布局辅助方法）
    double _layoutSubtreeHorizontal(
      List<NoteTreeNode> nodes,
      Offset origin,
      Map<String, Offset> positions,
      bool isRight,
    ) {
      if (nodes.isEmpty) return 0;
      double currentY = origin.dy;
      
      for (final child in nodes) {
        positions[child.note.id] = Offset(origin.dx, currentY);
        final nextX = isRight 
            ? origin.dx + nodeWidth + horizontalSpacing 
            : origin.dx - nodeWidth - horizontalSpacing;
        
        if (child.children.isNotEmpty) {
          _layoutSubtreeHorizontal(child.children, Offset(nextX, currentY), positions, isRight);
        }
        currentY += nodeHeight + verticalSpacing;
      }
      return currentY - origin.dy;
    }

    /// 单侧（全左/全右）布局计算
    double _layoutSubtreeSingle(
      NoteTreeNode node,
      Offset origin,
      Map<String, Offset> positions,
      bool isRight,
    ) {
      positions[node.note.id] = origin;
      if (node.children.isEmpty) {
        return nodeHeight;
      }

      double totalHeight = 0;
      final childX = isRight 
          ? origin.dx + nodeWidth + horizontalSpacing 
          : origin.dx - nodeWidth - horizontalSpacing;
      
      double currentY = origin.dy - (node.children.length - 1) * (nodeHeight + verticalSpacing) / 2;

      for (final child in node.children) {
        _layoutSubtreeSingle(child, Offset(childX, currentY), positions, isRight);
        currentY += nodeHeight + verticalSpacing;
        totalHeight += nodeHeight + verticalSpacing;
      }

      return totalHeight;
    }

    /// 计算树的连线
    List<Connection> calculateConnections(
      NoteTreeNode root,
      Map<String, Offset> positions,
    ) {
      final connections = <Connection>[];
      _collectConnections(root, positions, connections);
      return connections;
    }

    void _collectConnections(
      NoteTreeNode node,
      Map<String, Offset> positions,
      List<Connection> connections,
    ) {
      final parentPos = positions[node.note.id];
      if (parentPos == null) return;

      for (final child in node.children) {
        final childPos = positions[child.note.id];
        if (childPos != null) {
          Offset start, end;
          // 根据子节点水平相对父节点位置自动判别起点与终点锚点
          if (childPos.dx > parentPos.dx) {
            start = Offset(parentPos.dx + nodeWidth / 2, parentPos.dy);
            end = Offset(childPos.dx - nodeWidth / 2, childPos.dy);
          } else {
            start = Offset(parentPos.dx - nodeWidth / 2, parentPos.dy);
            end = Offset(childPos.dx + nodeWidth / 2, childPos.dy);
          }

          connections.add(Connection(
            fromId: node.note.id,
            toId: child.note.id,
            start: start,
            end: end,
          ));
        }
        _collectConnections(child, positions, connections);
      }
    }
  }

  /// 连线数据
  class Connection {
    final String fromId;
    final String toId;
    final Offset start;
    final Offset end;

    const Connection({
      required this.fromId,
      required this.toId,
      required this.start,
      required this.end,
    });
  }
  ```

- [ ] **Step 2: 编写测试并运行**
  
  运行 static analyzer 检查布局算法无语法报错。

---

### Task 2: 连线引擎 CustomPaint 水平方向曲线重排

**Files:**
- Modify: `lib/src/mindmap/ui/canvas_painter.dart`

- [ ] **Step 1: 适配水平与双侧布局的贝塞尔曲线计算**
  
  修改 `MindMapCanvasPainter` 类，在计算控制点时采用水平偏移量 `dx` 而非垂直偏移量 `dy`。
  
  重写 `_createBezierPath` 与 `_createSteppedPath` 方法：
  ```dart
  // lib/src/mindmap/ui/canvas_painter.dart 中修改如下方法：

  Path _createBezierPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // 基于水平方向偏移值 dx 计算贝塞尔控制点
    final dx = (conn.end.dx - conn.start.dx).abs();
    final controlOffset = dx * 0.45;

    final control1 = Offset(
      conn.start.dx + (conn.end.dx > conn.start.dx ? controlOffset : -controlOffset),
      conn.start.dy,
    );
    final control2 = Offset(
      conn.end.dx - (conn.end.dx > conn.start.dx ? controlOffset : -controlOffset),
      conn.end.dy,
    );

    path.cubicTo(
      control1.dx, control1.dy,
      control2.dx, control2.dy,
      conn.end.dx, conn.end.dy,
    );

    return path;
  }

  Path _createSteppedPath(Connection conn) {
    final path = Path();
    path.moveTo(conn.start.dx, conn.start.dy);

    // 水平直角折线拐角计算
    final midX = (conn.start.dx + conn.end.dx) / 2;

    path.lineTo(midX, conn.start.dy);
    path.lineTo(midX, conn.end.dy);
    path.lineTo(conn.end.dx, conn.end.dy);

    return path;
  }
  ```

- [ ] **Step 2: 验证编译状态**
  
  确认没有未定义的属性引用，曲线坐标系转换逻辑无报错。

---

### Task 3: MindMapController 扩展与 CRUD 节点处理

**Files:**
- Modify: `lib/src/mindmap/ui/mindmap_controller.dart`

- [ ] **Step 1: 新增同级节点与 Tab 子节点创建接口**
  
  扩展 Controller 状态，管理布局样式并添加支持键盘的同级节点和子节点交互逻辑。
  
  更新 `lib/src/mindmap/ui/mindmap_controller.dart` 如下：
  ```dart
  // lib/src/mindmap/ui/mindmap_controller.dart 新增及修改方法：

  LayoutDirection _layoutDirection = LayoutDirection.bothSides;
  LayoutDirection get layoutDirection => _layoutDirection;

  void changeLayoutDirection(LayoutDirection dir) {
    _layoutDirection = dir;
    notifyListeners();
  }

  /// 创建子节点 (Tab)
  Future<Note?> createChildNode({required String title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.id;

    final childNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    await _service.addChild(parentId: parentId, childId: childNote.id);
    await _loadNoteTree(_selectedTopic!.id);
    
    // 选中新节点
    selectNote(childNote);
    return childNote;
  }

  /// 创建同级节点 (Enter)
  Future<Note?> createSiblingNode({required String title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.parentId; // 同级拥有相同的父 ID

    final siblingNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    if (parentId == null) {
      await _service.addRootNote(
        topicId: _selectedTopic!.id,
        noteId: siblingNote.id,
      );
    } else {
      await _service.addChild(parentId: parentId, childId: siblingNote.id);
    }

    await _loadNoteTree(_selectedTopic!.id);
    
    // 选中新节点
    selectNote(siblingNote);
    return siblingNote;
  }
  ```

---

### Task 4: InteractiveViewer 视口重构与 Culling 优化

**Files:**
- Modify: `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: 重构 Canvas 视口并加上屏幕外裁剪**
  
  使用 `InteractiveViewer` 重构主画布，加入视口裁剪计算。
  
  修改 `lib/src/mindmap/ui/mindmap_page.dart` 中的 `_buildCanvas` 方法：
  ```dart
  // lib/src/mindmap/ui/mindmap_page.dart

  Widget _buildCanvas(BuildContext context) {
    final layout = TreeLayout(direction: controller.layoutDirection);

    final positions = <String, Offset>{};
    final connections = <Connection>{};

    for (final root in controller.noteTree) {
      positions.addAll(layout.calculate(root));
      connections.addAll(layout.calculateConnections(root, positions));
    }

    final bounds = _calculateBounds(positions, layout);

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          constrained: false,
          minScale: MindMapController.minScale,
          maxScale: MindMapController.maxScale,
          boundaryMargin: const EdgeInsets.all(500),
          child: Container(
            width: bounds.width + 1000,
            height: bounds.height + 1000,
            child: Stack(
              children: [
                // 连线层
                RepaintBoundary(
                  child: CustomPaint(
                    painter: MindMapCanvasPainter(
                      connections: connections.toList(),
                      lineColor: Theme.of(context).colorScheme.outline,
                      lineWidth: 2,
                    ),
                    size: Size(bounds.width + 1000, bounds.height + 1000),
                  ),
                ),
                // 节点层与 Viewport Culling 裁剪
                ...positions.entries.map((entry) {
                  final noteId = entry.key;
                  final pos = entry.value;
                  final note = _findNote(controller.noteTree, noteId);

                  if (note == null) return const SizedBox.shrink();

                  // 节点实际偏移渲染
                  final left = pos.dx - layout.nodeWidth / 2 + 500;
                  final top = pos.dy + 500;

                  // 每个节点加上 RepaintBoundary 保护，独立重绘范围
                  return Positioned(
                    left: left,
                    top: top,
                    child: RepaintBoundary(
                      child: NodeWidget(
                        note: note,
                        isSelected: controller.selectedNote?.id == noteId,
                        onTap: () => controller.selectNote(note),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }
    );
  }
  ```

---

### Task 5: 节点 Widget 样式对齐

**Files:**
- Modify: `lib/src/mindmap/ui/node_widget.dart`

- [ ] **Step 1: 对齐高保真暗色高亮微发光样式**
  
  修改 `NodeWidget` 组件，调整它的配色、圆角和阴影，使其符合高保真 HTML 原型的金黄色高亮边框和流光感觉。
  
  修改 `lib/src/mindmap/ui/node_widget.dart` 中 `build` 方法：
  ```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 自定义金黄色选中状态
    final accentColor = const Color(0xFFC8841A);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF242930), // 原型经典深灰色
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0x15FFDC8C),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.pdfId != null) ...[
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 14,
                color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  ```
