// lib/src/mindmap/ui/mindmap_page.dart

import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'mindmap_controller.dart';
import 'node_widget.dart';
import 'tree_layout.dart';
import 'framework_layout.dart';
import 'canvas_painter.dart';
import 'mindmap_sidebar.dart';
import 'bottom_action_bar.dart';
import 'floating_zoom_bar.dart';
import '../domain/note.dart';
import '../layout/layout_result.dart';
import '../study/study_mode_shortcut_handler.dart';
import '../study/study_mode_panel.dart';
import '../study/study_note_widget.dart';
import '../ink/ink_layer_controller.dart';
import '../ink/ink_layer.dart';
import '../ink/canvas_ink_layer.dart';
import '../ink/ink_layer_repository.dart';
import 'info_statistics_modal.dart';
import 'navigation_radar.dart';
import '../../home/workspace_controller_provider.dart';
import '../../home/tab_layout.dart';
import 'mixins/tree_traversal.dart';
import 'dialogs/add_node_dialog.dart';
import 'dialogs/rename_dialog.dart';
import 'dialogs/split_screen_menu.dart';
import 'dialogs/shortcuts_modal.dart';
import 'components/vertical_tab_bar.dart';
import 'components/lasso_overlay.dart';




/// MindMap canvas page.
///
/// Uses InteractiveViewer for zoom/pan.
/// Uses TreeLayout for automatic node layout.
/// Uses MindMapCanvasPainter for bezier connection drawing.
class MindMapPage extends StatefulWidget {
  final MindMapController controller;

  const MindMapPage({
    super.key,
    required this.controller,
  });

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> with TreeTraversal {
  late final TransformationController _transformationController;
  late final TextEditingController _noteTextEditingController;
  late final FocusNode _noteFocusNode;
  late final InkLayerController _inkLayerController;
  late final InkLayerRepository _inkLayerRepository;
  late final StudyModeShortcutHandler _studyShortcutHandler;
  String? _lastNoteId;
  String? _loadedInkTopicId;
  final Set<String> _loadedInkNodeIds = {};

  Offset? _lassoStart;
  Offset? _lassoCurrent;
  Rect? _lassoScreenRect;
  bool _showInfoModal = false;
  bool _showShortcutsModal = false;
  bool _isLocalSplitMode = false;
  bool _isStarred = true;
  bool _isInkMode = false;


  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _noteTextEditingController = TextEditingController();
    _noteFocusNode = FocusNode();
    _inkLayerController = InkLayerController();
    _inkLayerRepository = const FfiInkLayerRepository();
    _studyShortcutHandler = StudyModeShortcutHandler(widget.controller.studyModeController);
    widget.controller.addListener(_syncFromController);
    widget.controller.studyModeController.addListener(_onStudyModeChanged);

    // Set initial matrix
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromController();
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    widget.controller.removeListener(_syncFromController);
    widget.controller.studyModeController.removeListener(_onStudyModeChanged);
    _transformationController.dispose();
    _noteTextEditingController.dispose();
    _noteFocusNode.dispose();
    _inkLayerController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    if (!mounted) return;
    setState(() {}); // Trigger rebuild to recalculate visibleRect synchronously
  }

  void _syncFromController() {
    if (!mounted) return;

    // 确保 viewportScale 在有效范围内，避免 InteractiveViewer 的 scale != 0.0 断言错误
    final scale = widget.controller.viewportScale.clamp(
      MindMapController.minScale,
      MindMapController.maxScale,
    );

    final matrix = Matrix4.identity()
      ..translate(widget.controller.viewportOffset.dx, widget.controller.viewportOffset.dy)
      ..scale(scale);
    _transformationController.value = matrix;

    // Note text synchronization
    final selectedNote = widget.controller.selectedNote;
    if (selectedNote != null) {
      if (_lastNoteId != selectedNote.id) {
        _lastNoteId = selectedNote.id;
        final newText = selectedNote.content?.plainText ?? '';
        if (_noteTextEditingController.text != newText) {
          _noteTextEditingController.text = newText;
          _noteTextEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          );
        }
      }
    } else {
      _lastNoteId = null;
      if (_noteTextEditingController.text.isNotEmpty) {
        _noteTextEditingController.clear();
      }
    }

    setState(() {});
    _loadCanvasInkForSelectedTopic();
  }

  Future<void> _loadCanvasInkForSelectedTopic() async {
    final topicId = widget.controller.selectedTopic?.id;
    if (topicId == null || topicId == _loadedInkTopicId) return;
    _loadedInkTopicId = topicId;
    final layer = await _tryLoadInkLayer(topicId, InkLayerOwnerType.canvas);
    if (!mounted || layer == null) return;
    _inkLayerController.loadLayer(layer);
  }

  Future<void> _saveInkLayer(InkLayer layer) async {
    try {
      await _inkLayerRepository.saveInkLayer(layer);
    } on StateError {
      return;
    }
  }

  void _onStudyModeChanged() {
    if (!mounted) return;
    setState(() {});
    _loadNodeInkForStudyQuestion();
  }

  Future<void> _loadNodeInkForStudyQuestion() async {
    final noteId = widget.controller.studyModeController.currentQuestion?.note.id;
    if (noteId == null || !_loadedInkNodeIds.add(noteId)) return;
    final layer = await _tryLoadInkLayer(noteId, InkLayerOwnerType.node);
    if (!mounted || layer == null) return;
    _inkLayerController.loadLayer(layer);
  }

  Future<InkLayer?> _tryLoadInkLayer(String ownerId, InkLayerOwnerType ownerType) async {
    try {
      return await _inkLayerRepository.loadInkLayer(ownerId, ownerType);
    } on StateError {
      return null;
    }
  }

  bool _isNodeVisible(Rect visibleRect, Offset pos, Size size) {
    // 坐标系已改为中心坐标，需要减去高度一半得到顶部
    final nodeRect = Rect.fromLTWH(
      pos.dx - size.width / 2 + 500,
      pos.dy - size.height / 2 + 500,  // 修复：中心坐标减去高度一半
      size.width,
      size.height,
    );
    return visibleRect.overlaps(nodeRect);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isAlt = HardwareKeyboard.instance.isAltPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if (widget.controller.studyModeController.isStudyMode &&
            _studyShortcutHandler.handleKey(event.logicalKey)) {
          return KeyEventResult.handled;
        }

        if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyI) {
          setState(() => _isInkMode = !_isInkMode);
          return KeyEventResult.handled;
        }

        if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyT) {
          final topicId = widget.controller.selectedTopic?.id;
          if (topicId != null) {
            widget.controller.studyModeController.enterStudyMode(topicId);
          }
          return KeyEventResult.handled;
        }

        // Alt + Q -> 锁定/解锁编辑画布 (MUST be before lock check!)
        if (isAlt && event.logicalKey == LogicalKeyboardKey.keyQ) {
          widget.controller.toggleLock();
          return KeyEventResult.handled;
        }

        // If locked, ignore all other key events
        if (widget.controller.isLocked) {
          return KeyEventResult.ignored;
        }

        // Tab -> create child node dialog
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          _showAddNodeDialog(context, isChild: true);
          return KeyEventResult.handled;
        }

        // Enter -> create sibling node dialog
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          _showAddNodeDialog(context, isChild: false);
          return KeyEventResult.handled;
        }

        // Delete / Backspace -> delete selected node
        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          _handleDeleteSelected(context);
          return KeyEventResult.handled;
        }

        // Space -> Toggle collapse of selected node
        if (event.logicalKey == LogicalKeyboardKey.space) {
          final selectedNote = widget.controller.selectedNote;
          if (selectedNote != null) {
            widget.controller.toggleNodeCollapse(selectedNote.id);
            return KeyEventResult.handled;
          }
        }

        // F2 -> Rename selected node dialog
        if (event.logicalKey == LogicalKeyboardKey.f2) {
          final selectedNote = widget.controller.selectedNote;
          if (selectedNote != null) {
            _showRenameDialog(context, selectedNote);
            return KeyEventResult.handled;
          }
        }

        // Ctrl + Shift + E -> 自适应全屏
        if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyE) {
          _fitToScreen(context);
          return KeyEventResult.handled;
        }

        // Ctrl + Alt + [ -> WorkspaceController.setSidebarOpen(false)
        if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.bracketLeft) {
          context.maybeWorkspaceController?.setSidebarOpen(false);
          return KeyEventResult.handled;
        }

        // Ctrl + Alt + ] -> controller.toggleSidebar(SidebarTab.note)
        if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.bracketRight) {
          widget.controller.toggleSidebar(SidebarTab.note);
          return KeyEventResult.handled;
        }

        // Ctrl + Alt + \ -> 循环切换布局方式
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

        // Ctrl + Alt + S -> 局部分屏模式切换
        if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyS) {
          setState(() {
            _isLocalSplitMode = !_isLocalSplitMode;
          });
          return KeyEventResult.handled;
        }

        // Ctrl + W -> close tab
        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyW) {
          final workspace = context.maybeWorkspaceController;
          if (workspace != null) {
            final leaf = workspace.rootLayoutNode as LeafNode;
            final topicId = widget.controller.selectedTopic?.id;
            if (topicId != null) {
              final idx = leaf.tabs.indexWhere((t) => t.id == topicId && t.type == TabType.mindmap);
              if (idx != -1) {
                workspace.closeTab(idx);
              }
            }
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildBreadcrumbBar(context),
            Expanded(
              child: widget.controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.controller.noteTree.isEmpty
                      ? _buildEmptyState(context)
                      : Row(
                          children: [
                            Expanded(
                              child: _buildCanvas(context),
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
                            if (widget.controller.isSidebarExpanded)
                              MindMapSidebar(
                                controller: widget.controller,
                                textController: _noteTextEditingController,
                                focusNode: _noteFocusNode,
                              ),
                            _buildVerticalTabBar(),
                          ],
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (widget.controller.isLocked) {
              _showLockMessage(context);
              return;
            }
            _showAddNodeDialog(context, isChild: true);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No nodes',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below or press Enter/Tab to create nodes',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    // 检测是否有框架式节点
    final useFrameworkLayout = widget.controller.noteTree.any(
      (root) => root.note.layoutStyle == 'framework',
    );

    // 节点尺寸缓存（用于后续 viewport culling）
    final nodeSizes = <String, Size>{};

    // Calculate all node positions
    final positions = <String, Offset>{};
    final connections = <Connection>[];

    // 优先使用新布局引擎的结果
    final layoutResult = widget.controller.layoutResult;

    if (layoutResult != null && widget.controller.useNewLayoutEngine) {
      // 新架构：使用 LayoutResult
      positions.addAll(layoutResult.nodePositions);
      nodeSizes.addAll(layoutResult.nodeSizes);
      // NavigationRadar 仍需要 Connection 对象（临时兼容）
      for (final conn in layoutResult.connections) {
        connections.add(Connection(
          fromId: conn.fromId,
          toId: conn.toId,
          start: conn.startPoint,
          end: conn.endPoint,
        ));
      }
    } else if (useFrameworkLayout) {
      // 框架式布局
      final layout = FrameworkLayout();
      for (final root in widget.controller.noteTree) {
        positions.addAll(layout.calculate(root, Offset.zero));
        connections.addAll(layout.calculateConnections(root, positions));
      }
      nodeSizes.addAll(layout.nodeSizes);
    } else {
      // 树形布局
      final layout = TreeLayout(direction: widget.controller.layoutDirection);
      for (final root in widget.controller.noteTree) {
        positions.addAll(layout.calculate(root));
        connections.addAll(layout.calculateConnections(root, positions));
      }
      nodeSizes.addAll(layout.nodeSizes);
    }

    // Calculate bounding box
    final bounds = _calculateBounds(positions, nodeSizes);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate visible rect synchronously
        final matrix = _transformationController.value;
        final scale = matrix.getMaxScaleOnAxis();
        final Rect visibleRect;
        if (scale > 0) {
          final tx = matrix.entry(0, 3);
          final ty = matrix.entry(1, 3);
          const buffer = 200.0;
          final left = (-tx - buffer) / scale;
          final top = (-ty - buffer) / scale;
          final right = (constraints.maxWidth - tx + buffer) / scale;
          final bottom = (constraints.maxHeight - ty + buffer) / scale;
          visibleRect = Rect.fromLTRB(left, top, right, bottom);
        } else {
          visibleRect = Rect.largest;
        }

        // Radar visible rect (exact screen viewport in layout coordinates, without buffer or offset)
        final Rect radarVisibleRect;
        if (scale > 0) {
          final tx = matrix.entry(0, 3);
          final ty = matrix.entry(1, 3);
          final screenLeft = -tx / scale - 500.0;
          final screenTop = -ty / scale - 500.0;
          final screenWidth = constraints.maxWidth / scale;
          final screenHeight = constraints.maxHeight / scale;
          radarVisibleRect = Rect.fromLTWH(screenLeft, screenTop, screenWidth, screenHeight);
        } else {
          radarVisibleRect = Rect.largest;
        }

        return Container(
          color: widget.controller.canvasBgColor,
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                minScale: MindMapController.minScale,
                maxScale: MindMapController.maxScale,
                boundaryMargin: const EdgeInsets.all(500),
                scaleEnabled: widget.controller.interactMode != CanvasInteractMode.lasso,
                panEnabled: widget.controller.interactMode != CanvasInteractMode.lasso,
                child: Container(
                  width: bounds.width + 1000,
                  height: bounds.height + 1000,
                  color: widget.controller.canvasBgColor,
                  child: Stack(
                    children: [
                      // Connection layer (RepaintBoundary optimized)
                      // 连线坐标需要与节点位置同步，应用相同的 +500 偏移
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: MindMapCanvasPainter(
                            layoutResult: layoutResult != null && widget.controller.useNewLayoutEngine
                                ? _offsetLayoutResult(layoutResult, 500)
                                : null,
                            connections: layoutResult == null || !widget.controller.useNewLayoutEngine
                                ? connections.map((conn) => Connection(
                                    fromId: conn.fromId,
                                    toId: conn.toId,
                                    start: Offset(conn.start.dx + 500, conn.start.dy + 500),
                                    end: Offset(conn.end.dx + 500, conn.end.dy + 500),
                                  )).toList()
                                : null,
                            connectionStyle: widget.controller.connectionStyle,
                            lineColor: Theme.of(context).colorScheme.outline,
                            lineWidth: 2,
                            showGrid: widget.controller.showGrid,
                            gridSize: widget.controller.gridSize,
                            gridColor: widget.controller.gridColor,
                            isRainbowBranch: widget.controller.isRainbowBranch,
                          ),
                          size: Size(bounds.width + 1000, bounds.height + 1000),
                        ),
                      ),
                      // Node layer with Viewport Culling
                      ...positions.entries.map((entry) {
                        final noteId = entry.key;
                        final pos = entry.value;
                        final note = findNoteInTree(widget.controller.noteTree, noteId);

                        if (note == null) return const SizedBox.shrink();

                        final size = nodeSizes[noteId] ?? const Size(120, 40);
                        final visible = _isNodeVisible(visibleRect, pos, size);
                        if (!visible) return const SizedBox.shrink();

                        return Positioned(
                          left: pos.dx - size.width / 2 + 500,
                          top: pos.dy - size.height / 2 + 500,
                          child: RepaintBoundary(
                            child: NodeWidget(
                              note: note,
                              isSelected: widget.controller.selectedNote?.id == noteId,
                              onTap: () {
                                widget.controller.selectNote(note);
                                _centerOnNode(noteId, pos, size);
                              },
                              onLongPress: () => _showNodeContextMenu(context, note),
                              onToggleCollapse: () => widget.controller.toggleNodeCollapse(note.id),
                              customSize: size,
                              controller: widget.controller,
                            ),
                          ),
                        );
                      }),
                      if (widget.controller.selectedTopic != null)
                        Positioned.fill(
                          child: CanvasInkLayer(
                            controller: _inkLayerController,
                            ownerType: InkLayerOwnerType.canvas,
                            ownerId: widget.controller.selectedTopic!.id,
                            enabled: _isInkMode && !widget.controller.isLocked,
                            onLayerChanged: _saveInkLayer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.controller.interactMode == CanvasInteractMode.lasso)
                _buildLassoGestureOverlay(),
              if (widget.controller.studyModeController.isStudyMode)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: StudyModePanel(controller: widget.controller.studyModeController),
                ),
              if (widget.controller.studyModeController.currentQuestion != null)
                Positioned(
                  top: 72,
                  right: 24,
                  bottom: 24,
                  width: 420,
                  child: StudyNoteWidget(
                    question: widget.controller.studyModeController.currentQuestion!,
                    inkController: _inkLayerController,
                    onLayerChanged: _saveInkLayer,
                  ),
                ),
              if (_isInkMode)
                const Positioned(
                  top: 16,
                  left: 16,
                  child: _InkModeBadge(),
                ),
              // 左下角浮动缩放条
              FloatingZoomBar(
                controller: widget.controller,
                onShowInfo: () => setState(() => _showInfoModal = true),
                onShowShortcuts: () => setState(() => _showShortcutsModal = true),
                onToggleMinimap: widget.controller.toggleMinimap,
              ),
              // 底部操作栏
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: BottomActionBar(
                    controller: widget.controller,
                    onFitToScreen: () => _fitToScreen(context),
                    onShowAddChildDialog: () => _showAddNodeDialog(context, isChild: true),
                    onShowAddSiblingDialog: () => _showAddNodeDialog(context, isChild: false),
                    onAddNote: () => widget.controller.toggleSidebar(SidebarTab.note),
                  ),
                ),
              ),
              // 导航雷达 (根据 isMinimapVisible 控制显示)
              if (widget.controller.isMinimapVisible)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: NavigationRadar(
                    controller: widget.controller,
                    visibleRect: radarVisibleRect,
                    contentBounds: bounds,
                    nodePositions: positions,
                    connections: connections,
                    onPanCanvas: (delta) {
                      final matrix = _transformationController.value;
                      final scale = matrix.getMaxScaleOnAxis();
                      if (scale <= 0) return;
                      final tx = matrix.entry(0, 3);
                      final ty = matrix.entry(1, 3);

                      final newTx = tx - (delta.dx * scale);
                      final newTy = ty - (delta.dy * scale);

                      _transformationController.value = Matrix4.identity()
                        ..scale(scale)
                        ..translate(newTx / scale, newTy / scale);
                      _onTransformationChanged();
                    },
                  ),
                ),
              // 关于导图弹窗
              if (_showInfoModal)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showInfoModal = false),
                          child: Container(
                            color: Colors.black26,
                          ),
                        ),
                      ),
                      InfoStatisticsModal(
                        controller: widget.controller,
                        onClose: () => setState(() => _showInfoModal = false),
                      ),
                    ],
                  ),
                ),
              // 快捷键弹窗
              if (_showShortcutsModal)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showShortcutsModal = false),
                    child: Container(
                      color: Colors.black45,
                      child: ShortcutsModal(
                        onClose: () => setState(() => _showShortcutsModal = false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLassoGestureOverlay() {
    return LassoOverlay(
      onPanStart: (localPosition) {
        setState(() {
          _lassoStart = localPosition;
          _lassoCurrent = localPosition;
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, _lassoCurrent!);
        });
      },
      onPanUpdate: (localPosition) {
        if (_lassoStart == null) return;
        setState(() {
          _lassoCurrent = localPosition;
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, _lassoCurrent!);
        });
      },
      onPanEnd: () {
        if (_lassoScreenRect != null) {
          _performLassoSelection(_lassoScreenRect!);
        }
        setState(() {
          _lassoStart = null;
          _lassoCurrent = null;
          _lassoScreenRect = null;
        });
      },
      selectionRect: _lassoScreenRect,
    );
  }

  void _performLassoSelection(Rect selectionRect) {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.entry(0, 3);
    final ty = matrix.entry(1, 3);

    final canvasLeft = (selectionRect.left - tx) / scale;
    final canvasTop = (selectionRect.top - ty) / scale;
    final canvasRight = (selectionRect.right - tx) / scale;
    final canvasBottom = (selectionRect.bottom - ty) / scale;
    final canvasSelectionRect = Rect.fromLTRB(canvasLeft, canvasTop, canvasRight, canvasBottom);

    // 优先使用新布局引擎的结果
    final layoutResult = widget.controller.layoutResult;
    Map<String, Offset> positions;
    Map<String, Size> nodeSizes;

    if (layoutResult != null && widget.controller.useNewLayoutEngine) {
      positions = layoutResult.nodePositions;
      nodeSizes = layoutResult.nodeSizes;
    } else {
      // Fallback: 使用 TreeLayout
      final layout = TreeLayout(direction: widget.controller.layoutDirection);
      positions = <String, Offset>{};
      for (final root in widget.controller.noteTree) {
        positions.addAll(layout.calculate(root));
      }
      nodeSizes = layout.nodeSizes;
    }

    final selectedIds = <String>{};
    for (final entry in positions.entries) {
      final noteId = entry.key;
      final pos = entry.value;
      final size = nodeSizes[noteId] ?? const Size(120, 40);

      // Align with stack offsets: A node's bounding box inside the Stack is Rect.fromLTWH(...)
      final nodeBounds = Rect.fromLTWH(
        pos.dx - size.width / 2 + 500,
        pos.dy - size.height / 2 + 500,
        size.width,
        size.height,
      );

      if (canvasSelectionRect.overlaps(nodeBounds)) {
        selectedIds.add(noteId);
      }
    }

    widget.controller.setSelectedNotes(selectedIds);

    if (selectedIds.isNotEmpty) {
      final primaryId = selectedIds.first;
      final primaryNote = findNoteInTree(widget.controller.noteTree, primaryId);
      if (primaryNote != null) {
        widget.controller.selectNote(primaryNote);
        // 居中显示第一个选中的节点
        final primaryPos = positions[primaryId];
        final primarySize = nodeSizes[primaryId] ?? const Size(120, 40);
        if (primaryPos != null) {
          _centerOnNode(primaryId, primaryPos, primarySize);
        }
      }
    } else {
      widget.controller.selectNote(null);
    }
  }


  /// Calculate bounding box for all nodes
  Rect _calculateBounds(Map<String, Offset> positions, Map<String, Size> nodeSizes) {
    if (positions.isEmpty) {
      return Rect.fromLTWH(0, 0, 400, 400);
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final entry in positions.entries) {
      final id = entry.key;
      final pos = entry.value;
      final size = nodeSizes[id] ?? const Size(120, 40);

      // 坐标系已改为中心坐标
      minX = min(minX, pos.dx - size.width / 2);
      maxX = max(maxX, pos.dx + size.width / 2);
      minY = min(minY, pos.dy - size.height / 2);
      maxY = max(maxY, pos.dy + size.height / 2);
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  void _showNodeContextMenu(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final isContainer = note.highlightStyle == 'nestedCard';
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename Node'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Child Node'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddNodeDialog(context, isChild: true);
                },
              ),
              ListTile(
                leading: Icon(isContainer ? Icons.grid_view_rounded : Icons.crop_free_rounded),
                title: Text(isContainer ? 'Convert to Normal Node' : 'Convert to Card Group (Container)'),
                onTap: () async {
                  Navigator.pop(context);
                  await widget.controller.toggleNestedCard(note.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Node', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _handleDeleteSelected(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context, Note note) async {
    final result = await RenameDialog.show(context, initialTitle: note.title);

    if (result != null && result.isNotEmpty) {
      await widget.controller.updateNoteTitle(note.id, result);
    }
  }

  void _showLockMessage(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.lock_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              '思维导图已锁定，无法编辑',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C222B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0x1F2A3547), width: 1),
        ),
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.only(bottom: 84, left: 16, right: 16),
      ),
    );
  }

  void _fitToScreen(BuildContext context) {
    // 优先使用新布局引擎的结果
    final layoutResult = widget.controller.layoutResult;
    Map<String, Offset> positions;
    Map<String, Size> nodeSizes;

    if (layoutResult != null && widget.controller.useNewLayoutEngine) {
      positions = layoutResult.nodePositions;
      nodeSizes = layoutResult.nodeSizes;
    } else {
      // 检测是否有框架式节点
      final useFrameworkLayout = widget.controller.noteTree.any(
        (root) => root.note.layoutStyle == 'framework',
      );

      positions = <String, Offset>{};
      nodeSizes = <String, Size>{};

      if (useFrameworkLayout) {
        final layout = FrameworkLayout();
        for (final root in widget.controller.noteTree) {
          positions.addAll(layout.calculate(root, Offset.zero));
        }
        nodeSizes.addAll(layout.nodeSizes);
      } else {
        final layout = const TreeLayout();
        for (final root in widget.controller.noteTree) {
          positions.addAll(layout.calculate(root));
        }
        nodeSizes.addAll(layout.nodeSizes);
      }
    }

    final bounds = _calculateBounds(positions, nodeSizes);
    final screenSize = MediaQuery.of(context).size;

    widget.controller.fitToScreen(screenSize, bounds);
  }

  /// 将指定节点居中显示在视口中
  void _centerOnNode(String noteId, Offset nodePos, Size nodeSize) {
    final matrix = _transformationController.value;
    var scale = matrix.getMaxScaleOnAxis();

    // 确保缩放比例在有效范围内
    if (scale <= 0) {
      scale = 1.0;
    }
    scale = scale.clamp(MindMapController.minScale, MindMapController.maxScale);

    // 获取屏幕尺寸
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final screenSize = renderBox.size;

    // 计算节点在 Stack 中的中心位置（需要 +500 偏移）
    // nodePos 现在已经是节点中心坐标
    final nodeCenterX = nodePos.dx + 500;
    final nodeCenterY = nodePos.dy + 500;

    // 计算新的偏移量，使节点居中
    final newTx = screenSize.width / 2 - nodeCenterX * scale;
    final newTy = screenSize.height / 2 - nodeCenterY * scale;

    _transformationController.value = Matrix4.identity()
      ..scale(scale)
      ..translate(newTx / scale, newTy / scale);
    _onTransformationChanged();
  }

  Future<void> _handleDeleteSelected(BuildContext context) async {
    if (widget.controller.selectedNote != null) {
      await widget.controller.deleteNote(widget.controller.selectedNote!.id);
    }
  }

  Future<void> _showAddNodeDialog(BuildContext context, {bool isChild = true}) async {
    final result = await AddNodeDialog.show(context, isChild: isChild);

    if (result != null && result.isNotEmpty) {
      if (isChild) {
        await widget.controller.createChildNode(title: result);
      } else {
        await widget.controller.createSiblingNode(title: result);
      }
    }
  }

  Widget _buildVerticalTabBar() {
    return VerticalTabBar(controller: widget.controller);
  }

  Widget _buildBreadcrumbBar(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF100D08),
        border: Border(
          bottom: BorderSide(color: Color(0x1F2A3547), width: 1),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                tooltip: '后退',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onPressed: () {},
                tooltip: '前进',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: Icon(
                  _isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _isStarred ? const Color(0xFFE0A92E) : Colors.white60,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _isStarred = !_isStarred;
                  });
                },
                tooltip: '收藏',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_outlined, size: 14, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text(
                    widget.controller.selectedTopic?.title ?? 'AI配音',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 16),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('撤销成功'), duration: Duration(milliseconds: 500)),
                  );
                },
                tooltip: '撤销',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.redo_rounded, size: 16),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('重做成功'), duration: Duration(milliseconds: 500)),
                  );
                },
                tooltip: '重做',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: Icon(
                  widget.controller.splitType != null
                      ? Icons.splitscreen_rounded
                      : Icons.vertical_split_rounded,
                  size: 16,
                  color: widget.controller.splitType != null ? const Color(0xFF1862C6) : Colors.white60,
                ),
                onPressed: () => _showSplitScreenMenu(context),
                tooltip: '分屏',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('切换到大纲模式'), duration: Duration(milliseconds: 500)),
                  );
                },
                tooltip: '切换到大纲模式',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 16),
                onPressed: () => _showMoreActionsMenu(context),
                tooltip: '更多操作',
                color: Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.view_sidebar_outlined, size: 16),
                onPressed: () {
                  widget.controller.toggleSidebar(widget.controller.activeSidebarTab);
                },
                tooltip: '切换侧边栏',
                color: widget.controller.isSidebarExpanded ? const Color(0xFF1862C6) : Colors.white60,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showMoreActionsMenu(BuildContext context) async {
    final selected = await showMenu<_MindMapMoreAction>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
      color: const Color(0xFF1A1A1A),
      items: [
        PopupMenuItem(
          value: _MindMapMoreAction.importGuruMind,
          child: _buildMoreActionItem(Icons.file_upload_outlined, '导入 GuruMind'),
        ),
        PopupMenuItem(
          value: _MindMapMoreAction.exportGuruMind,
          enabled: widget.controller.selectedTopic != null,
          child: _buildMoreActionItem(Icons.file_download_outlined, '导出 GuruMind'),
        ),
        PopupMenuItem(
          value: _MindMapMoreAction.studyMode,
          enabled: widget.controller.selectedTopic != null,
          child: _buildMoreActionItem(Icons.school_outlined, '进入刷题模式'),
        ),
        PopupMenuItem(
          value: _MindMapMoreAction.toggleInk,
          enabled: widget.controller.selectedTopic != null,
          child: _buildMoreActionItem(_isInkMode ? Icons.draw : Icons.draw_outlined, _isInkMode ? '关闭画布手写' : '开启画布手写'),
        ),
      ],
    );
    if (!mounted || selected == null) return;

    switch (selected) {
      case _MindMapMoreAction.importGuruMind:
        await _importGuruMindFile();
      case _MindMapMoreAction.exportGuruMind:
        await _exportCurrentTopicAsGuruMind();
      case _MindMapMoreAction.studyMode:
        final topicId = widget.controller.selectedTopic?.id;
        if (topicId != null) await widget.controller.studyModeController.enterStudyMode(topicId);
      case _MindMapMoreAction.toggleInk:
        setState(() => _isInkMode = !_isInkMode);
    }
  }

  Widget _buildMoreActionItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Future<void> _importGuruMindFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择 GuruMind 文件',
      type: FileType.custom,
      allowedExtensions: const ['gurumind'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) return;

    try {
      final topic = await widget.controller.importGuruMindFile(filePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入：${topic?.title ?? 'GuruMind 文件'}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _exportCurrentTopicAsGuruMind() async {
    final topic = widget.controller.selectedTopic;
    if (topic == null) return;
    final directory = await FilePicker.getDirectoryPath(dialogTitle: '选择导出位置');
    if (directory == null) return;
    final outputPath = '$directory/${_safeFileName(topic.title)}.gurumind';

    try {
      await widget.controller.exportCurrentTopicAsGuruMind(outputPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出：$outputPath')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }

  String _safeFileName(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.isEmpty ? 'mindmap' : sanitized;
  }

  void _showSplitScreenMenu(BuildContext context) async {
    final workspaceCtrl = context.maybeWorkspaceController;
    if (workspaceCtrl == null) return;

    await SplitScreenMenu.show(
      context,
      controller: widget.controller,
      pdfDocs: workspaceCtrl.documents,
      getMindmaps: () => widget.controller.getAllTopics(),
    );
  }

  /// 将 LayoutResult 中的坐标偏移（用于 Stack 渲染）
  LayoutResult _offsetLayoutResult(LayoutResult result, double offset) {
    final offsetPositions = result.nodePositions.map(
      (id, pos) => MapEntry(id, Offset(pos.dx + offset, pos.dy + offset)),
    );

    final offsetConnections = result.connections.map((conn) {
      return ConnectionData(
        fromId: conn.fromId,
        toId: conn.toId,
        startPoint: Offset(conn.startPoint.dx + offset, conn.startPoint.dy + offset),
        endPoint: Offset(conn.endPoint.dx + offset, conn.endPoint.dy + offset),
        fromCenter: Offset(conn.fromCenter.dx + offset, conn.fromCenter.dy + offset),
        toCenter: Offset(conn.toCenter.dx + offset, conn.toCenter.dy + offset),
      );
    }).toList();

    return LayoutResult(
      nodePositions: offsetPositions,
      nodeSizes: result.nodeSizes,
      connections: offsetConnections,
      contentBounds: result.contentBounds.shift(Offset(offset, offset)),
    );
  }
}



class _InkModeBadge extends StatelessWidget {
  const _InkModeBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text('Ink mode', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

enum _MindMapMoreAction { importGuruMind, exportGuruMind, studyMode, toggleInk }
