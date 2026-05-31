// lib/src/mindmap/ui/navigation_radar.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'tree_layout.dart';
import '../service/mindmap_service.dart' show NoteTreeNode;

/// A mini-map radar widget that displays an overview of the mindmap
/// and allows smooth bi-directional panning by dragging.
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

    // Calculate scale factor to adaptively fit all nodes inside the 200x150 radar map box,
    // with 8px margin/padding on the borders (total 16px).
    final double boundsW = contentBounds.width <= 0 ? 1.0 : contentBounds.width;
    final double boundsH = contentBounds.height <= 0 ? 1.0 : contentBounds.height;
    final scaleX = (radarW - 16) / boundsW;
    final scaleY = (radarH - 16) / boundsH;
    final radarScale = min(scaleX, scaleY).clamp(0.001, 10.0);

    // Map visible rect coordinate offsets
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Render the minified mindmap nodes and connections
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
            // Interaction overlay tracking viewport panning
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final deltaRadar = details.delta;
                  final deltaCanvas = Offset(
                    deltaRadar.dx / radarScale,
                    deltaRadar.dy / radarScale,
                  );
                  onPanCanvas(deltaCanvas);
                },
                child: CustomPaint(
                  painter: _RadarViewportPainter(viewportRect: viewportRadarRect),
                ),
              ),
            ),
          ],
        ),
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
      ..color = const Color(0x1FFFFFFF) // Fine, light translucent gray
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = const Color(0x4DFFFFFF) // Tiny translucent white/gray
      ..style = PaintingStyle.fill;

    // Draw minified connection lines
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

    // Draw minified node rectangles
    for (final entry in positions.entries) {
      final pos = entry.value;
      final x = (pos.dx - contentBounds.left) * radarScale + 8;
      final y = (pos.dy - contentBounds.top) * radarScale + 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4, y - 2, 8, 4),
          const Radius.circular(1),
        ),
        nodePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarContentPainter oldDelegate) {
    return oldDelegate.radarScale != radarScale ||
        oldDelegate.contentBounds != contentBounds ||
        oldDelegate.positions != positions ||
        oldDelegate.connections != connections;
  }
}

class _RadarViewportPainter extends CustomPainter {
  final Rect viewportRect;

  _RadarViewportPainter({required this.viewportRect});

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = const Color(0xFFC8841A) // Gold frame
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0x0DC8841A) // Light translucent gold fill
      ..style = PaintingStyle.fill;

    canvas.drawRect(viewportRect, fillPaint);
    canvas.drawRect(viewportRect, framePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarViewportPainter oldDelegate) {
    return viewportRect != oldDelegate.viewportRect;
  }
}
