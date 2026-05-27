import 'dart:convert';
import 'dart:math';
import 'dart:ui';

/// Simplified stroke model for handwriting annotations in Starmind.
///
/// This is a lightweight representation that can be serialized to JSON
/// for storage in SQLite. For rendering, it can be converted to Saber's
/// Stroke class if needed.
class InkStroke {
  final List<InkPoint> points;
  final int color;  // ARGB32
  final double strokeWidth;
  final bool isHighlighter;

  const InkStroke({
    required this.points,
    required this.color,
    this.strokeWidth = 2.0,
    this.isHighlighter = false,
  });

  bool get isEmpty => points.isEmpty;
  int get length => points.length;

  /// Bounding rect in page coordinates.
  Rect? get bounds {
    if (points.isEmpty) return null;
    final xs = points.map((p) => p.x);
    final ys = points.map((p) => p.y);
    return Rect.fromLTRB(
      xs.reduce(min),
      ys.reduce(min),
      xs.reduce(max),
      ys.reduce(max),
    );
  }

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    return InkStroke(
      points: (json['p'] as List)
          .map((p) => InkPoint.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      color: json['c'] as int? ?? 0xFF000000,
      strokeWidth: (json['w'] as num?)?.toDouble() ?? 2.0,
      isHighlighter: json['h'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': points.map((p) => p.toJson()).toList(),
        'c': color,
        'w': strokeWidth,
        'h': isHighlighter,
      };

  InkStroke copy() => InkStroke(
        points: points.map((p) => p.copy()).toList(),
        color: color,
        strokeWidth: strokeWidth,
        isHighlighter: isHighlighter,
      );
}

/// A single point in an ink stroke.
class InkPoint {
  final double x;
  final double y;
  final double? pressure;

  const InkPoint({
    required this.x,
    required this.y,
    this.pressure,
  });

  Offset toOffset() => Offset(x, y);

  factory InkPoint.fromJson(Map<String, dynamic> json) {
    return InkPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pr'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        if (pressure != null) 'pr': pressure,
      };

  InkPoint copy() => InkPoint(
        x: x,
        y: y,
        pressure: pressure,
      );
}
