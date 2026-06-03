# 脑图双向交互雷达、信息弹窗与全局快捷键 (v11.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现思维导图双向交互式浮动雷达小地图、高保真磨砂信息统计弹窗，以及 Workspace 系统级的全局 Shortcuts 键盘流控制与局部防崩溃分屏模式。

**Architecture:**
采用解耦的组件编排模式。在脑图页面上方层叠 `NavigationRadar` 与 `InfoStatisticsModal` 组件。
小地图利用数学投影将脑图元素渲染为缩微图，并通过覆盖手势层捕获平移矩阵，实现拖拽缩微视口框平滑平移主视口。
键盘 Shortcuts 监听通过 `Focus` 绑定全局组合键，联动宿主 `WorkspaceController`（左侧树折叠、关闭 Tab）与脑图内局部 Row 布局（防崩溃分屏）。

**Tech Stack:** Flutter, CustomPainter, Atkinson Hyperlegible Next Font, WorkspaceController, Unit Tests.

---

## 1. 文件更新列表与职责边界

| 文件路径 | 职责类型 | 变更描述 |
| :--- | :--- | :--- |
| [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/page.dart) | **MODIFY** | 将键盘 Focus onKeyEvent 进行大量全局快捷键的扩充，放置雷达小地图，并实现 `_isLocalSplitMode` 局部防崩分屏。 |
| [bottom_action_bar.dart](file:///d:/starmind/lib/src/mindmap/ui/bottom_action_bar.dart) | **MODIFY** | 在最左侧添加信息统计按钮（`Icons.info_outline_rounded`），点击触发展示磨砂玻璃弹窗，并将分屏按钮绑定至本地局部分屏开关。 |
| [info_statistics_modal.dart](file:///d:/starmind/lib/src/mindmap/ui/info_statistics_modal.dart) | **NEW** | 关于导图的高保真磨砂统计对话框组件，实时递归计算节点数、总标题/笔记字数、嵌套数及树深度。 |
| [navigation_radar.dart](file:///d:/starmind/lib/src/mindmap/ui/navigation_radar.dart) | **NEW** | 小地图浮窗与 `RadarPainter` 绘制器，支持双向交互式拖拽平移画布。 |
| [radar_painter_test.dart](file:///d:/starmind/test/mindmap/ui/radar_painter_test.dart) | **NEW** | 验证小地图微缩包围框与可视视口框在各种变换矩阵下的坐标换算准确性。 |
| [shortcuts_mapping_test.dart](file:///d:/starmind/test/mindmap/ui/shortcuts_mapping_test.dart) | **NEW** | 验证 Focus 键盘绑定拦截对宿主 Workspace 控制器的调用，以及锁定状态下的拦截校验。 |

---

## 2. 分步开发计划

### Task 1: 导图信息统计磨砂弹窗 (Info Statistics Modal)

**Files:**
*   Create: `lib/src/mindmap/ui/info_statistics_modal.dart`
*   Modify: `lib/src/mindmap/ui/bottom_action_bar.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: 编写信息统计对话框 UI 组件**
  在 `lib/src/mindmap/ui/info_statistics_modal.dart` 中实现磨砂玻璃及数据遍历计算：
  ```dart
  import 'dart:ui';
  import 'package:flutter/material.dart';
  import 'mindmap_controller.dart';
  import '../service/mindmap_service.dart' show NoteTreeNode;

  class InfoStatisticsModal extends StatelessWidget {
    final MindMapController controller;
    final VoidCallback onClose;

    const InfoStatisticsModal({
      super.key,
      required this.controller,
      required this.onClose,
    });

    @override
    Widget build(BuildContext context) {
      // 递归计算数据
      final nodeCount = _countNodes(controller.noteTree);
      final charStats = _countCharacters(controller.noteTree);
      final containerCount = _countContainers(controller.noteTree);
      final maxDepth = _calculateMaxDepth(controller.noteTree);

      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xD91C222B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F2A3547), width: 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('关于导图', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const Divider(color: Color(0x15FFFFFF), height: 20),
                  _buildStatRow('节点总数', '$nodeCount 个'),
                  _buildStatRow('嵌套容器', '$containerCount 个'),
                  _buildStatRow('标题字数', '${charStats['title']} 字'),
                  _buildStatRow('笔记字数', '${charStats['content']} 字'),
                  _buildStatRow('总字符数', '${charStats['total']} 字'),
                  _buildStatRow('最大深度', '$maxDepth 层'),
                  _buildStatRow('关联文档', '${controller.selectedTopic?.pdfIds.length ?? 0} 篇'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildStatRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    int _countNodes(List<NoteTreeNode> roots) {
      return roots.fold(0, (sum, root) => sum + root.totalNodes);
    }

    Map<String, int> _countCharacters(List<NoteTreeNode> roots) {
      int title = 0;
      int content = 0;
      void traverse(NoteTreeNode n) {
        title += n.note.title.length;
        content += (n.note.content?.plainText.length ?? 0);
        for (final child in n.children) {
          traverse(child);
        }
      }
      for (final root in roots) {
        traverse(root);
      }
      return {'title': title, 'content': content, 'total': title + content};
    }

    int _countContainers(List<NoteTreeNode> roots) {
      int count = 0;
      void traverse(NoteTreeNode n) {
        if (n.note.highlightStyle == 'nestedCard') count++;
        for (final child in n.children) {
          traverse(child);
        }
      }
      for (final root in roots) {
        traverse(root);
      }
      return count;
    }

    int _calculateMaxDepth(List<NoteTreeNode> roots) {
      return roots.isEmpty ? 0 : roots.map((r) => r.maxDepth).reduce((a, b) => a > b ? a : b);
    }
  }
  ```

- [ ] **Step 2: 底部操作栏左侧添加按钮触发显示**
  在 `lib/src/mindmap/ui/bottom_action_bar.dart` 的 Row 最左侧添加：
  ```dart
  IconButton(
    icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
    onPressed: onShowInfo, // 触发信息弹窗回调
  ),
  ```

- [ ] **Step 3: 在 `mindmap_page.dart` 中叠层渲染**
  引入 `bool _showInfoModal = false;` 状态，在点击底部栏时置为 `true`。并在 Canvas Stack 最顶层进行覆盖：
  ```dart
  if (_showInfoModal)
    GestureDetector(
      onTap: () => setState(() => _showInfoModal = false),
      child: Container(
        color: Colors.black26, // 半透明蒙版背景
        child: InfoStatisticsModal(
          controller: widget.controller,
          onClose: () => setState(() => _showInfoModal = false),
        ),
      ),
    )
  ```

---

### Task 2: 导航雷达小地图与双向手势平移 (Navigation Radar)

**Files:**
*   Create: `lib/src/mindmap/ui/navigation_radar.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`
*   Create: `test/mindmap/ui/radar_painter_test.dart`

- [ ] **Step 1: 编写微缩雷达及双向坐标换算浮窗 `navigation_radar.dart`**
  ```dart
  // lib/src/mindmap/ui/navigation_radar.dart
  import 'dart:math';
  import 'package:flutter/material.dart';
  import 'mindmap_controller.dart';
  import 'tree_layout.dart';
  import 'canvas_painter.dart';
  import '../service/mindmap_service.dart' show NoteTreeNode;

  class NavigationRadar extends StatelessWidget {
    final MindMapController controller;
    final Rect visibleRect;
    final Rect contentBounds;
    final Map<String, Offset> nodePositions;
    final List<Connection> connections;
    final Function(Offset deltaCanvas) onPanCanvas;

    const NavigationRadar({
      super.key,
      required this.controller,
      required this.visibleRect,
      required this.contentBounds,
      required this.nodePositions,
      required this.connections,
      required this.onPanCanvas,
    });

    @override
    Widget build(BuildContext context) {
      const radarW = 200.0;
      const radarH = 150.0;

      // 1. 计算缩放比 scale
      final scaleX = (radarW - 16) / contentBounds.width;
      final scaleY = (radarH - 16) / contentBounds.height;
      final radarScale = min(scaleX, scaleY).clamp(0.001, 10.0);

      // 2. 映射可视框位置
      final viewLeft = (visibleRect.left - contentBounds.left) * radarScale + 8;
      final viewTop = (visibleRect.top - contentBounds.top) * radarScale + 8;
      final viewW = visibleRect.width * radarScale;
      final viewH = visibleRect.height * radarScale;
      
      final viewportRadarRect = Rect.fromLTWH(viewLeft, viewTop, viewW, viewH);

      return Container(
        width: radarW,
        height: radarH,
        decoration: BoxDecoration(
          color: const Color(0xCC1C222B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1F2A3547), width: 1.0),
        ),
        child: Stack(
          children: [
            // 绘制缩微全图
            Positioned.fill(
              child: CustomPaint(
                painter: _RadarContentPainter(
                  positions: nodePositions,
                  connections: connections,
                  contentBounds: contentBounds,
                  radarScale: radarScale,
                ),
              ),
            ),
            // 双向拖拽手势可视框
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  // 将雷达拖拽位移还原为大图位移
                  final deltaRadar = details.delta;
                  final deltaCanvas = Offset(deltaRadar.dx / radarScale, deltaRadar.dy / radarScale);
                  onPanCanvas(deltaCanvas);
                },
                child: CustomPaint(
                  painter: _RadarViewportPainter(viewportRect: viewportRadarRect),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _RadarContentPainter extends CustomPainter {
    final Map<String, Offset> positions;
    final List<Connection> connections;
    final Rect contentBounds;
    final double radarScale;

    _RadarContentPainter({
      required this.positions,
      required this.connections,
      required this.contentBounds,
      required this.radarScale,
    });

    @override
    void paint(Canvas canvas, Size size) {
      final linePaint = Paint()
        ..color = Colors.white12
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      final nodePaint = Paint()
        ..color = Colors.white30
        ..style = PaintingStyle.fill;

      // 绘制缩微线
      for (final conn in connections) {
        final start = Offset(
          (conn.start.dx - contentBounds.left) * radarScale + 8,
          (conn.start.dy - contentBounds.top) * radarScale + 8,
        );
        final end = Offset(
          (conn.end.dx - contentBounds.left) * radarScale + 8,
          (conn.end.dy - contentBounds.top) * radarScale + 8,
        );
        canvas.drawLine(start, end, linePaint);
      }

      // 绘制缩微节点
      for (final entry in positions.entries) {
        final pos = entry.value;
        final x = (pos.dx - contentBounds.left) * radarScale + 8;
        final y = (pos.dy - contentBounds.top) * radarScale + 8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 4, y - 2, 8, 4), const Radius.circular(1)),
          nodePaint,
        );
      }
    }

    @override
    bool shouldRepaint(covariant _RadarContentPainter oldDelegate) => true;
  }

  class _RadarViewportPainter extends CustomPainter {
    final Rect viewportRect;

    _RadarViewportPainter({required this.viewportRect});

    @override
    void paint(Canvas canvas, Size size) {
      final framePaint = Paint()
        ..color = const Color(0xFFC8841A)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final fillPaint = Paint()
        ..color = const Color(0x0DC8841A)
        ..style = PaintingStyle.fill;

      canvas.drawRect(viewportRect, fillPaint);
      canvas.drawRect(viewportRect, framePaint);
    }

    @override
    bool shouldRepaint(covariant _RadarViewportPainter oldDelegate) =>
        viewportRect != oldDelegate.viewportRect;
  }
  ```

- [ ] **Step 2: 在 `mindmap_page.dart` 底部右侧悬浮雷达组件**
  ```dart
  Positioned(
    bottom: 84, // 位于底部操作栏上方
    right: 76,  // 靠近 Tab 导航固定栏
    child: NavigationRadar(
      controller: widget.controller,
      visibleRect: visibleRect,
      contentBounds: bounds,
      nodePositions: positions,
      connections: connections,
      onPanCanvas: (delta) {
        // 反向平移 InteractiveViewer 视口位移
        final matrix = _transformationController.value;
        final scale = matrix.getMaxScaleOnAxis();
        final tx = matrix.entry(0, 3);
        final ty = matrix.entry(1, 3);
        
        final newTx = tx - (delta.dx * scale);
        final newTy = ty - (delta.dy * scale);
        
        _transformationController.value = Matrix4.identity()
          ..scale(scale)
          ..translate(newTx / scale, newTy / scale);
        _onTransformationChanged(); // 触发可视视口框重算重绘
      },
    ),
  )
  ```

---

### Task 3: 全局 Workspace 联动 Shortcuts 键盘流

**Files:**
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`
*   Create: `test/mindmap/ui/shortcuts_mapping_test.dart`

- [ ] **Step 4: 扩充 Focus 键盘捕获层，绑定全局键及宿主联动接口**
  在 `mindmap_page.dart` 的 `Focus.onKeyEvent` 拦截器中，扩充快捷键，穿透联动外层：
  ```dart
  // 1. 获取外层宿主控制器 (WorkspaceController)
  // 通过 Provider 或在页面初始化时由宿主传入。为保障绝对解耦，在 Page 中可以通过 LocalProvider 获取：
  // final workspace = Provider.of<WorkspaceController>(context, listen: false);
  
  onKeyEvent: (node, event) {
    if (widget.controller.isLocked && event.logicalKey != LogicalKeyboardKey.keyQ) {
      return KeyEventResult.ignored;
    }
    
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      // Ctrl + Alt + ] -> 开关右侧笔记侧边栏
      if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.bracketRight) {
        widget.controller.toggleSidebar(SidebarTab.note);
        return KeyEventResult.handled;
      }

      // Ctrl + Alt + \ -> 快速循环切换两侧/单左/单右布局
      if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.backslash) {
        final currentDir = widget.controller.layoutDirection;
        final nextDir = currentDir == LayoutDirection.bothSides
            ? LayoutDirection.left
            : currentDir == LayoutDirection.left
                ? LayoutDirection.horizontal
                : LayoutDirection.bothSides;
        widget.controller.changeLayoutDirection(nextDir);
        return KeyEventResult.handled;
      }

      // Alt + Q -> 锁定/解锁编辑画布
      if (isAlt && event.logicalKey == LogicalKeyboardKey.keyQ) {
        widget.controller.toggleLock();
        return KeyEventResult.handled;
      }

      // Ctrl + Shift + E -> 自适应全屏
      if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyE) {
        _fitToScreen(context);
        return KeyEventResult.handled;
      }

      // Space -> 节点折叠切换
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (widget.controller.selectedNote != null) {
          widget.controller.toggleNodeCollapse(widget.controller.selectedNote!.id);
          return KeyEventResult.handled;
        }
      }

      // F2 -> 重命名弹窗
      if (event.logicalKey == LogicalKeyboardKey.f2) {
        if (widget.controller.selectedNote != null) {
          _showRenameDialog(context, widget.controller.selectedNote!);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }
  ```

---

### Task 4: 局部分屏避灾模式 (Lasso & Split Prevention)

**Files:**
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`
*   Modify: `lib/src/mindmap/ui/bottom_action_bar.dart`

- [ ] **Step 1: 键盘捕获 `Ctrl + Alt + S` 触发应用内局部 Row 分屏**
  在 `_MindMapPageState` 中定义状态：
  ```dart
  bool _isLocalSplitMode = false;
  ```
  在 Focus 快捷键中捕获：
  ```dart
  // Ctrl + Alt + S -> 局部分屏切换
  if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyS) {
    setState(() => _isLocalSplitMode = !_isLocalSplitMode);
    return KeyEventResult.handled;
  }
  ```

- [ ] **Step 2: Scaffold 弹性适配局部分屏视图**
  当分屏激活时，将 Row 内部的画布一分为二，右侧以高精度 PDF 矢量视口渲染器填充，彻底不污染 `rootLayoutNode` 类型：
  ```dart
  Row(
    children: [
      Expanded(
        child: _buildCanvas(context), // 左半侧渲染画布
      ),
      if (_isLocalSplitMode)
        const VerticalDivider(width: 1, color: Color(0x1F2A3547)),
      if (_isLocalSplitMode)
        Expanded(
          child: Container(
            color: const Color(0xFF141B24),
            child: const Center(
              child: Text(
                '关联 PDF 矢量双向分屏视口\n(防闪退局部分屏)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4),
              ),
            ),
          ),
        ),
      // 侧边栏和垂直 Tab 固定栏...
    ],
  )
  ```

---
