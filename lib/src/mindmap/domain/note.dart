// lib/src/mindmap/domain/note.dart

import 'dart:convert';
import 'note_content.dart';

/// 导图节点（对应 MarginNote ZBOOKNOTE）。
///
/// 设计依据：
/// - MarginNote: 管道分隔 childIds + PDF 摘录完整支持
/// - GuruMind: JSON segments 富文本
/// - 优化: parent_id 反向索引
/// - ID前缀: "1-{UUID}" (导图节点) 或 "2-{UUID}" (笔记节点)
class Note {
  /// 节点 ID（格式: "1-{UUID}" 或 "2-{UUID}"）
  final String id;

  /// 所属导图 ID
  final String topicId;

  /// 主父节点 ID（优化反向查询）
  final String? parentId;

  /// 节点标题
  final String title;

  /// 富文本内容（JSON segments 格式）
  final NoteContent? content;

  /// 子节点 ID 列表（管道分隔存储，MarginNote 模式）
  final List<String> childIds;

  /// 关联的 PDF ID
  final String? pdfId;

  /// PDF 起始页码
  final int? startPage;

  /// PDF 结束页码（支持跨页摘录）
  final int? endPage;

  /// 起始坐标 JSON（{"x":..., "y":...}）
  final String? startPosJson;

  /// 结束坐标 JSON
  final String? endPosJson;

  /// PDF 摘录原文
  final String? highlightText;

  /// 高亮样式（MarginNote: mbooks-annotation12）
  final String? highlightStyle;

  /// 关联媒体 ID 列表（管道分隔）
  final List<String> mediaIds;

  /// 画布 X 坐标
  final double? positionX;

  /// 画布 Y 坐标
  final double? positionY;

  /// Z 序索引
  final int zIndex;

  /// 是否折叠
  final bool isCollapsed;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 同步版本号
  final int syncVersion;

  const Note({
    required this.id,
    required this.topicId,
    this.parentId,
    required this.title,
    this.content,
    this.childIds = const [],
    this.pdfId,
    this.startPage,
    this.endPage,
    this.startPosJson,
    this.endPosJson,
    this.highlightText,
    this.highlightStyle,
    this.mediaIds = const [],
    this.positionX,
    this.positionY,
    this.zIndex = 0,
    this.isCollapsed = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncVersion = 0,
  });

  /// 从数据库 Map 创建
  factory Note.fromMap(Map<String, dynamic> map) {
    NoteContent? content;
    if (map['content_json'] != null) {
      try {
        final json = jsonDecode(map['content_json'] as String) as Map<String, dynamic>;
        content = NoteContent.fromJson(json);
      } catch (_) {
        // JSON 解析失败时忽略
      }
    }

    return Note(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      parentId: map['parent_id'] as String?,
      title: map['title'] as String,
      content: content,
      childIds: _parsePipedList(map['child_ids'] as String?),
      pdfId: map['pdf_id'] as String?,
      startPage: map['start_page'] as int?,
      endPage: map['end_page'] as int?,
      startPosJson: map['start_pos'] as String?,
      endPosJson: map['end_pos'] as String?,
      highlightText: map['highlight_text'] as String?,
      highlightStyle: map['highlight_style'] as String?,
      mediaIds: _parsePipedList(map['media_ids'] as String?),
      positionX: (map['position_x'] as num?)?.toDouble(),
      positionY: (map['position_y'] as num?)?.toDouble(),
      zIndex: map['z_index'] as int? ?? 0,
      isCollapsed: (map['is_collapsed'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncVersion: (map['sync_version'] as int?) ?? 0,
    );
  }

  /// 转为数据库 Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'topic_id': topicId,
        'parent_id': parentId,
        'title': title,
        'content_json': content != null ? jsonEncode(content!.toJson()) : null,
        'child_ids': childIds.isEmpty ? null : childIds.join('|'),
        'pdf_id': pdfId,
        'start_page': startPage,
        'end_page': endPage,
        'start_pos': startPosJson,
        'end_pos': endPosJson,
        'highlight_text': highlightText,
        'highlight_style': highlightStyle,
        'media_ids': mediaIds.isEmpty ? null : mediaIds.join('|'),
        'position_x': positionX,
        'position_y': positionY,
        'z_index': zIndex,
        'is_collapsed': isCollapsed ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_version': syncVersion,
      };

  /// 解析管道分隔字符串
  static List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 复制并更新字段
  Note copyWith({
    String? title,
    NoteContent? content,
    List<String>? childIds,
    String? parentId,
    double? positionX,
    double? positionY,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      topicId: topicId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      content: content ?? this.content,
      childIds: childIds ?? this.childIds,
      pdfId: pdfId,
      startPage: startPage,
      endPage: endPage,
      startPosJson: startPosJson,
      endPosJson: endPosJson,
      highlightText: highlightText,
      highlightStyle: highlightStyle,
      mediaIds: mediaIds,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      zIndex: zIndex,
      isCollapsed: isCollapsed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion,
    );
  }
}
