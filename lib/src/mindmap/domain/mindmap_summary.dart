// lib/src/mindmap/domain/mindmap_summary.dart

const defaultSummaryText = '概要';

/// 思维导图概要节点
///
/// 对同一父节点下连续兄弟节点区间的概要标注。
/// 通过 parentId + startIndex + endIndex 唯一标识。
class MindMapSummary {
  final String id;
  final String topicId;
  final String parentId;
  final int startIndex;
  final int endIndex;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  MindMapSummary({
    required this.id,
    required this.topicId,
    required this.parentId,
    required int startIndex,
    required int endIndex,
    this.text = defaultSummaryText,
    required this.createdAt,
    required this.updatedAt,
  })  : startIndex = startIndex <= endIndex ? startIndex : endIndex,
        endIndex = startIndex <= endIndex ? endIndex : startIndex;

  factory MindMapSummary.fromMap(Map<String, dynamic> map) => MindMapSummary(
        id: map['id'] as String,
        topicId: map['topic_id'] as String,
        parentId: map['parent_id'] as String,
        startIndex: map['start_index'] as int,
        endIndex: map['end_index'] as int,
        text: (map['text'] as String?) ?? defaultSummaryText,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'parent_id': parentId,
        'start_index': startIndex,
        'end_index': endIndex,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MindMapSummary copyWith({
    String? text,
    int? startIndex,
    int? endIndex,
    DateTime? updatedAt,
  }) {
    return MindMapSummary(
      id: id,
      topicId: topicId,
      parentId: parentId,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
