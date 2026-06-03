/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/stroke_stabilizer.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/gesture_dispatcher.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart' show InkTool;

/// Canvas layer for drawing ink/handwriting annotations.
///
/// Captures single-finger gestures in drawing mode and renders strokes.
/// Integrates with AnnotationController for persistence.
///
/// Enhancement features:
/// - Stroke stabilization (String Pulling + Moving Average + Corner Detection)
/// - Pressure curve mapping (Cubic Bezier)
/// - Pen type presets (fountain pen, ballpoint, pencil, highlighter, eraser)
class InkCanvasLayer extends StatefulWidget {
  final AnnotationController annotationController;
  final int pageIndex;
  final bool isInkMode;
  final bool palmRejectionEnabled;
  final InkTool currentTool;
  final String currentColor;
  final double strokeWidth;
  final double scale; // Static baseScale of the page layout
  final double pdfWidth;
  final double pdfHeight;

  /// Pen configuration for enhanced drawing.
  final PenConfig? penConfig;

  const InkCanvasLayer({
    super.key,
    required this.annotationController,
    required this.pageIndex,
    required this.isInkMode,
    required this.palmRejectionEnabled,
    required this.currentTool,
    required this.currentColor,
    required this.strokeWidth,
    required this.scale,
    required this.pdfWidth,
    required this.pdfHeight,
    this.penConfig,
  });

  @override
  State<InkCanvasLayer> createState() => _InkCanvasLayerState();
}

class _InkCanvasLayerState extends State<InkCanvasLayer> {
  /// Current stroke being drawn.
  List<InkPoint> _currentStrokePoints = [];

  /// All strokes drawn in this session (not yet saved).
  List<InkStroke> _sessionStrokes = [];

  /// Whether currently drawing.
  bool _isDrawing = false;

  /// Stroke stabilizer for smooth drawing.
  late StrokeStabilizer _stabilizer;

  /// Current pen configuration derived from tool selection.
  late PenConfig _activePenConfig;

  /// Eraser trail points for visual feedback.
  List<Offset> _eraserPoints = [];

  /// Gesture dispatcher for multi-touch handling.
  late GestureDispatcher _gestureDispatcher;

  @override
  void initState() {
    super.initState();
    _stabilizer = StrokeStabilizer(level: 3);
    _gestureDispatcher = GestureDispatcher();
    _gestureDispatcher.inkModeEnabled = widget.isInkMode;
    _gestureDispatcher.palmRejectionEnabled = widget.palmRejectionEnabled;
    _updatePenConfig();
  }

  @override
  void didUpdateWidget(InkCanvasLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTool != widget.currentTool ||
        oldWidget.strokeWidth != widget.strokeWidth ||
        oldWidget.currentColor != widget.currentColor ||
        oldWidget.penConfig != widget.penConfig) {
      _updatePenConfig();
    }
    // Sync GestureDispatcher settings
    _gestureDispatcher.inkModeEnabled = widget.isInkMode;
    _gestureDispatcher.palmRejectionEnabled = widget.palmRejectionEnabled;
  }

  void _updatePenConfig() {
    // Use provided pen config or derive from tool selection
    if (widget.penConfig != null) {
      _activePenConfig = widget.penConfig!;
      _stabilizer.level = _activePenConfig.stabilizerLevel;
    } else {
      // Derive pen config from tool type
      final color = _parseColor(widget.currentColor);
      switch (widget.currentTool) {
        case InkTool.pen:
          _activePenConfig = PenConfig.ballpointPen(
            color: Color(color),
            baseWidth: widget.strokeWidth,
            stabilizerLevel: 3,
          );
          break;
        case InkTool.highlighter:
          _activePenConfig = PenConfig.highlighter(
            color: Color(color),
            baseWidth: widget.strokeWidth,
          );
          break;
        case InkTool.eraser:
          _activePenConfig = PenConfig.eraser(baseWidth: widget.strokeWidth);
          break;
      }
      _stabilizer.level = _activePenConfig.stabilizerLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    // In reading mode, don't capture gestures
    if (!widget.isInkMode) {
      return const SizedBox.shrink();
    }

    // Use Listener instead of GestureDetector to allow multi-touch passthrough
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: InkCanvasPainter(
          sessionStrokes: _sessionStrokes,
          currentStrokePoints: _currentStrokePoints,
          currentColor: _parseColor(widget.currentColor),
          strokeWidth: widget.strokeWidth,
          isHighlighter: widget.currentTool == InkTool.highlighter,
          scale: widget.scale,
          pdfWidth: widget.pdfWidth,
          pdfHeight: widget.pdfHeight,
          eraserStrokes: widget.currentTool == InkTool.eraser ? _eraserPoints : null,
          penConfig: _activePenConfig,
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    // Use GestureDispatcher for handling
    _gestureDispatcher.onPointerDown(event.pointer, event.kind, event.localPosition);

    if (!_gestureDispatcher.isDrawing) return;
    if (_gestureDispatcher.drawingPointerId != event.pointer) return;

    // Single pointer in annotation mode: allow drawing
    _stabilizer.reset();

    if (widget.currentTool == InkTool.eraser) {
      _eraserPoints = [_screenToPdf(event.localPosition)];
      setState(() {});
      return;
    }

    _isDrawing = true;
    final rawPoint = _screenToPdf(event.localPosition);

    // Apply stabilizer if enabled
    final stabilizedPoint = _stabilizer.stabilize(
      rawPoint,
      timestampUs: DateTime.now().microsecondsSinceEpoch,
    );

    // Apply pressure curve if pressure is available
    double? pressure;
    if (_activePenConfig.pressureEnabled && event.pressure > 0) {
      pressure = _activePenConfig.pressureCurve.evaluate(
        _stabilizer.stabilizePressure(event.pressure),
      );
    }

    _currentStrokePoints = [
      InkPoint(
        x: stabilizedPoint.dx,
        y: stabilizedPoint.dy,
        pressure: pressure,
      ),
    ];
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Use GestureDispatcher for handling
    if (!_gestureDispatcher.onPointerMove(event.pointer, event.localPosition)) {
      return;
    }

    if (widget.currentTool == InkTool.eraser) {
      final pdfPos = _screenToPdf(event.localPosition);
      _eraserPoints.add(pdfPos);
      _eraseStrokesAt(pdfPos);
      setState(() {});
      return;
    }

    if (!_isDrawing) return;

    final rawPoint = _screenToPdf(event.localPosition);

    // Apply stabilizer
    final stabilizedPoint = _stabilizer.stabilize(
      rawPoint,
      timestampUs: DateTime.now().microsecondsSinceEpoch,
    );

    // Apply pressure curve
    double? pressure;
    if (_activePenConfig.pressureEnabled && event.pressure > 0) {
      pressure = _activePenConfig.pressureCurve.evaluate(
        _stabilizer.stabilizePressure(event.pressure),
      );
    }

    _currentStrokePoints.add(
      InkPoint(
        x: stabilizedPoint.dx,
        y: stabilizedPoint.dy,
        pressure: pressure,
      ),
    );
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    _gestureDispatcher.onPointerUp(event.pointer);

    // If we're in multi-touch mode (still have other pointers), don't finalize drawing
    if (_gestureDispatcher.activePointerCount > 0 && _gestureDispatcher.drawingPointerId == null) {
      // This pointer was drawing but another finger is still down
      // Cancel the drawing - zoom/pan is now active
      _isDrawing = false;
      _currentStrokePoints = [];
      _eraserPoints = [];
      _stabilizer.reset();
      setState(() {});
      return;
    }

    if (widget.currentTool == InkTool.eraser) {
      _eraserPoints = [];
      setState(() {});
      return;
    }

    if (!_isDrawing || _currentStrokePoints.isEmpty) return;

    _isDrawing = false;

    // Generate catch-up points to close stabilizer lag gap
    final rawPoint = _screenToPdf(event.localPosition);
    final catchUpPoints = _stabilizer.finalize(rawPoint);

    // Add catch-up points to stroke
    for (final point in catchUpPoints) {
      _currentStrokePoints.add(InkPoint(x: point.dx, y: point.dy));
    }

    // Determine stroke width based on pen type and pressure
    double strokeWidth = _activePenConfig.baseWidth;
    bool isHighlighter = _activePenConfig.type == PenType.highlighter;

    // For pressure-sensitive pens, calculate average width
    if (_activePenConfig.pressureEnabled && _currentStrokePoints.any((p) => p.pressure != null)) {
      // Use first pressure value as reference (or average)
      final avgPressure = _currentStrokePoints
          .where((p) => p.pressure != null)
          .map((p) => p.pressure!)
          .reduce((a, b) => a + b) / _currentStrokePoints.where((p) => p.pressure != null).length;
      strokeWidth = _activePenConfig.baseWidth * (0.5 + avgPressure * 1.5);
    }

    final stroke = InkStroke(
      points: _currentStrokePoints,
      color: _parseColor(widget.currentColor),
      strokeWidth: strokeWidth,
      isHighlighter: isHighlighter,
    );

    _sessionStrokes.add(stroke);
    _currentStrokePoints = [];
    _stabilizer.reset();
    setState(() {});
    _saveStrokes();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _gestureDispatcher.onPointerCancel(event.pointer);

    // Cancel drawing if this was the drawing pointer
    if (!_gestureDispatcher.isDrawing) {
      _isDrawing = false;
      _currentStrokePoints = [];
      _eraserPoints = [];
      _stabilizer.reset();
      setState(() {});
    }
  }

  /// Convert screen position to PDF coordinates.
  Offset _screenToPdf(Offset screenPos) {
    // Local coordinates range from 0 to pdfWidth * scale
    // Divide by scale to get back to PDF points
    final pdfX = screenPos.dx / widget.scale;
    final pdfY = widget.pdfHeight - (screenPos.dy / widget.scale);
    return Offset(pdfX, pdfY);
  }

  /// Erase strokes at given PDF position.
  void _eraseStrokesAt(Offset pdfPos) {
    const eraserRadius = 10.0;
    final eraserRect = Rect.fromCenter(
      center: pdfPos,
      width: eraserRadius * 2,
      height: eraserRadius * 2,
    );

    // Check each session stroke
    for (final stroke in _sessionStrokes) {
      for (final point in stroke.points) {
        if (eraserRect.contains(Offset(point.x, point.y))) {
          // Remove this stroke
          _sessionStrokes.remove(stroke);
          break;
        }
      }
    }

    // Also check saved annotations
    final annotations = widget.annotationController.annotationsForPage(widget.pageIndex);
    for (final annotation in annotations) {
      if (annotation.type != AnnotationType.ink) continue;
      if (annotation.strokes == null) continue;

      for (final stroke in annotation.strokes!) {
        for (final point in stroke.points) {
          if (eraserRect.contains(Offset(point.x, point.y))) {
            widget.annotationController.deleteAnnotation(annotation.id);
            break;
          }
        }
      }
    }
  }

  /// Save all session strokes to annotation controller.
  void _saveStrokes() {
    if (_sessionStrokes.isEmpty) return;

    widget.annotationController.createInk(
      pageIndex: widget.pageIndex,
      strokes: _sessionStrokes,
      colorHex: widget.currentColor,
    );

    _sessionStrokes = [];
  }

  int _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return int.parse(buffer.toString(), radix: 16);
  }
}

/// Custom painter for ink canvas layer.
class InkCanvasPainter extends CustomPainter {
  final List<InkStroke> sessionStrokes;
  final List<InkPoint> currentStrokePoints;
  final int currentColor;
  final double strokeWidth;
  final bool isHighlighter;
  final double scale; // Static baseScale of the page layout
  final double pdfWidth;
  final double pdfHeight;
  final List<Offset>? eraserStrokes;
  final PenConfig penConfig;

  InkCanvasPainter({
    required this.sessionStrokes,
    required this.currentStrokePoints,
    required this.currentColor,
    required this.strokeWidth,
    required this.isHighlighter,
    required this.scale,
    required this.pdfWidth,
    required this.pdfHeight,
    required this.eraserStrokes,
    required this.penConfig,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw saved session strokes
    for (final stroke in sessionStrokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke being drawn
    if (currentStrokePoints.isNotEmpty) {
      final currentStroke = InkStroke(
        points: currentStrokePoints,
        color: currentColor,
        strokeWidth: strokeWidth,
        isHighlighter: isHighlighter,
      );
      _drawStroke(canvas, currentStroke);
    }

    // Draw eraser trail
    if (eraserStrokes != null && eraserStrokes!.length > 1) {
      final eraserPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 20 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final eraserPath = Path();
      final first = _pdfToScreen(eraserStrokes!.first);
      eraserPath.moveTo(first.dx, first.dy);
      for (final point in eraserStrokes!.skip(1)) {
        final screen = _pdfToScreen(point);
        eraserPath.lineTo(screen.dx, screen.dy);
      }
      canvas.drawPath(eraserPath, eraserPaint);
    }
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final baseWidth = stroke.strokeWidth * scale;
    final paint = Paint()
      ..color = Color(stroke.color).withValues(
        alpha: stroke.isHighlighter ? 0.3 : penConfig.opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = _pdfToScreen(Offset(stroke.points.first.x, stroke.points.first.y));
    path.moveTo(first.dx, first.dy);

    // Draw with pressure-sensitive width if applicable
    if (penConfig.pressureEnabled && stroke.points.any((p) => p.pressure != null)) {
      // Draw segments with varying width
      for (int i = 1; i < stroke.points.length; i++) {
        final prevPoint = stroke.points[i - 1];
        final currPoint = stroke.points[i];

        final prevScreen = _pdfToScreen(Offset(prevPoint.x, prevPoint.y));
        final currScreen = _pdfToScreen(Offset(currPoint.x, currPoint.y));

        // Calculate width based on pressure
        double width = baseWidth;
        if (prevPoint.pressure != null) {
          width = baseWidth * (0.5 + prevPoint.pressure! * 1.5);
        }

        // Draw segment with calculated width
        final segmentPaint = Paint()
          ..color = Color(stroke.color).withValues(
            alpha: stroke.isHighlighter ? 0.3 : penConfig.opacity,
          )
          ..strokeWidth = width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawLine(prevScreen, currScreen, segmentPaint);
      }
    } else {
      // Draw with fixed width
      paint.strokeWidth = baseWidth;
      for (int i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final screen = _pdfToScreen(Offset(point.x, point.y));
        path.lineTo(screen.dx, screen.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Convert PDF coordinates to screen coordinates.
  Offset _pdfToScreen(Offset pdfPos) {
    final screenX = pdfPos.dx * scale;
    final screenY = (pdfHeight - pdfPos.dy) * scale;
    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant InkCanvasPainter oldDelegate) {
    return oldDelegate.sessionStrokes != sessionStrokes ||
        oldDelegate.currentStrokePoints != currentStrokePoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isHighlighter != isHighlighter ||
        oldDelegate.scale != scale ||
        oldDelegate.eraserStrokes != eraserStrokes ||
        oldDelegate.penConfig != penConfig;
  }
}