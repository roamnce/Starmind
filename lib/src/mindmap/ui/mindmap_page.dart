// lib/src/mindmap/ui/mindmap_page.dart

import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'node_widget.dart';
import 'tree_layout.dart';
import 'canvas_painter.dart';
import '../service/mindmap_service.dart' show NoteTreeNode;
import '../domain/note.dart';

/// MindMap canvas page.
///
/// Uses InteractiveViewer for zoom/pan.
/// Uses TreeLayout for automatic node layout.
/// Uses MindMapCanvasPainter for bezier connection drawing.
class MindMapPage extends StatelessWidget {
  final MindMapController controller;

  const MindMapPage({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.selectedTopic?.title ?? 'MindMap'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: controller.zoomOut,
            tooltip: 'Zoom out',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: controller.zoomIn,
            tooltip: 'Zoom in',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: () => _fitToScreen(context),
            tooltip: 'Fit to screen',
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.noteTree.isEmpty
              ? _buildEmptyState(context)
              : _buildCanvas(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context),
        child: const Icon(Icons.add),
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
            'Tap the button below to create a root node',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final layout = const TreeLayout();

    // Calculate all node positions
    final positions = <String, Offset>{};
    final connections = <Connection>[];

    for (final root in controller.noteTree) {
      positions.addAll(layout.calculate(root));
      connections.addAll(layout.calculateConnections(root, positions));
    }

    // Calculate bounding box
    final bounds = _calculateBounds(positions, layout);

    return InteractiveViewer(
      constrained: false,
      minScale: MindMapController.minScale,
      maxScale: MindMapController.maxScale,
      boundaryMargin: const EdgeInsets.all(100),
      child: Container(
        width: bounds.width + 200,
        height: bounds.height + 200,
        child: Stack(
          children: [
            // Connection layer
            CustomPaint(
              painter: MindMapCanvasPainter(
                connections: connections,
                lineColor: Theme.of(context).colorScheme.outline,
                lineWidth: 2,
              ),
              size: Size(bounds.width + 200, bounds.height + 200),
            ),
            // Node layer
            ...positions.entries.map((entry) {
              final noteId = entry.key;
              final pos = entry.value;
              final note = _findNote(controller.noteTree, noteId);

              if (note == null) return const SizedBox.shrink();

              return Positioned(
                left: pos.dx - layout.nodeWidth / 2 + 100,
                top: pos.dy + 100,
                child: NodeWidget(
                  note: note,
                  isSelected: controller.selectedNote?.id == noteId,
                  onTap: () => controller.selectNote(note),
                ),
              );
            }),
          ],
        ),
      ),
    );
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

    for (final pos in positions.values) {
      minX = _min(minX, pos.dx - layout.nodeWidth / 2);
      maxX = _max(maxX, pos.dx + layout.nodeWidth / 2);
      minY = _min(minY, pos.dy);
      maxY = _max(maxY, pos.dy + layout.nodeHeight);
    }

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
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

  void _fitToScreen(BuildContext context) {
    final layout = const TreeLayout();
    final positions = <String, Offset>{};

    for (final root in controller.noteTree) {
      positions.addAll(layout.calculate(root));
    }

    final bounds = _calculateBounds(positions, layout);
    final screenSize = MediaQuery.of(context).size;

    controller.fitToScreen(screenSize, bounds);
  }

  Future<void> _showAddNodeDialog(BuildContext context) async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Node'),
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
      await controller.createNote(title: result);
    }
  }
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;