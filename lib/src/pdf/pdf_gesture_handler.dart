import 'package:flutter/material.dart';
import 'pdf_viewport_controller.dart';

/// PDF gesture handler
///
/// Handles zoom and pan gestures, replacing InteractiveViewer for better control.
class PdfGestureHandler {
  final PdfViewportController controller;

  PdfGestureHandler({required this.controller});

  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  bool _isZooming = false;
  bool _isPanning = false;

  void onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastScale = 1.0;
    _isZooming = false;
    _isPanning = false;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final focalPoint = details.localFocalPoint;
    final scaleDelta = details.scale / _lastScale;

    // Detect zoom (scale change > 1%)
    if ((scaleDelta - 1.0).abs() > 0.01) {
      _isZooming = true;
      _zoomAt(focalPoint, scaleDelta);
      _lastScale = details.scale;
    }

    // Detect pan (when not zooming)
    if (_lastFocalPoint != null && !_isZooming) {
      final panDelta = focalPoint - _lastFocalPoint!;
      if (panDelta.distance > 2.0) {
        _isPanning = true;
        controller.pan(panDelta);
      }
    }

    _lastFocalPoint = focalPoint;
  }

  void onScaleEnd(ScaleEndDetails details, Size pdfSize, Size viewportSize) {
    // Apply boundary constraints
    controller.constrainBounds(pdfSize, viewportSize);

    _lastFocalPoint = null;
    _isZooming = false;
    _isPanning = false;
  }

  void _zoomAt(Offset focalPoint, double scaleDelta) {
    final newZoom = controller.zoom * scaleDelta;
    controller.zoomAt(focalPoint, newZoom);
  }

  void reset() {
    _lastFocalPoint = null;
    _lastScale = 1.0;
    _isZooming = false;
    _isPanning = false;
  }
}
