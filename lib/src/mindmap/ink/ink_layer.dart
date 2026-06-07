import 'dart:convert';
import 'dart:ui';

enum InkLayerOwnerType { canvas, node }

enum InkTool { pen, highlighter, eraser, lasso }

class InkPoint {
  final double x;
  final double y;
  final double pressure;

  const InkPoint(this.x, this.y, {this.pressure = 1});

  Offset get offset => Offset(x, y);

  InkPoint translate(Offset delta) => InkPoint(x + delta.dx, y + delta.dy, pressure: pressure);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'pressure': pressure};

  factory InkPoint.fromJson(Map<String, dynamic> json) => InkPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        pressure: (json['pressure'] as num?)?.toDouble() ?? 1,
      );
}

class InkStroke {
  final String id;
  final InkTool tool;
  final int color;
  final double width;
  final List<InkPoint> points;
  final DateTime createdAt;

  const InkStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    required this.createdAt,
  });

  bool get isEmpty => points.isEmpty;

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.x;
    var right = points.first.x;
    var top = points.first.y;
    var bottom = points.first.y;
    for (final point in points.skip(1)) {
      if (point.x < left) left = point.x;
      if (point.x > right) right = point.x;
      if (point.y < top) top = point.y;
      if (point.y > bottom) bottom = point.y;
    }
    final inflateBy = width / 2;
    return Rect.fromLTRB(left, top, right, bottom).inflate(inflateBy);
  }

  bool intersects(Rect rect) => bounds.overlaps(rect) || rect.contains(bounds.center);

  InkStroke translate(Offset delta) => copyWith(points: points.map((point) => point.translate(delta)).toList());

  InkStroke copyWith({List<InkPoint>? points}) => InkStroke(
        id: id,
        tool: tool,
        color: color,
        width: width,
        points: points ?? this.points,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tool': tool.name,
        'color': color,
        'width': width,
        'points': points.map((point) => point.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory InkStroke.fromJson(Map<String, dynamic> json) => InkStroke(
        id: json['id'] as String,
        tool: InkTool.values.byName(json['tool'] as String),
        color: json['color'] as int,
        width: (json['width'] as num).toDouble(),
        points: (json['points'] as List<dynamic>? ?? const [])
            .map((point) => InkPoint.fromJson(Map<String, dynamic>.from(point as Map)))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class InkLayer {
  final String id;
  final InkLayerOwnerType ownerType;
  final String ownerId;
  final List<InkStroke> strokes;
  final int zIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InkLayer({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    this.strokes = const [],
    this.zIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  String get strokesJson => jsonEncode(strokes.map((stroke) => stroke.toJson()).toList());

  InkLayer addStroke(InkStroke stroke) => copyWith(strokes: [...strokes, stroke], updatedAt: DateTime.now());

  InkLayer eraseIn(Rect rect) => copyWith(
        strokes: strokes.where((stroke) => !stroke.intersects(rect)).toList(),
        updatedAt: DateTime.now(),
      );

  InkLayer moveIn(Rect rect, Offset delta) => copyWith(
        strokes: strokes.map((stroke) => stroke.intersects(rect) ? stroke.translate(delta) : stroke).toList(),
        updatedAt: DateTime.now(),
      );

  InkLayer copyWith({List<InkStroke>? strokes, DateTime? updatedAt}) => InkLayer(
        id: id,
        ownerType: ownerType,
        ownerId: ownerId,
        strokes: strokes ?? this.strokes,
        zIndex: zIndex,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': ownerType.name,
        'owner_id': ownerId,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        'z_index': zIndex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InkLayer.fromJson(Map<String, dynamic> json) => InkLayer(
        id: json['id'] as String,
        ownerType: InkLayerOwnerType.values.byName(json['type'] as String),
        ownerId: json['owner_id'] as String,
        strokes: (json['strokes'] as List<dynamic>? ?? const [])
            .map((stroke) => InkStroke.fromJson(Map<String, dynamic>.from(stroke as Map)))
            .toList(),
        zIndex: json['z_index'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
