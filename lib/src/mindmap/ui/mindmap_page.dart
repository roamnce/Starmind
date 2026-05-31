// lib/src/mindmap/ui/mindmap_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mindmap_controller.dart';
import 'node_widget.dart';
import 'tree_layout.dart';
import 'canvas_painter.dart';
import 'mindmap_sidebar.dart';
import 'bottom_action_bar.dart';
import 'lasso_painter.dart';
import '../service/mindmap_service.dart' show NoteTreeNode;
import '../domain/note.dart';



/// MindMap canvas page.
///
/// Uses InteractiveViewer for zoom/pan.
/// Uses TreeLayout for automatic node layout.
/// Uses MindMapCanvasPainter for bezier connection drawing.
class MindMapPage extends StatefulWidget {
  final MindMapController controller;

  const MindMapPage({
    key,
    required this.controller,
  }) : super(key: key);

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  late final TransformationController _transformationController;
  late final TextEditingController _noteTextEditingController;
  late final FocusNode _noteFocusNode;
  String? _lastNoteId;

  Offset? _lassoStart;
  Offset? _lassoCurrent;
  Rect? _lassoScreenRect;


  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _noteTextEditingController = TextEditingController();
    _noteFocusNode = FocusNode();
    widget.controller.addListener(_syncFromController);

    // Set initial matrix
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromController();
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    widget.controller.removeListener(_syncFromController);
    _transformationController.dispose();
    _noteTextEditingController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    if (!mounted) return;
    setState(() {}); // Trigger rebuild to recalculate visibleRect synchronously
  }

  void _syncFromController() {
    if (!mounted) return;
    final matrix = Matrix4.identity()
      ..translate(widget.controller.viewportOffset.dx, widget.controller.viewportOffset.dy)
      ..scale(widget.controller.viewportScale);
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
  }

  bool _isNodeVisible(Rect visibleRect, Offset pos, Size size) {
    final nodeRect = Rect.fromLTWH(
      pos.dx - size.width / 2 + 500,
      pos.dy + 500,
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
        if (widget.controller.isLocked) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            _showAddNodeDialog(context, isChild: true);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _showAddNodeDialog(context, isChild: false);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.delete ||
                     event.logicalKey == LogicalKeyboardKey.backspace) {
            _handleDeleteSelected(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.controller.selectedTopic?.title ?? 'MindMap'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: widget.controller.zoomOut,
              tooltip: 'Zoom out',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: widget.controller.zoomIn,
              tooltip: 'Zoom in',
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: () => _fitToScreen(context),
              tooltip: 'Fit to screen',
            ),
          ],
        ),
        body: widget.controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.controller.noteTree.isEmpty
                ? _buildEmptyState(context)
                : Row(
                    children: [
                      Expanded(
                        child: _buildCanvas(context),
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
    final layout = TreeLayout(direction: widget.controller.layoutDirection);

    // Calculate all node positions
    final positions = <String, Offset>{};
    final connections = <Connection>[];

    for (final root in widget.controller.noteTree) {
      positions.addAll(layout.calculate(root));
      connections.addAll(layout.calculateConnections(root, positions));
    }

    // Calculate bounding box
    final bounds = _calculateBounds(positions, layout);

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
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: MindMapCanvasPainter(
                            connections: connections,
                            lineColor: Theme.of(context).colorScheme.outline,
                            lineWidth: 2,
                            showGrid: widget.controller.showGrid,
                            gridSize: widget.controller.gridSize,
                            gridColor: widget.controller.gridColor,
                          ),
                          size: Size(bounds.width + 1000, bounds.height + 1000),
                        ),
                      ),
                      // Node layer with Viewport Culling
                      ...positions.entries.map((entry) {
                        final noteId = entry.key;
                        final pos = entry.value;
                        final note = _findNote(widget.controller.noteTree, noteId);

                        if (note == null) return const SizedBox.shrink();

                        final size = layout.nodeSizes[noteId] ?? Size(layout.nodeWidth, layout.nodeHeight);
                        final visible = _isNodeVisible(visibleRect, pos, size);
                        if (!visible) return const SizedBox.shrink();

                        return Positioned(
                          left: pos.dx - size.width / 2 + 500,
                          top: pos.dy + 500,
                          child: RepaintBoundary(
                            child: NodeWidget(
                              note: note,
                              isSelected: widget.controller.selectedNote?.id == noteId,
                              onTap: () => widget.controller.selectNote(note),
                              onLongPress: () => _showNodeContextMenu(context, note),
                              onToggleCollapse: () => widget.controller.toggleNodeCollapse(note.id),
                              customSize: size,
                              controller: widget.controller,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (widget.controller.interactMode == CanvasInteractMode.lasso)
                _buildLassoGestureOverlay(),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: BottomActionBar(
                    controller: widget.controller,
                    onFitToScreen: () => _fitToScreen(context),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        setState(() {
          _lassoStart = details.localPosition;
          _lassoCurrent = details.localPosition;
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, _lassoCurrent!);
        });
      },
      onPanUpdate: (details) {
        if (_lassoStart == null) return;
        setState(() {
          _lassoCurrent = details.localPosition;
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, _lassoCurrent!);
        });
      },
      onPanEnd: (details) {
        if (_lassoScreenRect != null) {
          _performLassoSelection(_lassoScreenRect!);
        }
        setState(() {
          _lassoStart = null;
          _lassoCurrent = null;
          _lassoScreenRect = null;
        });
      },
      child: CustomPaint(
        painter: LassoPainter(selectionRect: _lassoScreenRect),
        size: Size.infinite,
      ),
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

    // Retrieve layouts
    final layout = TreeLayout(direction: widget.controller.layoutDirection);
    final positions = <String, Offset>{};
    for (final root in widget.controller.noteTree) {
      positions.addAll(layout.calculate(root));
    }

    final selectedIds = <String>{};
    for (final entry in positions.entries) {
      final noteId = entry.key;
      final pos = entry.value;
      final size = layout.nodeSizes[noteId] ?? Size(layout.nodeWidth, layout.nodeHeight);

      // Align with stack offsets: A node's bounding box inside the Stack is Rect.fromLTWH(...)
      final nodeBounds = Rect.fromLTWH(
        pos.dx - size.width / 2 + 500,
        pos.dy + 500,
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
      final primaryNote = _findNote(widget.controller.noteTree, primaryId);
      if (primaryNote != null) {
        widget.controller.selectNote(primaryNote);
      }
    } else {
      widget.controller.selectNote(null);
    }
  }


  /// Calculate bounding box for all nodes
  Rect _calculateBounds(Map<String, Offset> positions, TreeLayout layout) {
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
      final size = layout.nodeSizes[id] ?? Size(layout.nodeWidth, layout.nodeHeight);

      minX = _min(minX, pos.dx - size.width / 2);
      maxX = _max(maxX, pos.dx + size.width / 2);
      minY = _min(minY, pos.dy);
      maxY = _max(maxY, pos.dy + size.height);
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
    final textController = TextEditingController(text: note.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Node'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await widget.controller.updateNoteTitle(note.id, result);
    }
  }

  /// Find note in tree
  Note? _findNote(List<NoteTreeNode> roots, String id) {
    for (final root in roots) {
      final found = _findNoteInTree(root, id);
      if (found != null) return found;
    }
    return null;
  }

  Note? _findNoteInTree(NoteTreeNode node, String id) {
    if (node.note.id == id) return node.note;
    for (final child in node.children) {
      final found = _findNoteInTree(child, id);
      if (found != null) return found;
    }
    return null;
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
    final layout = const TreeLayout();
    final positions = <String, Offset>{};

    for (final root in widget.controller.noteTree) {
      positions.addAll(layout.calculate(root));
    }

    final bounds = _calculateBounds(positions, layout);
    final screenSize = MediaQuery.of(context).size;

    widget.controller.fitToScreen(screenSize, bounds);
  }

  Future<void> _handleDeleteSelected(BuildContext context) async {
    if (widget.controller.selectedNote != null) {
      await widget.controller.deleteNote(widget.controller.selectedNote!.id);
    }
  }

  Future<void> _showAddNodeDialog(BuildContext context, {bool isChild = true}) async {
    final textController = TextEditingController();
    final titleText = isChild ? 'Create Child Node' : 'Create Sibling Node';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titleText),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter node title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (isChild) {
        await widget.controller.createChildNode(title: result);
      } else {
        await widget.controller.createSiblingNode(title: result);
      }
    }
  }

  Widget _buildVerticalTabBar() {
    return Container(
      width: 52,
      decoration: const BoxDecoration(
        color: Color(0xFF141921),
        border: Border(
          left: BorderSide(color: Color(0x1F2A3547), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildVerticalTabButton(SidebarTab.note, Icons.send_rounded, '节点笔记'),
          _buildVerticalTabButton(SidebarTab.style, Icons.push_pin_rounded, '导图主题'),
          _buildVerticalTabButton(SidebarTab.icon, Icons.sentiment_satisfied_alt_rounded, '节点图标'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildVerticalTabButton(SidebarTab tab, IconData icon, String tooltip) {
    final isActive = widget.controller.isSidebarExpanded && widget.controller.activeSidebarTab == tab;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: InkWell(
          onTap: () => widget.controller.toggleSidebar(tab),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1862C6) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1862C6).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Transform.rotate(
              angle: tab == SidebarTab.note ? -0.5 : 0.0,
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.white60,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;