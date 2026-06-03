import 'package:flutter/material.dart';

/// Manages viewport transformation state (zoom and pan).
///
/// Responsibilities:
/// - Zoom level with min/max constraints
/// - Pan offset for scrolling
/// - Zoom-at-focal-point calculations
/// - Viewport state persistence/restore
///
/// This is a deep module: callers use setZoom/pan/zoomAt without
/// needing to understand the matrix math behind focal-point zoom.
class ViewportTransform extends ChangeNotifier {
  /// Minimum zoom factor (10% of original size).
  static const double minZoom = 0.1;

  /// Maximum zoom factor (3000% of original size).
  static const double maxZoom = 30.0;

  // ── Viewport State ──

  double _zoom = 1.0;
  double get zoom => _zoom;

  Offset _panOffset = Offset.zero;
  Offset get panOffset => _panOffset;

  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;

  bool _freePanEnabled = false;
  bool get freePanEnabled => _freePanEnabled;

  bool _palmRejectionEnabled = false;
  bool get palmRejectionEnabled => _palmRejectionEnabled;

  // ── Public Interface ──

  /// Sets the zoom factor (clamps between minZoom and maxZoom).
  void setZoom(double newZoom) {
    final clamped = newZoom.clamp(minZoom, maxZoom);
    if (_zoom != clamped) {
      _zoom = clamped;
      notifyListeners();
    }
  }

  /// Sets the pan offset (in PDF coordinates).
  void setPanOffset(Offset offset) {
    _panOffset = offset;
    notifyListeners();
  }

  /// Pan the viewport by a delta amount.
  void pan(Offset delta) {
    _panOffset += delta;
    notifyListeners();
  }

  /// Zoom with a specific focal point (the point that stays fixed on screen).
  /// The focal point remains at the same screen position after zooming.
  void zoomAt(Offset focalPoint, double newZoom) {
    final clampedZoom = newZoom.clamp(minZoom, maxZoom);
    if (clampedZoom == _zoom) return;

    // Calculate scale ratio
    final scaleRatio = clampedZoom / _zoom;

    // Adjust pan offset to keep the focal point fixed
    // New panOffset = focalPoint - (focalPoint - oldPanOffset) * scaleRatio
    _panOffset = Offset(
      focalPoint.dx - (focalPoint.dx - _panOffset.dx) * scaleRatio,
      focalPoint.dy - (focalPoint.dy - _panOffset.dy) * scaleRatio,
    );

    _zoom = clampedZoom;
    notifyListeners();
  }

  /// Sets both zoom and pan offset in one update.
  void setViewportState({double? zoom, Offset? panOffset}) {
    if (zoom != null) {
      _zoom = zoom.clamp(minZoom, maxZoom);
    }
    if (panOffset != null) {
      _panOffset = panOffset;
    }
    notifyListeners();
  }

  /// Sets the viewport size (called by widget).
  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  /// Resets viewport to default state (centered, zoom 1.0).
  void resetViewport() {
    _zoom = 1.0;
    _panOffset = Offset.zero;
    notifyListeners();
  }

  /// Enables or disables free pan mode.
  void setFreePanEnabled(bool enabled) {
    if (_freePanEnabled != enabled) {
      _freePanEnabled = enabled;
      notifyListeners();
    }
  }

  /// Enables or disables palm rejection.
  void setPalmRejectionEnabled(bool enabled) {
    if (_palmRejectionEnabled != enabled) {
      _palmRejectionEnabled = enabled;
      notifyListeners();
    }
  }

  // ── Persistence ──

  /// Gets the viewport state for persistence.
  ViewportState getViewportState() {
    return ViewportState(
      zoom: _zoom,
      panOffsetX: _panOffset.dx,
      panOffsetY: _panOffset.dy,
    );
  }

  /// Restores viewport state from persistence.
  void restoreViewportState(ViewportState state) {
    _zoom = state.zoom.clamp(minZoom, maxZoom);
    _panOffset = Offset(state.panOffsetX, state.panOffsetY);
    notifyListeners();
  }

  /// Constrain viewport boundaries to keep PDF visible within viewport.
  /// No-op if free pan mode is enabled.
  ///
  /// This is the only coordination logic that belongs in ViewportTransform:
  /// it operates purely on viewport state, not on document state.
  void constrainBounds({
    required Size pdfSize,
    required Size viewportSize,
    bool freePanEnabled = false,
  }) {
    if (freePanEnabled || pdfSize.isEmpty || viewportSize.isEmpty) return;

    final baseScale = viewportSize.width / pdfSize.width;
    final pdfDisplayWidth = pdfSize.width * baseScale * _zoom;
    final pdfDisplayHeight = pdfSize.height * baseScale * _zoom;

    double minX;
    double maxX;
    if (pdfDisplayWidth < viewportSize.width) {
      minX = (viewportSize.width - pdfDisplayWidth) / 2;
      maxX = minX;
    } else {
      minX = viewportSize.width - pdfDisplayWidth;
      maxX = 0.0;
    }

    double minY;
    double maxY;
    if (pdfDisplayHeight < viewportSize.height) {
      minY = (viewportSize.height - pdfDisplayHeight) / 2;
      maxY = minY;
    } else {
      minY = viewportSize.height - pdfDisplayHeight;
      maxY = 0.0;
    }

    final targetX = _panOffset.dx.clamp(minX, maxX);
    final targetY = _panOffset.dy.clamp(minY, maxY);
    setPanOffset(Offset(targetX, targetY));
  }
}

/// Viewport state for persistence.
class ViewportState {
  final double zoom;
  final double panOffsetX;
  final double panOffsetY;

  const ViewportState({
    required this.zoom,
    required this.panOffsetX,
    required this.panOffsetY,
  });

  factory ViewportState.fromJson(Map<String, dynamic> json) {
    return ViewportState(
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      panOffsetX: (json['panOffsetX'] as num?)?.toDouble() ?? 0.0,
      panOffsetY: (json['panOffsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'zoom': zoom,
        'panOffsetX': panOffsetX,
        'panOffsetY': panOffsetY,
      };
}