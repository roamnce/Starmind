// lib/src/mindmap/domain/mindmap_relation.dart

import 'dart:convert';

const defaultRelationText = '关联';
const relationStyleSolid = 'solid';

/// 关联线控制点
class RelationControlPoint {
  final double x;
  final double y;

  const RelationControlPoint({required this.x, required this.y});

  factory RelationControlPoint.fromJson(Map<String, dynamic> json) {
    return RelationControlPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// 思维导图关联线（有向）
///
/// A→B 与 B→A 是两条不同的关联线。
class MindMapRelation {
  final String id;
  final String topicId;
  final String sourceNoteId;
  final String targetNoteId;
  final String text;
  final List<RelationControlPoint> controlPoints;
  final String style;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MindMapRelation({
    required this.id,
    required this.topicId,
    required this.sourceNoteId,
    required this.targetNoteId,
    this.text = defaultRelationText,
    this.controlPoints = const [],
    this.style = relationStyleSolid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MindMapRelation.fromMap(Map<String, dynamic> map) {
    final rawControlPoints = map['control_points_json'] as String?;
    final decodedControlPoints =
        rawControlPoints == null || rawControlPoints.isEmpty
            ? const <RelationControlPoint>[]
            : (jsonDecode(rawControlPoints) as List)
                .map((item) => RelationControlPoint.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList();

    return MindMapRelation(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      sourceNoteId: map['source_note_id'] as String,
      targetNoteId: map['target_note_id'] as String,
      text: (map['text'] as String?) ?? defaultRelationText,
      controlPoints: decodedControlPoints,
      style: (map['style'] as String?) ?? relationStyleSolid,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'source_note_id': sourceNoteId,
        'target_note_id': targetNoteId,
        'text': text,
        'control_points_json': controlPoints.isEmpty
            ? null
            : jsonEncode(
                controlPoints.map((point) => point.toJson()).toList()),
        'style': style,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MindMapRelation copyWith({
    String? text,
    List<RelationControlPoint>? controlPoints,
    String? style,
    DateTime? updatedAt,
  }) {
    return MindMapRelation(
      id: id,
      topicId: topicId,
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      text: text ?? this.text,
      controlPoints: controlPoints ?? this.controlPoints,
      style: style ?? this.style,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
